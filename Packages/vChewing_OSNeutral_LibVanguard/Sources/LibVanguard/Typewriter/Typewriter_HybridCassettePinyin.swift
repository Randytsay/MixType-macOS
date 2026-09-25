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

    if session.state.isCandidateContainer,
       handler.handleCandidate(input: input, ignoringModifiers: true) {
      return true
    }

    if (input.isSpace || input.isEnter), !handler.calligrapher.isEmpty {
      guard !session.state.candidates.isEmpty else {
        handler.errorCallback?("Hybrid: no candidate for \(handler.calligrapher).")
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
