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
    case mixedSegmented
    case pinyinComposed
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

private struct HybridPinyinCompositionPathState {
  let score: Double
  let readings: [String]
  let value: String
}

enum HybridCandidateSelectionOutcome {
  case commit(String)
  case composition
}

extension InputHandlerProtocol {
  /// 以 Hybrid raw-key buffer 唯讀生成候選。
  ///
  /// 排序固定為 CIN exact → Personal full Pinyin → CIN quick → full Pinyin
  /// → deterministic Pinyin+English+Pinyin mixed candidate → composed Pinyin sentence
  /// → Personal mixed Pinyin prefix → Personal initials
  /// → abbreviated Pinyin；
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
    groupedOffers.append(hybridMixedSegmentedOffers(for: rawKeys))
    groupedOffers.append(hybridComposedPinyinOffers(for: rawKeys))
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
    // 若前方數字已 passthrough，使用者現在明確選了中文候選，代表數字 token 邊界到此結束。
    mixTypePassthroughNumericPrefix.removeAll()

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
    case .mixedSegmented:
      calligrapher.removeAll()
      composer.clear()
      invalidateFuriousTrail()
      return .commit(committableDisplayText(sansReading: true) + canonicalCandidate.value)
    case .pinyinComposed:
      guard confirmHybridComposedPinyinCandidate(canonicalCandidate) else { return nil }
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
    guard let possibleKeys = hybridPossiblePinyinKeys(for: rawKeys) else { return [] }

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

  /// V0.3 Phase A Batch 4：單一 raw buffer 內的 Pinyin + English + Pinyin。
  ///
  /// 例如 `jintianmeetinggai` 會產生 `今天meeting改` 這類整體候選，但絕不
  /// 在候選確認前自動提交任何中文字。中間 ASCII 必須通過較強的 English gate；
  /// 兩側則只接受 full/composed Personal/factory Pinyin，避免 initials/abbreviation
  /// 的弱匹配把普通拼音句誤切成中英混打。
  private func hybridMixedSegmentedOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard prefs.mixTypeMixedTokenSegmentationEnabled,
          assembler.isEmpty,
          composer.parser.isPinyin,
          (8 ... 48).contains(rawKeys.count),
          rawKeys.range(of: "^[a-z]+$", options: .regularExpression) != nil
    else {
      return []
    }

    let count = rawKeys.count
    var results: [HybridCandidateOffer] = []
    var seenValues = Set<String>()

    // prefix/suffix 至少各 2 字母；English 中段至少 4 字母。
    for middleStartOffset in 2 ... max(2, count - 6) {
      let minimumMiddleEnd = middleStartOffset + 4
      guard minimumMiddleEnd <= count - 2 else { continue }
      for middleEndOffset in minimumMiddleEnd ... (count - 2) {
        let prefixEnd = rawKeys.index(rawKeys.startIndex, offsetBy: middleStartOffset)
        let middleEnd = rawKeys.index(rawKeys.startIndex, offsetBy: middleEndOffset)
        let prefixRaw = String(rawKeys[..<prefixEnd])
        let middleRaw = String(rawKeys[prefixEnd ..< middleEnd])
        let suffixRaw = String(rawKeys[middleEnd...])

        guard MixTypeEnglishIntent.isConfidentEnglishSegment(
          middleRaw,
          parser: composer.parser
        ) else {
          continue
        }

        let prefixOffers = hybridStrongPinyinSegmentOffers(for: prefixRaw).filter {
          $0.candidate.keyArray.count >= 2 && $0.candidate.value.count >= 2
        }
        guard !prefixOffers.isEmpty else { continue }
        let suffixOffers = hybridStrongPinyinSegmentOffers(for: suffixRaw)
        guard !suffixOffers.isEmpty else { continue }

        for prefix in prefixOffers.prefix(4) {
          for suffix in suffixOffers.prefix(4) {
            let value = prefix.candidate.value + middleRaw + suffix.candidate.value
            guard seenValues.insert(value).inserted else { continue }
            results.append(
              HybridCandidateOffer(
                candidate: (
                  keyArray: prefix.candidate.keyArray + suffix.candidate.keyArray,
                  value: value
                ),
                source: .mixedSegmented,
                score: prefix.score + suffix.score + Double(middleRaw.count) * 0.001
              )
            )
          }
        }
      }
    }

    return results.sorted { lhs, rhs in
      if lhs.score != rhs.score { return lhs.score > rhs.score }
      return lhs.candidate.value < rhs.candidate.value
    }.prefix(12).map { $0 }
  }

  private func hybridStrongPinyinSegmentOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard hybridPossiblePinyinKeys(for: rawKeys) != nil else { return [] }

    var offers: [HybridCandidateOffer] = []
    offers.append(contentsOf: currentLM.lxQuerier.personalLexiconMatches(for: rawKeys).compactMap { match in
      guard match.kind == .fullPinyin else { return nil }
      return HybridCandidateOffer(
        candidate: (keyArray: match.entry.readings, value: match.entry.phrase),
        source: .personalFullPinyin,
        score: match.score,
        personalEntryID: match.entry.id
      )
    })
    offers.append(contentsOf: hybridFullPinyinOffers(for: rawKeys))
    offers.append(contentsOf: hybridComposedPinyinOffers(for: rawKeys))

    var seen = Set<String>()
    return offers.filter { seen.insert($0.candidate.value).inserted }
  }

  /// 對「factory 沒有整句詞條、但每個音節都可由既有詞/字組句」的完整拼音，
  /// 用一個乾淨的 Homa scratch 組字器生成最佳句子候選。
  ///
  /// 例如 `guolaiyixia` 沒有四字 factory gram，但 `過來` + `一下` 均在庫，
  /// 因此 scratch 可得到 `過來一下`。這裡只提供第一次可選能力，不把結果直接
  /// 寫成詞條；真正持久化仍交給 Composition Phrase Learning 的提交門檻。
  private func hybridComposedPinyinOffers(for rawKeys: String) -> [HybridCandidateOffer] {
    guard assembler.isEmpty else { return [] }
    guard let possibleKeys = hybridPossiblePinyinKeys(for: rawKeys) else { return [] }
    guard (2 ... LXAssembly.CompositionPhraseLearningStore.maximumPhraseLength).contains(possibleKeys.count) else {
      return []
    }

    let keyCount = possibleKeys.count
    let beamWidth = 16
    let gramsPerSpan = 24
    let resultLimit = 12
    var states = Array(repeating: [HybridPinyinCompositionPathState](), count: keyCount + 1)
    states[0] = [.init(score: 0, readings: [], value: "")]

    func keepBest(
      _ candidates: [HybridPinyinCompositionPathState],
      limit: Int
    ) -> [HybridPinyinCompositionPathState] {
      var seen = Set<String>()
      return candidates.sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.value < rhs.value
      }.filter { item in
        let signature = "\(item.readings.joined(separator: "\u{1F}"))\u{1E}\(item.value)"
        return seen.insert(signature).inserted
      }.prefix(limit).map { $0 }
    }

    for start in 0 ..< keyCount where !states[start].isEmpty {
      let maxLength = min(assembler.maxSegLength, keyCount - start)
      guard maxLength > 0 else { continue }
      for length in 1 ... maxLength {
        let end = start + length
        let query = Array(possibleKeys[start ..< end])
        var seenGramSignatures = Set<String>()
        let grams = currentLM.lxQuerier.hybridPhoneticGrams(for: query)
          .filter {
            $0.isUnigram
              && $0.keyArray.count == length
              && $0.current.count == length
          }
          .sorted {
            if $0.probability != $1.probability { return $0.probability > $1.probability }
            return $0.current < $1.current
          }
          .filter { gram in
            let signature = "\(gram.keyArray.joined(separator: "\u{1F}"))\u{1E}\(gram.current)"
            return seenGramSignatures.insert(signature).inserted
          }
          .prefix(gramsPerSpan)

        guard !grams.isEmpty else { continue }
        var expanded = states[end]
        for prefix in states[start] {
          for gram in grams {
            expanded.append(
              .init(
                score: prefix.score + gram.probability,
                readings: prefix.readings + gram.keyArray,
                value: prefix.value + gram.current
              )
            )
          }
        }
        states[end] = keepBest(expanded, limit: beamWidth)
      }
    }

    var offers: [HybridCandidateOffer] = []
    for state in keepBest(states[keyCount], limit: resultLimit) {
      guard LXAssembly.CompositionPhraseLearningStore.isValidPhraseAndReadings(
        phrase: state.value,
        readings: state.readings
      ) else {
        continue
      }
      let candidate: CandidateInState = (keyArray: state.readings, value: state.value)
      guard canReproduceHybridComposedPinyinCandidate(candidate) else { continue }
      offers.append(
        HybridCandidateOffer(
          candidate: candidate,
          source: .pinyinComposed,
          score: state.score
        )
      )
    }
    return offers
  }

  /// `rawKeys` 必須能被完整切成合法漢語拼音音節；每音節展開成所有聲調讀音。
  private func hybridPossiblePinyinKeys(for rawKeys: String) -> [Homa.PossibleKey]? {
    guard composer.parser.isPinyin else { return nil }
    let normalized = rawKeys.lowercased()
    let trie = Tekkon.PinyinTrie.shared(parser: composer.parser)
    let chopped = trie.chop(normalized)
    guard !chopped.isEmpty, chopped.joined() == normalized else { return nil }
    guard let map = composer.parser.mapZhuyinPinyin else { return nil }

    var possibleKeys: [Homa.PossibleKey] = []
    possibleKeys.reserveCapacity(chopped.count)
    for syllable in chopped {
      guard let tonelessZhuyin = map[syllable] else { return nil }
      let tones = Tekkon.allowedIntonations.map { tone -> String in
        tonelessZhuyin + (tone == " " ? "" : String(tone))
      }
      possibleKeys.append(.multipleKeys(tones))
    }
    return possibleKeys
  }

  /// composed candidate 並不存在一個「整句 factory gram」，因此不能用整節 override。
  /// 直接插入 scratch 已確認過的實際讀音，讓真實 Homa 依同一 LM 自然組句即可。
  @discardableResult
  private func confirmHybridComposedPinyinCandidate(_ candidate: CandidateInState) -> Bool {
    guard assembler.isEmpty,
          candidate.keyArray.count >= 2,
          candidate.keyArray.count == candidate.value.count
    else {
      return false
    }
    let backup = assembler.copy
    let keys = candidate.keyArray.map { Homa.PossibleKey.singleKey($0) }
    guard (try? assembler.insertKeys(keys)) != nil,
          assembler.actualKeys == candidate.keyArray,
          assembler.assembledSentence.values.joined() == candidate.value
    else {
      assembler = backup
      return false
    }
    calligrapher.removeAll()
    composer.clear()
    invalidateFuriousTrail()
    return true
  }

  private func canReproduceHybridComposedPinyinCandidate(_ candidate: CandidateInState) -> Bool {
    guard candidate.keyArray.count >= 2,
          candidate.keyArray.count == candidate.value.count
    else {
      return false
    }
    let scratch = Homa.Assembler(
      gramQuerier: assembler.gramQuerier,
      gramAvailabilityChecker: assembler.gramAvailabilityChecker
    )
    scratch.maxSegLength = assembler.maxSegLength
    let keys = candidate.keyArray.map { Homa.PossibleKey.singleKey($0) }
    guard (try? scratch.insertKeys(keys)) != nil else { return false }
    return scratch.actualKeys == candidate.keyArray
      && scratch.assembledSentence.values.joined() == candidate.value
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
