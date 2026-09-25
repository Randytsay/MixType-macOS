// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

extension InputHandlerProtocol {
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
    case .promoted:
      // 先落長期 Personal，再落「已移除該 observation」的 pending 檔。
      SessionHost.shared.savePersonalLexiconData(currentLM.isCHS)
      SessionHost.shared.savePersonalLexiconPromotionData(currentLM.isCHS)
    }
  }
}
