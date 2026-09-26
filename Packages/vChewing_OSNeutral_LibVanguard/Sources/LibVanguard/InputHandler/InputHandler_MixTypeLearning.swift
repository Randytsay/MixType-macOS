// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

extension InputHandlerProtocol {
  /// MixType 的「組句短語」學習入口。
  ///
  /// 只接受 assembler 已完成、且實際提交文字完全等於組句中文內容的情況。
  /// 這個 gate 刻意排除：單字、ASCII/符號混合、超過 6 字、讀音數量不對齊、
  /// 尚有 raw buffer 的提交。達門檻後升級到既有 Personal Lexicon，後續自然獲得
  /// full Pinyin / initials / mixed-prefix 查詢能力。
  public func observeMixTypeCompositionPhraseCommit(textToCommit: String) {
    guard prefs.mixTypeAutoPromotionEnabled else { return }
    guard calligrapher.isEmpty, mixedAlphanumericalBuffer.isEmpty else { return }
    guard composer.isEmpty else { return }

    let phrase = assembler.assembledSentence.values.joined()
    let readings = assembler.actualKeys
    guard textToCommit == phrase else { return }
    guard LXAssembly.CompositionPhraseLearningStore.isValidPhraseAndReadings(
      phrase: phrase,
      readings: readings
    ) else {
      return
    }

    switch currentLM.observeCompositionPhrasePromotion(
      phrase: phrase,
      readings: readings,
      threshold: prefs.mixTypeAutoPromotionThreshold
    ) {
    case .ignored, .alreadyPersonal:
      return
    case .pending:
      SessionHost.shared.saveCompositionPhraseLearningData(currentLM.isCHS)
    case .rejectedUnsupportedFactoryReading:
      // threshold 時已移除無法由 factory 驗證的 pending observation，立即落盤。
      SessionHost.shared.saveCompositionPhraseLearningData(currentLM.isCHS)
    case .promoted:
      // 先落長期 Personal，再落「已移除 observation」的 composition pending 檔。
      SessionHost.shared.savePersonalLexiconData(currentLM.isCHS)
      SessionHost.shared.saveCompositionPhraseLearningData(currentLM.isCHS)
    }
  }

  /// MixType 的「明確選字」學習入口。
  ///
  /// - 已是 Personal Lexicon：只更新 selectionCount / lastUsedAt。
  /// - 尚未進 Personal：在啟用 Auto Promotion 時累積 pending observation；達門檻後提升。
  /// - 純 CIN 路徑不參與 phonetic promotion，避免把字根碼表候選誤學成拼音詞。
  /// - Preview / highlight / canceled candidate 不會呼叫此 API，因此不計數。
  public func observeMixTypeExplicitSelection(
    _ candidate: CandidateInState,
    allowAutoPromotion: Bool = true
  ) {
    guard !candidate.value.isEmpty, !candidate.keyArray.isEmpty else { return }

    if currentLM.recordPersonalLexiconSelection(
      phrase: candidate.value,
      readings: candidate.keyArray
    ) {
      SessionHost.shared.savePersonalLexiconData(currentLM.isCHS)
      return
    }

    // 單字不進 Personal Lexicon Auto Promotion；拼音使用者最需要的是同一個
    // 無聲調讀音 bucket 內的候選偏好排序（例如 yao → 耀）。
    if candidate.value.count == 1,
       candidate.keyArray.count == 1,
       typingMode == .hybridCassettePinyin || typingMode == .pinyinKeyblock || typingMode == .pinyinFuriousTyping,
       let reading = candidate.keyArray.first,
       currentLM.recordSingleCharacterPreference(reading: reading, value: candidate.value) != nil {
      SessionHost.shared.saveSingleCharacterPreferenceData(currentLM.isCHS)
      return
    }

    guard allowAutoPromotion, prefs.mixTypeAutoPromotionEnabled else { return }
    if mixTypeBaseInputProvider == .cin, typingMode != .hybridCassettePinyin { return }

    switch currentLM.observePersonalLexiconPromotion(
      phrase: candidate.value,
      readings: candidate.keyArray,
      threshold: prefs.mixTypeAutoPromotionThreshold
    ) {
    case .ignored, .alreadyPersonal:
      return
    case .pending:
      SessionHost.shared.savePersonalLexiconPromotionData(currentLM.isCHS)
    case .rejectedUnsupportedFactoryReading:
      // threshold 時已移除無法由 factory 驗證的 pending observation，立即落盤。
      SessionHost.shared.savePersonalLexiconPromotionData(currentLM.isCHS)
    case .promoted:
      // 先落長期 Personal，再落「已移除該 observation」的 pending 檔。
      SessionHost.shared.savePersonalLexiconData(currentLM.isCHS)
      SessionHost.shared.savePersonalLexiconPromotionData(currentLM.isCHS)
    }
  }

  func mixTypeSingleCharacterPreference(
    for candidate: CandidateInState
  ) -> LXAssembly.SingleCharacterPreferenceEntry? {
    guard candidate.value.count == 1,
          candidate.keyArray.count == 1,
          let reading = candidate.keyArray.first
    else {
      return nil
    }
    return currentLM.singleCharacterPreference(reading: reading, value: candidate.value)
  }

  /// 只重排「單讀音＋單字」候選所在的位置，不改變長詞與其他 segment 的相對位置。
  /// 有學習紀錄的單字依 selectionCount、lastSelectedAt 排前；無紀錄者保留原始順序。
  func applyMixTypeSingleCharacterPreference(
    to candidates: [CandidateInState]
  ) -> [CandidateInState] {
    let indices = candidates.indices.filter {
      candidates[$0].value.count == 1 && candidates[$0].keyArray.count == 1
    }
    guard indices.count > 1 else { return candidates }

    let indexedSingles = indices.map { index in
      (originalIndex: index, candidate: candidates[index])
    }
    let sortedSingles = indexedSingles.sorted { lhs, rhs in
      let lhsPref = mixTypeSingleCharacterPreference(for: lhs.candidate)
      let rhsPref = mixTypeSingleCharacterPreference(for: rhs.candidate)
      let lhsRawCount = lhsPref?.selectionCount ?? 0
      let rhsRawCount = rhsPref?.selectionCount ?? 0
      let lhsCount = lhsRawCount >= LXAssembly.SingleCharacterPreferenceStore.rankingThreshold ? lhsRawCount : 0
      let rhsCount = rhsRawCount >= LXAssembly.SingleCharacterPreferenceStore.rankingThreshold ? rhsRawCount : 0
      if lhsCount != rhsCount { return lhsCount > rhsCount }
      let lhsDate = lhsCount > 0 ? (lhsPref?.lastSelectedAt ?? .distantPast) : .distantPast
      let rhsDate = rhsCount > 0 ? (rhsPref?.lastSelectedAt ?? .distantPast) : .distantPast
      if lhsDate != rhsDate { return lhsDate > rhsDate }
      return lhs.originalIndex < rhs.originalIndex
    }.map(\.candidate)

    var result = candidates
    for (targetIndex, candidate) in zip(indices, sortedSingles) {
      result[targetIndex] = candidate
    }
    return result
  }
}
