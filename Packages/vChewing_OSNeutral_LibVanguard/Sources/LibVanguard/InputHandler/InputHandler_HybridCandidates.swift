// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - HybridCandidateOffer

/// MixType Hybrid 內部使用的候選來源標記。
///
/// 不把來源資訊塞進全域 `CandidateInState`，避免影響既有候選窗與非 Hybrid 路徑。
struct HybridCandidateOffer {
  enum Source: Equatable {
    case cassetteExact
    case personalFullPinyin
    case cassetteQuick
    case pinyinFull
    case personalMixedPinyin
    case personalInitials
    case pinyinAbbreviation
  }

  let candidate: CandidateInState
  let source: Source
  let score: Double
  let personalEntryID: UUID?

  init(
    candidate: CandidateInState,
    source: Source,
    score: Double,
    personalEntryID: UUID? = nil
  ) {
    self.candidate = candidate
    self.source = source
    self.score = score
    self.personalEntryID = personalEntryID
  }
}

enum HybridCandidateSelectionOutcome {
  case commit(String)
  case composition
}

extension InputHandlerProtocol {
  /// 以 Hybrid raw-key buffer 唯讀生成候選。
  ///
  /// 排序固定為 CIN exact → Personal full Pinyin → CIN quick → full Pinyin
  /// → Personal mixed Pinyin prefix → Personal initials → abbreviated Pinyin；
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

    let personalMatches = currentLM.lxQuerier.personalLexiconMatches(for: rawKeys)
    groupedOffers.append(personalMatches.compactMap { match in
      guard match.kind == .fullPinyin else { return nil }
      return HybridCandidateOffer(
        candidate: (keyArray: match.entry.readings, value: match.entry.phrase),
        source: .personalFullPinyin,
        score: match.score,
        personalEntryID: match.entry.id
      )
    })

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
    let alreadyMatchedPersonalIDs = Set(personalMatches.map(\.entry.id))
    groupedOffers.append(hybridPersonalMixedPinyinOffers(
      for: rawKeys,
      excludingEntryIDs: alreadyMatchedPersonalIDs
    ))
    groupedOffers.append(personalMatches.compactMap { match in
      guard match.kind == .initials else { return nil }
      return HybridCandidateOffer(
        candidate: (keyArray: match.entry.readings, value: match.entry.phrase),
        source: .personalInitials,
        score: match.score,
        personalEntryID: match.entry.id
      )
    })
    groupedOffers.append(hybridAbbreviatedPinyinOffers(for: rawKeys))

    var seenValues = Set<String>()
    var merged: [HybridCandidateOffer] = []
    for offer in groupedOffers.flatMap({ $0 }) {
      let value = offer.candidate.value
      guard !value.isEmpty, value != currentLM.nullCandidateInCassette else { continue }
      guard seenValues.insert(value).inserted else { continue }
      merged.append(offer)
    }
    if shouldPreferHybridASCIIWord(rawKeys: rawKeys, offers: merged) {
      return []
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
    // `hybridCandidateOffers` 已經以顯示值去重；因此在確認階段，顯示值就是
    // 當前 raw-key buffer 內穩定且唯一的候選 identity。不要要求 UI state 裡
    // 保存的 keyArray 與第二次 lookup 完全一致：factory / user data 可能對同一
    // 顯示字提供多個等價讀音，重新查詢時 canonical keyArray 可能不同。
    guard let offer = offers.first(where: { $0.candidate.value == candidate.value }) else {
      return nil
    }
    let canonicalCandidate = offer.candidate

    switch offer.source {
    case .cassetteExact, .cassetteQuick:
      guard !canonicalCandidate.value.isEmpty,
            canonicalCandidate.value != currentLM.nullCandidateInCassette
      else {
        return nil
      }
      return .commit(committableDisplayText(sansReading: true) + canonicalCandidate.value)
    case .personalFullPinyin, .personalMixedPinyin, .personalInitials:
      guard confirmHybridPinyinCandidate(canonicalCandidate) else { return nil }
      observeMixTypeExplicitSelection(canonicalCandidate, allowAutoPromotion: false)
      return .composition
    case .pinyinFull, .pinyinAbbreviation:
      guard confirmHybridPinyinCandidate(canonicalCandidate) else { return nil }
      observeMixTypeExplicitSelection(canonicalCandidate)
      return .composition
    }
  }

  // MARK: - Private helpers

  private func shouldPreferHybridASCIIWord(
    rawKeys: String,
    offers: [HybridCandidateOffer]
  ) -> Bool {
    guard prefs.mixTypeEnglishIntentEnabled,
          MixTypeEnglishIntent.looksLikeEnglishWord(rawKeys),
          !offers.isEmpty
    else {
      return false
    }

    // Only suppress accidental factory abbreviation collisions. Any stronger or user-controlled
    // source keeps the Chinese candidate UI available.
    return offers.allSatisfy { $0.source == .pinyinAbbreviation }
  }

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

    let factoryGrams = currentLM.lxQuerier.hybridPhoneticFactoryGrams(for: possibleKeys)
    let userAndTemporaryGrams = currentLM.lxQuerier.grams(for: possibleKeys)
    var bestByValue: [String: Homa.Gram] = [:]
    for gram in factoryGrams + userAndTemporaryGrams {
      guard !gram.current.isEmpty else { continue }
      if let existing = bestByValue[gram.current], existing.probability >= gram.probability {
        continue
      }
      bestByValue[gram.current] = gram
    }

    let baseOffers = bestByValue.values.sorted { lhs, rhs in
      if lhs.probability != rhs.probability { return lhs.probability > rhs.probability }
      return lhs.current < rhs.current
    }.map {
      HybridCandidateOffer(
        candidate: (keyArray: $0.keyArray, value: $0.current),
        source: .pinyinFull,
        score: $0.probability
      )
    }

    let candidates = baseOffers.map(\.candidate)
    let reordered = applyMixTypeSingleCharacterPreference(to: candidates)
    let offerBySignature = Dictionary(
      uniqueKeysWithValues: baseOffers.map { offer in
        ("\(offer.candidate.keyArray.joined(separator: "\u{1F}"))\u{1E}\(offer.candidate.value)", offer)
      }
    )
    return reordered.compactMap { candidate in
      let signature = "\(candidate.keyArray.joined(separator: "\u{1F}"))\u{1E}\(candidate.value)"
      return offerBySignature[signature]
    }
  }

  private func hybridPersonalMixedPinyinOffers(
    for rawKeys: String,
    excludingEntryIDs: Set<UUID>
  ) -> [HybridCandidateOffer] {
    guard composer.parser.isPinyin else { return [] }
    let normalized = rawKeys.lowercased()
    let trie = Tekkon.PinyinTrie.shared(parser: composer.parser)
    let chunks = trie.chop(normalized)
    guard chunks.count >= 2,
          chunks.joined() == normalized,
          chunks.allSatisfy({ !trie.zhuyinReadings(forPinyinFragment: $0).isEmpty })
    else {
      return []
    }

    return currentLM.lxQuerier.personalLexiconMatches(pinyinPrefixes: chunks).compactMap { match in
      guard match.kind == .mixedPinyinPrefix,
            !excludingEntryIDs.contains(match.entry.id)
      else {
        return nil
      }
      return HybridCandidateOffer(
        candidate: (keyArray: match.entry.readings, value: match.entry.phrase),
        source: .personalMixedPinyin,
        score: match.score,
        personalEntryID: match.entry.id
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
