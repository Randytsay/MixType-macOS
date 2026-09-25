// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - HybridCassettePinyinTypewriter

/// MixType Hybrid CIN + Pinyin 的單一事件分派入口。
///
/// 每個事件只會進入本 typewriter；CIN 與 Pinyin 都以唯讀 provider 查詢，
/// 不會把 `CassetteTypewriter` 與 `BPMFFullMatchTypewriter` 依序作用於同一份 state。
@frozen
public struct HybridCassettePinyinTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }

    if input.isBackSpace, !handler.calligrapher.isEmpty {
      if input.commonKeyModifierFlags == .option {
        handler.calligrapher.removeAll()
      } else {
        handler.calligrapher.removeLast()
      }
      refreshState(session: session)
      return true
    }

    if input.isEsc, !handler.calligrapher.isEmpty {
      handler.calligrapher.removeAll()
      refreshState(session: session)
      return true
    }

    // Hybrid 的 inline candidate pane 直接以目前畫面 selectionKeys 接受主鍵盤數字。
    // 不沿用 Cassette/Furious 的 Shift 判斷，確保 UI 標示「5」時 plain 5 就選該候選。
    if session.state.isCandidateContainer,
       input.isMainAreaNumKey,
       input.commonKeyModifierFlags.isEmpty,
       let ctlCandidate = session.candidateController(), ctlCandidate.visible {
      let matched = (input.mainAreaNumKeyChar ?? input.inputTextIgnoringModifiers ?? input.text)
        .lowercased()
      if let keyLabelIndex = session.selectionKeys.enumerated().first(where: {
        String($0.element).lowercased() == matched
      })?.offset,
         let candidateIndex = ctlCandidate.candidateIndexAtKeyLabelIndex(keyLabelIndex) {
        session.candidatePairSelectionConfirmed(at: candidateIndex)
        return true
      }
    }

    if session.state.isCandidateContainer,
       handler.handleCandidate(input: input, ignoringModifiers: true) {
      return true
    }

    if (input.isSpace || input.isEnter), !handler.calligrapher.isEmpty {
      guard !session.state.candidates.isEmpty else {
        // V0.2 ASCII fallback：完整 raw buffer 沒有任何中文候選時，不再蜂鳴或卡住。
        // 直接提交既有中文組字 + 原始 ASCII；Space 另外保留半形空格，Enter 僅完成提交。
        // 這是最保守的中英混打退路：只有「零候選」才會觸發，不會搶走任何可用中文候選。
        let textToCommit = handler.committableDisplayText(sansReading: true)
          + handler.calligrapher
          + (input.isSpace ? " " : "")
        session.switchState(State.ofCommitting(textToCommit: textToCommit))
        return true
      }
      let highlightedIndex = session.candidateController()?.highlightedIndex ?? 0
      let safeIndex = session.state.candidates.indices.contains(highlightedIndex) ? highlightedIndex : 0
      session.candidatePairSelectionConfirmed(at: safeIndex)
      return true
    }

    let skipRawHandling =
      input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHeld || input.isOptionHeld || input.isCommandHeld
    guard !skipRawHandling else { return nil }

    let rawInput = (input.inputTextIgnoringModifiers ?? input.text).lowercased()
    guard rawInput.count == 1 else { return nil }

    // 空白狀態下，普通數字預設交還 client。只有磁帶真的存在以該數字開頭的碼時，
    // 才把它視為 CIN raw key。如此可避免 Hybrid/Pinyin 把單獨的 0...9 當聲調或字根吞掉。
    if input.isMainAreaNumKey,
       input.commonKeyModifierFlags.isEmpty,
       handler.calligrapher.isEmpty,
       handler.assembler.isEmpty,
       !handler.currentLM.lxQuerier.cassetteHasKeyPrefix(rawInput) {
      return false
    }

    let isCassetteKey = handler.currentLM.isThisCassetteKeyAllowed(key: rawInput)
    let isPinyinKey = handler.composer.inputValidityCheck(charStr: rawInput)
    guard isCassetteKey || isPinyinKey else { return nil }

    handler.calligrapher.append(rawInput)
    refreshState(session: session)
    return true
  }

  // MARK: Private

  private func refreshState(session: Handler.Session) {
    if handler.calligrapher.isEmpty {
      if handler.assembler.isEmpty {
        session.switchState(.ofAbortion())
      } else {
        session.switchState(handler.generateStateOfInputting())
      }
      return
    }
    let offers = handler.hybridCandidateOffers(for: handler.calligrapher)
    var state = handler.generateStateOfInputting(guarded: true)
    state.candidates = offers.map(\.candidate)
    session.switchState(state)
  }
}
