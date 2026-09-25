// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - HybridCandidateOffer

/// MixType Hybrid 內部使用的候選來源標記。
///
/// 不把來源資訊塞進全域 `CandidateInState`，避免影響既有候選窗與非 Hybrid 路徑。
struct HybridCandidateOffer {
  enum Source: Equatable {
    case cassetteExact
    case cassetteQuick
    case pinyinFull
    case pinyinAbbreviation
  }

  let candidate: CandidateInState
  let source: Source
  let score: Double
}

enum HybridCandidateSelectionOutcome {
  case commit(String)
  case composition
}

extension InputHandlerProtocol {
  /// 以 Hybrid raw-key buffer 唯讀生成候選。
  ///
  /// 排序固定為 CIN exact → CIN quick → full Pinyin → abbreviated Pinyin；
  /// 相同輸出值只保留第一次出現者，因此 CIN 命中不會被拼音重新排序到後方。
  func hybridCandidateOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard !rawKeys.isEmpty else { return [] }

    var groupedOffers: [[HybridCandidateOffer]] = []

    let cassetteExact = currentLM.lxQuerier.cassetteGrams(for: rawKeys).map {
      HybridCandidateOffer(
        candidate: (keyArray: $0.keyArray, value: $0.current),
        source: .cassetteExact,
        score: $0.probability
      )
    }
    groupedOffers.append(cassetteExact)

    let cassetteQuick: [HybridCandidateOffer]
    if let rawQuick = currentLM.lxQuerier.cassetteQuickSets(
      for: rawKeys,
      strategy: .configuredLookup
    ) {
      cassetteQuick = rawQuick.split(separator: "\t").enumerated().map { index, value in
        HybridCandidateOffer(
          candidate: (keyArray: [rawKeys], value: value.description),
          source: .cassetteQuick,
          score: -Double(index)
        )
      }
    } else {
      cassetteQuick = []
    }
    groupedOffers.append(cassetteQuick)

    groupedOffers.append(hybridFullPinyinOffers(for: rawKeys))
    groupedOffers.append(hybridAbbreviatedPinyinOffers(for: rawKeys))

    var seenValues = Set<String>()
    var merged: [HybridCandidateOffer] = []
    for offer in groupedOffers.flatMap({ $0 }) {
      let value = offer.candidate.value
      guard !value.isEmpty, value != currentLM.nullCandidateInCassette else { continue }
      guard seenValues.insert(value).inserted else { continue }
      merged.append(offer)
    }
    return merged
  }

  /// 將已選定的 Hybrid Pinyin 候選以真實讀音寫入 Homa，再覆寫成使用者指定詞值。
  ///
  /// 失敗時完整還原組字器；raw-key buffer 只有在成功後才清空。
  @discardableResult
  func confirmHybridPinyinCandidate(_ candidate: CandidateInState) -> Bool {
    guard !candidate.keyArray.isEmpty, !candidate.value.isEmpty else { return false }
    let backup = assembler.copy
    let anchor = assembler.cursor
    let keys = candidate.keyArray.map { Homa.PossibleKey.singleKey($0) }
    guard (try? assembler.insertKeys(keys)) != nil else { return false }
    do {
      try assembler.overrideCandidate(
        .init(keyArray: candidate.keyArray, value: candidate.value),
        at: anchor,
        type: .withSpecified,
        isExplicitlyOverridden: true,
        enforceRetokenization: true
      )
    } catch {
      assembler = backup
      return false
    }
    calligrapher.removeAll()
    composer.clear()
    invalidateFuriousTrail()
    return true
  }

  /// 共用於 production / test session 的 Hybrid 選字語義。
  ///
  /// CIN 保留既有 cassette 的直接遞交；Pinyin 則寫入 Homa 並留在組字區。
  func confirmHybridCandidateSelection(
    _ candidate: CandidateInState
  )
    -> HybridCandidateSelectionOutcome? {
    guard typingMode == .hybridCassettePinyin else { return nil }
    let offers = hybridCandidateOffers(for: calligrapher)
    guard let offer = offers.first(where: {
      $0.candidate.keyArray == candidate.keyArray && $0.candidate.value == candidate.value
    }) else { return nil }

    switch offer.source {
    case .cassetteExact, .cassetteQuick:
      guard !candidate.value.isEmpty, candidate.value != currentLM.nullCandidateInCassette else {
        return nil
      }
      return .commit(committableDisplayText(sansReading: true) + candidate.value)
    case .pinyinFull, .pinyinAbbreviation:
      guard confirmHybridPinyinCandidate(candidate) else { return nil }
      return .composition
    }
  }

  // MARK: - Private helpers

  private func hybridFullPinyinOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard composer.parser.isPinyin else { return [] }
    let normalized = rawKeys.lowercased()
    let trie = Tekkon.PinyinTrie.shared(parser: composer.parser)
    let chopped = trie.chop(normalized)
    guard !chopped.isEmpty, chopped.joined() == normalized else { return [] }
    guard let map = composer.parser.mapZhuyinPinyin else { return [] }

    var possibleKeys: [Homa.PossibleKey] = []
    for syllable in chopped {
      guard let tonelessZhuyin = map[syllable] else { return [] }
      let tones = Tekkon.allowedIntonations.map { tone -> String in
        tonelessZhuyin + (tone == " " ? "" : String(tone))
      }
      possibleKeys.append(.multipleKeys(tones))
    }

    return currentLM.lxQuerier.grams(for: possibleKeys).map {
      HybridCandidateOffer(
        candidate: (keyArray: $0.keyArray, value: $0.current),
        source: .pinyinFull,
        score: $0.probability
      )
    }
  }

  private func hybridAbbreviatedPinyinOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard composer.parser.isPinyin else { return [] }
    guard let cells = furiousAbbreviatedCells(romaji: rawKeys.lowercased()) else { return [] }
    return currentLM.lxQuerier.abbreviatedWordCandidates(keysChopped: cells).map {
      HybridCandidateOffer(
        candidate: (keyArray: $0.keyArray, value: $0.current),
        source: .pinyinAbbreviation,
        score: $0.probability
      )
    }
  }
}
