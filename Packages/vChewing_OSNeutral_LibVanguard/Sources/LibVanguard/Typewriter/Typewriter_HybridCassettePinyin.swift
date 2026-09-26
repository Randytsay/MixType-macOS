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

    maintainNumericPassthroughContext(input)

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
      if trySplitASCIIAndHybridPinyinSuffix(session: session) {
        return true
      }
      refreshState(session: session)
      return true
    }

    let rawInput = (input.inputTextIgnoringModifiers ?? input.text).lowercased()
    guard rawInput.count == 1 else { return nil }

    // 空白 raw buffer 下，普通數字預設交還 client。只有磁帶真的存在以該數字開頭的碼時，
    // 才把它視為 CIN raw key。V0.3 flag 開啟時，額外只記住「已 passthrough」的數字 context，
    // 供後續 `3pm / 20kW / 300RT` suffix 判斷；數字本身絕不再次提交。
    if input.isMainAreaNumKey,
       input.commonKeyModifierFlags.isEmpty,
       handler.calligrapher.isEmpty,
       !handler.currentLM.lxQuerier.cassetteHasKeyPrefix(rawInput) {
      if handler.prefs.mixTypeMixedTokenSegmentationEnabled {
        if !handler.assembler.isEmpty {
          let priorChineseText = handler.committableDisplayText(sansReading: true)
          if !priorChineseText.isEmpty {
            session.switchState(.ofCommitting(textToCommit: priorChineseText))
          }
        }
        handler.mixTypePassthroughNumericPrefix.append(rawInput)
        return false
      }
      // Feature flag OFF 時完全維持 V0.2：只有 assembler 空白才直接 passthrough；
      // 已有中文組字時自然落回下方既有 CIN/Pinyin key routing。
      if handler.assembler.isEmpty { return false }
    }

    let isCassetteKey = handler.currentLM.isThisCassetteKeyAllowed(key: rawInput)
    let isPinyinKey = handler.composer.inputValidityCheck(charStr: rawInput)
    guard isCassetteKey || isPinyinKey else { return nil }

    handler.calligrapher.append(rawInput)
    if trySplitASCIIAndHybridPinyinSuffix(session: session) {
      return true
    }
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

  /// 清理只屬於「緊鄰前導數字」的 runtime context。
  /// 數字已經交給 client，因此這裡只能忘記 context，不能提交或刪除任何數字。
  private func maintainNumericPassthroughContext(_ input: some InputSignalProtocol) {
    guard handler.prefs.mixTypeMixedTokenSegmentationEnabled else {
      handler.mixTypePassthroughNumericPrefix.removeAll()
      return
    }
    guard !handler.mixTypePassthroughNumericPrefix.isEmpty, handler.calligrapher.isEmpty else { return }

    let visible = input.text.applyingTransformFW2HW(reverse: false)
    let scalars = visible.unicodeScalars
    let isSingleASCIIAlnum = scalars.count == 1 && scalars.allSatisfy { scalar in
      scalar.isASCII
        && ((0x30 ... 0x39).contains(scalar.value)
          || (0x41 ... 0x5A).contains(scalar.value)
          || (0x61 ... 0x7A).contains(scalar.value))
    }
    if !isSingleASCIIAlnum {
      handler.mixTypePassthroughNumericPrefix.removeAll()
    }
  }

  private func isRecognizedDigitLeadingMixedTokenSuffix(_ suffix: String) -> Bool {
    let numericPrefix = handler.mixTypePassthroughNumericPrefix
    guard !numericPrefix.isEmpty, numericPrefix.allSatisfy(\.isNumber) else { return false }
    let recognizedSuffixes: Set<String> = [
      "am", "pm",
      "W", "kW", "MW", "GW", "Wh", "kWh", "MWh", "GWh",
      "RT", "Hz", "kHz", "MHz", "GHz",
      "V", "kV", "A", "mA", "kA",
      "VA", "kVA", "MVA", "VAR", "kVAR", "MVAR",
    ]
    return recognizedSuffixes.contains(suffix)
  }

  /// V0.3 Phase A Batch 2：把「確定的 ASCII prefix + 可完整查到中文的 Pinyin suffix」
  /// 在同一個 Hybrid route 內切開。
  ///
  /// 例如 `meetinggai`：`meeting` 具有保守 English-word shape，且無法完整切成合法
  /// Pinyin 音節；`gai` 有 full-Pinyin 中文候選。此時只提交 ASCII prefix，保留
  /// `gai` 與候選窗，**不自動選「改」**。
  private func trySplitASCIIAndHybridPinyinSuffix(session: Handler.Session) -> Bool {
    guard handler.prefs.mixTypeMixedTokenSegmentationEnabled else { return false }
    let fullInput = handler.calligrapher
    guard fullInput.count >= 3,
          !isProtectedMixedToken(fullInput),
          fullInput.range(of: "^[A-Za-z0-9@:/._+%?&=#~-]+$", options: .regularExpression) != nil
    else {
      return false
    }

    // 使用者自己的詞條、CIN exact/quick 或 factory full-Pinyin 整段命中均優先保留；
    // 僅 composed/abbreviation 這類較弱的「碰巧可組」結果不得阻止明確 ASCII 邊界。
    let wholeOffers = handler.hybridCandidateOffers(for: fullInput)
    let hasAuthoritativeWholeOffer = wholeOffers.contains {
      switch $0.source {
      case .cassetteExact, .personalFullPinyin, .cassetteQuick, .pinyinFull,
           .mixedSegmented, .personalMixedPinyin, .personalInitials:
        return true
      case .pinyinComposed, .pinyinAbbreviation:
        return false
      }
    }
    guard !hasAuthoritativeWholeOffer else { return false }

    for prefixLength in 1 ..< fullInput.count {
      let splitIndex = fullInput.index(fullInput.startIndex, offsetBy: prefixLength)
      let prefix = String(fullInput[..<splitIndex])
      let suffix = String(fullInput[splitIndex...])
      guard suffix.count >= 2,
            suffix.range(of: "^[a-z]+$", options: .regularExpression) != nil,
            isConfidentASCIIIntentPrefix(prefix)
      else {
        continue
      }

      let suffixOffers = handler.hybridCandidateOffers(for: suffix)
      let hasStrongPinyinSuffix = suffixOffers.contains {
        switch $0.source {
        case .personalFullPinyin, .pinyinFull, .pinyinComposed, .personalMixedPinyin:
          return true
        case .cassetteExact, .cassetteQuick, .mixedSegmented, .personalInitials,
             .pinyinAbbreviation:
          return false
        }
      }
      guard hasStrongPinyinSuffix else { continue }

      let priorChineseText = handler.committableDisplayText(sansReading: true)
      let priorChineseKeyCount = handler.assembler.length
      if priorChineseKeyCount > 0, !priorChineseText.isEmpty {
        session.commit(text: priorChineseText)
        handler.assembler.cursor = 0
        for _ in 0 ..< priorChineseKeyCount {
          _ = handler.dropKey(direction: .front)
        }
      }

      handler.calligrapher = suffix
      var state = handler.generateStateOfInputting(guarded: true)
      state.candidates = suffixOffers.map { $0.candidate }
      state.textToCommit = prefix
      session.switchState(state)
      return true
    }
    return false
  }

  /// English shape 只是一層弱證據；若同一 prefix 本身能被完整切成合法 Pinyin，
  /// 預設不把它當成自動 mixed-token 邊界。只有兩類額外證據會升級為明確 ASCII：
  /// 1. 相鄰重複英文字母（例如 `meeting` 的 `ee`）；
  /// 2. 最長合法 Pinyin 前綴之後仍殘留至少 2 個字母（例如 `server`）。
  /// 這可避免把 `taida`、`taidag` 這類合法拼音或僅多一鍵的中間態誤切。
  private func isConfidentASCIIIntentPrefix(_ text: String) -> Bool {
    guard !isProtectedMixedToken(text) else { return false }
    return MixTypeEnglishIntent.isConfidentEnglishSegment(
      text,
      parser: handler.composer.parser
    )
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
    let shouldProtectASCII = handler.prefs.mixTypeMixedTokenSegmentationEnabled
      && (isProtectedMixedToken(handler.calligrapher)
        || isRecognizedDigitLeadingMixedTokenSuffix(handler.calligrapher))
    let offers = shouldProtectASCII
      ? []
      : handler.hybridCandidateOffers(for: handler.calligrapher)
    var state = handler.generateStateOfInputting(guarded: true)
    state.candidates = offers.map(\.candidate)
    session.switchState(state)
  }
}
