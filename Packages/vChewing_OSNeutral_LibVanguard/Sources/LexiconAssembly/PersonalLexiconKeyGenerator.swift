// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Tekkon

extension LXAssembly {
  public enum PersonalLexiconReadingParser {
    public static func parse(_ raw: String) -> [String]? {
      let tokens = raw.split(whereSeparator: { $0.isWhitespace }).map(String.init)
      guard !tokens.isEmpty else { return nil }
      var result: [String] = []
      result.reserveCapacity(tokens.count)

      for token in tokens {
        if token.unicodeScalars.contains(where: { (0x3105 ... 0x312F).contains($0.value) }) {
          result.append(token)
          continue
        }

        let numeric = Tekkon.cnvHanyuPinyinTextbookStyleToNumeric(targetJoined: token)
        guard numeric.unicodeScalars.contains(where: { (0x31 ... 0x35).contains($0.value) }) else {
          return nil
        }
        let phona = Tekkon.cnvHanyuPinyinToPhona(targetJoined: numeric, newToneOne: "")
        guard !phona.isEmpty,
              phona != numeric,
              phona.unicodeScalars.allSatisfy({
                (0x3105 ... 0x312F).contains($0.value) || "ˊˇˋ˙".unicodeScalars.contains($0)
              })
        else {
          return nil
        }
        result.append(phona)
      }
      return result
    }
  }

  public enum PersonalLexiconKeyGenerator {
    public struct Keys: Sendable, Equatable {
      public let pinyinTokens: [String]
      public let fullPinyinKey: String
      public let initialsKey: String
    }

    public static func generate(readings: [String]) -> Keys? {
      guard !readings.isEmpty else { return nil }
      let tokens = readings.compactMap(normalizePinyinToken(reading:))
      guard tokens.count == readings.count, tokens.allSatisfy({ !$0.isEmpty }) else { return nil }
      let full = tokens.joined()
      let initials = tokens.compactMap(\.first).map(String.init).joined()
      guard !full.isEmpty, initials.count == tokens.count else { return nil }
      return .init(pinyinTokens: tokens, fullPinyinKey: full, initialsKey: initials)
    }

    public static func makeEntry(
      phrase: String,
      readings: [String],
      source: PersonalLexiconEntry.Source = .manual,
      pinned: Bool = false,
      now: Date = Date()
    ) -> PersonalLexiconEntry? {
      guard !phrase.isEmpty, let keys = generate(readings: readings) else { return nil }
      return .init(
        phrase: phrase,
        readings: readings,
        pinyinTokens: keys.pinyinTokens,
        fullPinyinKey: keys.fullPinyinKey,
        initialsKey: keys.initialsKey,
        source: source,
        createdAt: now,
        updatedAt: now,
        pinned: pinned
      )
    }

    // MARK: Private

    private static func normalizePinyinToken(reading: String) -> String? {
      let raw = Tekkon.cnvPhonaToHanyuPinyin(targetJoined: reading).lowercased()
      let asciiLetters = raw.unicodeScalars.compactMap { scalar -> Character? in
        guard scalar.isASCII else { return nil }
        let value = scalar.value
        guard (97 ... 122).contains(value) else { return nil }
        return Character(String(scalar))
      }
      guard !asciiLetters.isEmpty else { return nil }
      return String(asciiLetters)
    }
  }

  public enum PersonalLexiconReadingResolver {
    /// 從目前 factory reverse lookup 解析詞語讀音。
    ///
    /// 優先整詞；若整詞不存在，採「最長詞段優先」切分。這能讓 factory 中已有
    /// `台達` 與 `能源`、但沒有 `台達能源` 時仍得到穩定的四音節讀音。
    public static func resolveFactoryReadings(for phrase: String) -> [String]? {
      let characters = Array(phrase)
      guard !characters.isEmpty, characters.count <= 32 else { return nil }

      // 一次收集所有連續詞段，再以單次 TextMap scan 取得 exact value→reading chains。
      // 避免最長詞段 DP 每試一個 substring 就重掃整份 factory dictionary。
      var targetSegments = Set<String>()
      for start in characters.indices {
        for end in (start + 1) ... characters.count {
          targetSegments.insert(String(characters[start ..< end]))
        }
      }
      let readingChains = LXFacade.getFactoryExactReadingChains(for: targetSegments)

      if let exact = preferredReadingChain(
        for: phrase,
        expectedCount: characters.count,
        readingChains: readingChains
      ) {
        return exact
      }

      var memo: [Int: [String]?] = [:]
      func resolve(from start: Int) -> [String]? {
        if start == characters.count { return [] }
        if let cached = memo[start] { return cached }

        let remaining = characters.count - start
        for length in stride(from: remaining, through: 1, by: -1) {
          let end = start + length
          let segment = String(characters[start ..< end])
          guard let readings = preferredReadingChain(
            for: segment,
            expectedCount: length,
            readingChains: readingChains
          ) else {
            continue
          }
          if let suffix = resolve(from: end) {
            let result = readings + suffix
            memo[start] = result
            return result
          }
        }
        memo[start] = nil
        return nil
      }

      return resolve(from: 0)
    }

    public static func makeManualEntry(
      phrase: String,
      pinned: Bool = true,
      now: Date = Date()
    ) -> PersonalLexiconEntry? {
      guard let readings = resolveFactoryReadings(for: phrase) else { return nil }
      return PersonalLexiconKeyGenerator.makeEntry(
        phrase: phrase,
        readings: readings,
        source: .manual,
        pinned: pinned,
        now: now
      )
    }

    // MARK: Private

    private static func preferredReadingChain(
      for phrase: String,
      expectedCount: Int,
      readingChains: [String: [[String]]]
    ) -> [String]? {
      if expectedCount == 1,
         phrase.unicodeScalars.count == 1,
         let candidates = LXFacade.getFactoryReverseLookupData(with: phrase) {
        for candidate in candidates {
          let readings = candidate.split(separator: "-").map(String.init)
          if readings.count == 1, !readings[0].isEmpty { return readings }
        }
      }
      guard let candidates = readingChains[phrase] else { return nil }
      for readings in candidates {
        guard readings.count == expectedCount, readings.allSatisfy({ !$0.isEmpty }) else { continue }
        return readings
      }
      return nil
    }
  }
}
