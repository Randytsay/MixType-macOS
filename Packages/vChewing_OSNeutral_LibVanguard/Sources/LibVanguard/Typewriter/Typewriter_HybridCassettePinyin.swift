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

    // Shift 產生的可列印 ASCII 是明確的英文／符號意圖，必須在候選選字邏輯之前處理。
    // 否則 Shift+2 會因 charactersIgnoringModifiers == "2" 而被誤認成「候選 2」。
    // 若前方仍有尚未確認的 Hybrid raw token（例如 `space`），一律按原樣提交為 ASCII，
    // 不因碰巧存在中文候選而自動選字；已經明確進入 Homa 的中文則照常先提交。
    if let shiftedASCII = resolveShiftedPrintableASCII(input) {
      if shouldBufferMixedTokenCharacter(shiftedASCII) {
        handler.calligrapher.append(shiftedASCII)
        refreshState(session: session)
        return true
      }
      let textToCommit = handler.committableDisplayText(sansReading: true)
        + handler.calligrapher
        + shiftedASCII
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      return true
    }

    // Hybrid 明確英文 override：
    // - Enter：原樣提交目前 raw token，不選中文候選。
    // - Shift+Space：原樣提交目前 raw token，並補一個半形空格。
    // 只在 raw token 非空時攔截；空狀態仍保留既有 Enter / Shift+Space 全域行為。
    if !handler.calligrapher.isEmpty, input.isEnter {
      let textToCommit = handler.committableDisplayText(sansReading: true) + handler.calligrapher
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
      return true
    }
    if !handler.calligrapher.isEmpty, input.isSpace, input.isShiftHeld {
      let textToCommit = handler.committableDisplayText(sansReading: true)
        + handler.calligrapher
        + " "
      session.switchState(State.ofCommitting(textToCommit: textToCommit))
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

    if input.isSpace, !handler.calligrapher.isEmpty {
      guard !session.state.candidates.isEmpty else {
        // V0.2 ASCII fallback：完整 raw buffer 沒有任何中文候選時，不再蜂鳴或卡住。
        // 直接提交既有中文組字 + 原始 ASCII，並保留半形空格。
        // 這是最保守的中英混打退路：只有「零候選」才會觸發，不會搶走任何可用中文候選。
        let textToCommit = handler.committableDisplayText(sansReading: true)
          + handler.calligrapher
          + " "
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

    if let mixedTokenCharacter = resolveMixedTokenCharacter(input) {
      handler.calligrapher.append(mixedTokenCharacter)
      refreshState(session: session)
      return true
    }

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

  private func resolveShiftedPrintableASCII(_ input: some InputSignalProtocol) -> String? {
    guard input.isShiftHeld,
          !input.isControlHeld,
          !input.isOptionHeld,
          !input.isCommandHeld
    else {
      return nil
    }

    var visibleText = input.text.applyingTransformFW2HW(reverse: false)
    let baseText = (input.inputTextIgnoringModifiers ?? input.text)
      .applyingTransformFW2HW(reverse: false)

    // 某些 client/event 只回報 base glyph（例如 Shift+2 仍回 "2"）。
    // 這時依目前 Latin keyboard layout + keyCode 還原真正可見的 shifted glyph。
    if visibleText == baseText {
      let keyboardLayout = LatinKeyboardMappings(rawValue: handler.prefs.basicKeyboardLayout) ?? .qwerty
      guard let mapped = keyboardLayout.mapTable[input.keyCode] else { return nil }
      visibleText = mapped.1.applyingTransformFW2HW(reverse: false)
    }

    let scalars = visibleText.unicodeScalars
    guard scalars.count == 1,
          let scalar = scalars.first,
          scalar.isASCII,
          (0x21 ... 0x7E).contains(scalar.value)
    else {
      return nil
    }
    return visibleText
  }

  /// V0.3 Phase A 的 deterministic ASCII-token gate。
  ///
  /// 只在 feature flag 開啟時生效；flag 關閉時完全沿用 V0.2 的 Shift-ASCII / raw-key routing。
  /// 一旦 token 出現大小寫、數字或 email/URL/unit 常見符號，就視為「受保護 ASCII token」，
  /// 後續 ASCII 字元不再送往 CIN/Pinyin 候選查詢。
  private func shouldBufferMixedTokenCharacter(_ character: String) -> Bool {
    guard handler.prefs.mixTypeMixedTokenSegmentationEnabled,
          isSinglePrintableASCII(character),
          character != " "
    else {
      return false
    }
    if isProtectedMixedToken(handler.calligrapher) { return true }
    if character.first?.isUppercase == true { return true }
    guard !handler.calligrapher.isEmpty else { return false }
    return mixedTokenSyntaxCharacters.contains(character)
  }

  /// 處理沒有 Shift 的 ASCII token 延伸，例如 `MacBookM6` 的一般字母/數字、
  /// `email@example.com` 的 `.`、以及 URL 的 `/`。
  private func resolveMixedTokenCharacter(_ input: some InputSignalProtocol) -> String? {
    guard handler.prefs.mixTypeMixedTokenSegmentationEnabled,
          !input.isShiftHeld
    else {
      return nil
    }
    let visible = input.text.applyingTransformFW2HW(reverse: false)
    guard isSinglePrintableASCII(visible), visible != " " else { return nil }

    if isProtectedMixedToken(handler.calligrapher) {
      return visible
    }
    if visible.first?.isUppercase == true {
      return visible
    }
    if visible.first?.isNumber == true,
       MixTypeEnglishIntent.looksLikeEnglishWord(handler.calligrapher) {
      return visible
    }
    guard !handler.calligrapher.isEmpty,
          mixedTokenSyntaxCharacters.contains(visible)
    else {
      return nil
    }
    return visible
  }

  private var mixedTokenSyntaxCharacters: Set<String> {
    Set(["@", ":", "/", ".", "_", "-", "+", "%", "?", "&", "=", "#", "~"])
  }

  private func isProtectedMixedToken(_ text: String) -> Bool {
    if text.unicodeScalars.contains(where: { scalar in
      guard scalar.isASCII else { return false }
      if (65 ... 90).contains(scalar.value) { return true }
      return mixedTokenSyntaxCharacters.contains(String(scalar))
    }) {
      return true
    }
    guard let firstDigit = text.firstIndex(where: \.isNumber) else { return false }
    return MixTypeEnglishIntent.looksLikeEnglishWord(String(text[..<firstDigit]))
  }

  private func isSinglePrintableASCII(_ text: String) -> Bool {
    let scalars = text.unicodeScalars
    guard scalars.count == 1, let scalar = scalars.first else { return false }
    return scalar.isASCII && (0x21 ... 0x7E).contains(scalar.value)
  }

  private func refreshState(session: Handler.Session) {
    if handler.calligrapher.isEmpty {
      if handler.assembler.isEmpty {
        session.switchState(.ofAbortion())
      } else {
        session.switchState(handler.generateStateOfInputting())
      }
      return
    }
    let offers = isProtectedMixedToken(handler.calligrapher)
      && handler.prefs.mixTypeMixedTokenSegmentationEnabled
      ? []
      : handler.hybridCandidateOffers(for: handler.calligrapher)
    var state = handler.generateStateOfInputting(guarded: true)
    state.candidates = offers.map(\.candidate)
    session.switchState(state)
  }
}
