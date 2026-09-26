// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import LXAssemblyMaterials4Tests
import Shared
import Tekkon
import Testing

@testable import LexiconAssembly
@testable import LibVanguard

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test
  func test_IH090_HybridTypingModeMatrix() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.composer.isPinyinMode)
    #expect(testHandler.typingMode == .cassette)

    testHandler.prefs.hybridCassettePinyinEnabled = true
    #expect(testHandler.typingMode == .hybridCassettePinyin)

    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    #expect(!testHandler.prefs.pinyinTypingEnabled)
    #expect(!testHandler.composer.isPinyinMode)
    #expect(testHandler.typingMode == .cassette)

    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.ensureKeyboardParser()
    #expect(testHandler.typingMode == .pinyinFuriousTyping)

    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.typingMode == .bopomofoKeyblock)
  }

  @Test
  func test_IH091_HybridPhaseAUsesSingleCassetteCompatibleRoute() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer { LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.autoCompositeWithLongestPossibleCassetteKey = false
    testHandler.ensureKeyboardParser()

    #expect(testHandler.typingMode == .hybridCassettePinyin)
    #expect(testHandler.composer.isPinyinMode)

    let handled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "q").asEvent)

    #expect(handled)
    #expect(testHandler.calligrapher == "q")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.recentCommissions.isEmpty)
  }

  @Test
  func test_IH092_HybridMergeKeepsCassettePriorityAndDeduplicates() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你", score: 10),
      Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "悄", score: 9),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let offers = testHandler.hybridCandidateOffers(for: "ni")
    let values = offers.map(\.candidate.value)
    let firstPinyin = try #require(offers.firstIndex(where: { $0.source == .pinyinFull }))
    let firstCassette = try #require(offers.firstIndex(where: { $0.source == .cassetteExact }))

    #expect(firstCassette < firstPinyin)
    #expect(values.contains("你"))
    #expect(values.filter { $0 == "悄" }.count == 1)
    #expect(offers.first(where: { $0.candidate.value == "悄" })?.source == .cassetteExact)
  }

  @Test
  func test_IH093_HybridFullPinyinPhraseCanBeSelectedAndCommitted() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你", score: 5),
      Homa.Gram(keyArray: ["ㄏㄠˇ"], value: "好", score: 5),
      Homa.Gram(keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"], value: "你好", score: 10),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nihao")

    #expect(testHandler.typingMode == .hybridCassettePinyin)
    #expect(testHandler.calligrapher == "nihao")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.isEmpty)
    #expect(testSession.state.displayedText.contains("nihao"))

    let candidateIndex = try #require(testSession.state.candidates.firstIndex(where: { $0.value == "你好" }))
    let offers = testHandler.hybridCandidateOffers(for: "nihao")
    #expect(offers.contains { $0.source == .pinyinFull && $0.candidate.value == "你好" })

    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄧˇ", "ㄏㄠˇ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["你好"])
    #expect(testSession.recentCommissions.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "你好")
  }

  @Test
  func test_IH094_HybridAbbreviationCanBeSelectedAndCommitted() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"], value: "野獸先輩", score: 10),
      Homa.Gram(keyArray: ["ㄧㄝ"], value: "椰", score: 1),
      Homa.Gram(keyArray: ["ㄕㄡ"], value: "收", score: 1),
      Homa.Gram(keyArray: ["ㄒㄧㄢ"], value: "先", score: 1),
      Homa.Gram(keyArray: ["ㄅㄟ"], value: "杯", score: 1),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("ysxb")

    #expect(testHandler.calligrapher == "ysxb")
    #expect(testHandler.composer.romajiBuffer.isEmpty)
    let offers = testHandler.hybridCandidateOffers(for: "ysxb")
    #expect(offers.contains {
      $0.source == .pinyinAbbreviation && $0.candidate.value == "野獸先輩"
    })

    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "野獸先輩" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄧㄝ", "ㄕㄡ", "ㄒㄧㄢ", "ㄅㄟ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["野獸先輩"])

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "野獸先輩")
  }

  @Test
  func test_IH095_HybridFactoryPinyinSmoke() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let directFactory = testHandler.currentLM.factoryCoreUnigramsFor(
      key: "ㄋㄥˊ-ㄌㄧㄡˊ",
      keyArray: ["ㄋㄥˊ", "ㄌㄧㄡˊ"]
    )
    #expect(directFactory.contains { $0.current == "能留" })

    // 測試詞庫不含「你好」，使用其中真實存在的雙音節原廠詞「能留」。
    let offers = testHandler.hybridCandidateOffers(for: "nengliu")
    #expect(offers.contains {
      $0.source == .pinyinFull
        && $0.candidate.keyArray == ["ㄋㄥˊ", "ㄌㄧㄡˊ"]
        && $0.candidate.value == "能留"
    })
  }

  @Test
  func test_IH096_HybridPlainDigitSelectsCandidateWhenCassetteSelectionKeysOverlapRoots() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    let cin = """
    %ename HybridDigitSelectionFixture
    %cname HybridDigitSelectionFixture
    %sname HDIGIT
    %selkey 0123456789
    %chardef begin
    a5 測
    ab 字
    %chardef end
    """
    let cinURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("hybrid-digit-selection-\(UUID().uuidString).cin")
    try cin.write(to: cinURL, atomically: true, encoding: .utf8)
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      try? FileManager.default.removeItem(at: cinURL)
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testSession.mockCandidateController = nil
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LXAssembly.LXFacade.loadCassetteData(path: cinURL.path)
    #expect(testHandler.currentLM.areCassetteCandidateKeysShiftHeld)

    let values = ["甲", "乙", "丙", "丁", "戊", "己"]
    for (offset, value) in values.enumerated() {
      testHandler.currentLM.insertTemporaryData(
        unigram: .init(keyArray: ["ㄋㄥˊ"], value: value, score: 100 - Double(offset)),
        isFiltering: false
      )
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("neng")
    #expect(testSession.state.candidates.prefix(values.count).map(\.value) == values)
    testSession.installMockCandidateController(visible: true, capacityPerPage: 10)
    testSession.selectionKeys = "0123456789"

    let digit5 = KBEvent.KeyEventData(chars: "5", keyCode: 23).asEvent
    #expect(testHandler.triageInput(event: digit5))
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["己"])
  }

  @Test
  func test_IH097_HybridLeadingDigitPassesThroughWhenNoCassetteCodeStartsWithDigit() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    let cin = """
    %ename HybridLeadingDigitFixture
    %cname HybridLeadingDigitFixture
    %sname HLEADDIGIT
    %selkey 0123456789
    %chardef begin
    a5 測
    ab 字
    %chardef end
    """
    let cinURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("hybrid-leading-digit-\(UUID().uuidString).cin")
    try cin.write(to: cinURL, atomically: true, encoding: .utf8)
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      try? FileManager.default.removeItem(at: cinURL)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LXAssembly.LXFacade.loadCassetteData(path: cinURL.path)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let digit5 = KBEvent.KeyEventData(chars: "5", keyCode: 23).asEvent
    #expect(!testHandler.triageInput(event: digit5))
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testSession.state.type == .ofEmpty)
  }

  @Test
  func test_IH098_HybridLeadingDigitStillFeedsCassetteWhenCodePrefixExists() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    let cin = """
    %ename HybridDigitPrefixFixture
    %cname HybridDigitPrefixFixture
    %sname HDIGITPREFIX
    %selkey 1234567890
    %chardef begin
    5a 測
    ab 字
    %chardef end
    """
    let cinURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("hybrid-digit-prefix-\(UUID().uuidString).cin")
    try cin.write(to: cinURL, atomically: true, encoding: .utf8)
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      try? FileManager.default.removeItem(at: cinURL)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    LXAssembly.LXFacade.loadCassetteData(path: cinURL.path)
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    #expect(testHandler.currentLM.lxQuerier.cassetteHasKeyPrefix("5"))
    let digit5 = KBEvent.KeyEventData(chars: "5", keyCode: 23).asEvent
    #expect(testHandler.triageInput(event: digit5))
    #expect(testHandler.calligrapher == "5")
  }

  @Test
  func test_IH099_HybridSelectionResolvesByDeduplicatedDisplayValue() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你", score: 5),
      Homa.Gram(keyArray: ["ㄏㄠˇ"], value: "好", score: 5),
      Homa.Gram(keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"], value: "你好", score: 10),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nihao")
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "你好" })
    )

    // 模擬 production candidate UI 持有同一顯示值、但其 keyArray 與重新查詢後的
    // canonical offer 不完全相同。選字仍應以 Hybrid 已去重的顯示值解析來源。
    var staleState = testSession.state
    staleState.candidates[candidateIndex] = (keyArray: ["ㄨㄟˇ"], value: "你好")
    testSession.switchState(staleState)
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄧˇ", "ㄏㄠˇ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["你好"])
  }

  @Test
  func test_IH100_HybridFactoryPinyinSelectionCanEnterAssemblerWithCassetteEnabled() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nengliu")
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "能留" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄥˊ", "ㄌㄧㄡˊ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["能留"])
  }

  @Test
  func test_IH101_HybridFactoryAbbreviationCanEnterAssemblerWithCassetteEnabled() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nl")
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "能留" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄋㄥˊ", "ㄌㄧㄡˊ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["能留"])
  }

  @Test
  func test_IH102_HybridLongFullPinyinRawBufferAcceptsEveryKey() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let sequence = "taidanengyuan"
    var expected = ""
    for char in sequence {
      let text = String(char)
      let handled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: text).asEvent)
      expected.append(char)
      #expect(handled, "Hybrid rejected key \(text) after prefix \(expected)")
      #expect(testHandler.calligrapher == expected)
    }
  }

  @Test
  func test_IH103_HybridNoCandidateSpaceFallsBackToASCIIWithoutError() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("taidanengyuan")
    #expect(testHandler.calligrapher == "taidanengyuan")
    #expect(testSession.state.candidates.isEmpty)

    let handled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ").asEvent)
    #expect(handled)
    #expect(testSession.recentCommissions.joined() == "taidanengyuan ")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testSession.state.type == .ofEmpty)
  }

  @Test
  func test_IH104_HybridKnownPinyinSpaceStillSelectsChineseCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nengliu")
    #expect(testSession.state.candidates.contains { $0.value == "能留" })
    let targetIndex = try #require(testSession.state.candidates.firstIndex { $0.value == "能留" })
    testSession.installMockCandidateController(visible: true, capacityPerPage: 9).highlightedIndex = targetIndex

    let handled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ").asEvent)
    #expect(handled)
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["能留"])
  }

  @Test(arguments: ["taidanengyuan", "tdny"])
  func test_IH105_HybridPersonalLexiconFullAndInitialsSelectIntoHoma(rawKey: String) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    testHandler.currentLM.replacePersonalLexiconEntries([
      .init(
        phrase: "台達能源",
        readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
        pinyinTokens: ["tai", "da", "neng", "yuan"],
        fullPinyinKey: "taidanengyuan",
        initialsKey: "tdny",
        source: .manual,
        pinned: true
      ),
    ])

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence(rawKey)
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "台達能源" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"])
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["台達能源"])
  }

  @Test
  func test_IH106_HybridNoCandidateFallbackCommitsPriorChinesePlusASCII() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nengliu")
    let chineseIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "能留" })
    )
    testSession.candidatePairSelectionConfirmed(at: chineseIndex)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["能留"])

    typeSentence("taidanengyuan")
    #expect(testHandler.calligrapher == "taidanengyuan")
    #expect(testSession.state.candidates.isEmpty)

    let handled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ").asEvent)
    #expect(handled)
    #expect(testSession.recentCommissions.joined() == "能留taidanengyuan ")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test(arguments: [
    (chars: "@", charsSansModifiers: "2", keyCode: UInt16(19), expected: "@"),
    (chars: "2", charsSansModifiers: "2", keyCode: UInt16(19), expected: "@"),
    (chars: "G", charsSansModifiers: "g", keyCode: UInt16(5), expected: "G"),
    (chars: "/", charsSansModifiers: "/", keyCode: UInt16(44), expected: "?"),
  ])
  func test_IH107_HybridShiftASCIIUsesVisibleGlyph(
    scenario: (chars: String, charsSansModifiers: String, keyCode: UInt16, expected: String)
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = false
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let event = KBEvent.KeyEventData(
      flags: .shift,
      chars: scenario.chars,
      charsSansModifiers: scenario.charsSansModifiers,
      keyCode: scenario.keyCode
    ).asEvent
    #expect(testHandler.triageInput(event: event))
    #expect(testSession.recentCommissions.joined() == scenario.expected)
    #expect(testHandler.calligrapher.isEmpty)
  }

  @Test
  func test_IH108_HybridShiftAtCommitsPendingRawAsASCIIInsteadOfSelectingCandidate() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = false
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("nengliu")
    #expect(testHandler.calligrapher == "nengliu")
    #expect(!testSession.state.candidates.isEmpty, "fixture should exercise candidate-window collision")

    let shift2 = KBEvent.KeyEventData(
      flags: .shift,
      chars: "@",
      charsSansModifiers: "2",
      keyCode: 19
    ).asEvent
    #expect(testHandler.triageInput(event: shift2))
    #expect(testSession.recentCommissions.joined() == "nengliu@")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test(arguments: [
    (trigger: "enter", expectTrailingSpace: false),
    (trigger: "shiftSpace", expectTrailingSpace: true),
  ])
  func test_IH109_HybridExplicitEnglishOverrideBeatsChineseCandidate(
    scenario: (trigger: String, expectTrailingSpace: Bool)
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    // `nengliu` has a valid Chinese candidate in the test factory lexicon.
    // Enter / Shift+Space must nevertheless preserve the literal raw token when the user explicitly asks for English.
    typeSentence("nengliu")
    #expect(!testSession.state.candidates.isEmpty)
    #expect(testHandler.calligrapher == "nengliu")

    let event: KBEvent
    switch scenario.trigger {
    case "shiftSpace":
      event = KBEvent.KeyEventData(flags: .shift, chars: " ", charsSansModifiers: " ", keyCode: 49).asEvent
    default:
      event = KBEvent.KeyEventData.dataEnterReturn.asEvent
    }
    #expect(testHandler.triageInput(event: event))
    #expect(testSession.recentCommissions.joined() == (scenario.expectTrailingSpace ? "nengliu " : "nengliu"))
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test
  func test_IH110_HybridPersonalSelectionLearnsAndRequestsPersistence() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    var saveCount = 0
    SessionHost.shared.savePersonalLexiconData = { _ in saveCount += 1 }
    defer {
      SessionHost.shared.savePersonalLexiconData = { _ in }
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      pinned: true
    )
    testHandler.currentLM.replacePersonalLexiconEntries([entry])

    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("tdny")
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "台達能源" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    let learned = try #require(testHandler.currentLM.personalLexiconEntries.first)
    #expect(learned.selectionCount == 1)
    #expect(learned.lastUsedAt != nil)
    #expect(saveCount == 1)
  }

  @Test
  func test_IH520_MixTypeBaseProviderDerivesFromExistingPreferences() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.mixTypeBaseInputProvider == .cin)

    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.mixTypeBaseInputProvider == .pinyin)

    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.mixTypeBaseInputProvider == .zhuyin)
  }

  @Test
  func test_IH521_NativePinyinHomaSeesPersonalLexicon() throws {
    try verifyNativePhoneticPersonalLexicon(parser: .ofHanyuPinyin, expectedProvider: .pinyin)
  }

  @Test
  func test_IH522_NativeZhuyinHomaSeesPersonalLexicon() throws {
    try verifyNativePhoneticPersonalLexicon(parser: .ofStandard, expectedProvider: .zhuyin)
  }

  @Test
  func test_IH523_HybridExplicitFactorySelectionAutoPromotesAtThreshold() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldEnabled = testHandler.prefs.mixTypeAutoPromotionEnabled
    let oldThreshold = testHandler.prefs.mixTypeAutoPromotionThreshold
    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    var personalSaveCount = 0
    var pendingSaveCount = 0
    LXAssembly.LXFacade.asyncLoadingUserData = false
    SessionHost.shared.savePersonalLexiconData = { _ in personalSaveCount += 1 }
    SessionHost.shared.savePersonalLexiconPromotionData = { _ in pendingSaveCount += 1 }
    defer {
      testHandler.prefs.mixTypeAutoPromotionEnabled = oldEnabled
      testHandler.prefs.mixTypeAutoPromotionThreshold = oldThreshold
      SessionHost.shared.savePersonalLexiconData = { _ in }
      SessionHost.shared.savePersonalLexiconPromotionData = { _ in }
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.currentLM.replacePersonalLexiconPromotionObservations([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    testHandler.prefs.mixTypeAutoPromotionEnabled = true
    testHandler.prefs.mixTypeAutoPromotionThreshold = 3
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    for expectedCount in 1 ... 3 {
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
      typeSentence("nengliu")

      // Merely displaying the candidate must never count as a selection.
      let beforeSelection = testHandler.currentLM.personalLexiconPromotionObservations.first?.selectionCount ?? 0
      #expect(beforeSelection == expectedCount - 1)

      let candidateIndex = try #require(
        testSession.state.candidates.firstIndex(where: { $0.value == "能留" })
      )
      testSession.candidatePairSelectionConfirmed(at: candidateIndex)

      if expectedCount < 3 {
        #expect(testHandler.currentLM.personalLexiconEntries.isEmpty)
        #expect(testHandler.currentLM.personalLexiconPromotionObservations.first?.selectionCount == expectedCount)
      }
    }

    let promoted = try #require(testHandler.currentLM.personalLexiconEntries.first)
    #expect(promoted.phrase == "能留")
    #expect(promoted.source == .autoPromoted)
    #expect(promoted.fullPinyinKey == "nengliu")
    #expect(promoted.initialsKey == "nl")
    #expect(promoted.selectionCount == 3)
    #expect(testHandler.currentLM.personalLexiconPromotionObservations.isEmpty)
    #expect(personalSaveCount == 1)
    #expect(pendingSaveCount == 3)
  }

  @Test(arguments: [
    (raw: "space", expected: true),
    (raw: "hello", expected: true),
    (raw: "meeting", expected: true),
    (raw: "server", expected: true),
    (raw: "tdny", expected: false),
    (raw: "ysxb", expected: false),
    (raw: "jngsfa", expected: false),
    (raw: "nl", expected: false),
  ])
  func test_IH524_MixTypeConservativeEnglishWordShape(
    scenario: (raw: String, expected: Bool)
  ) {
    #expect(MixTypeEnglishIntent.looksLikeEnglishWord(scenario.raw) == scenario.expected)
  }

  @Test
  func test_IH525_SingleCharacterPreferencePromotesFrequentlySelectedYao() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    testHandler.currentLM.replaceSingleCharacterPreferenceEntries([])
    defer { testHandler.currentLM.replaceSingleCharacterPreferenceEntries([]) }

    let candidates: [CandidateInState] = [
      (keyArray: ["ㄧㄠˋ"], value: "要"),
      (keyArray: ["ㄧㄠˋ"], value: "藥"),
      (keyArray: ["ㄧㄠˋ"], value: "耀"),
    ]
    #expect(testHandler.applyMixTypeSingleCharacterPreference(to: candidates).map(\.value) == ["要", "藥", "耀"])

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    for offset in 0 ..< 2 {
      #expect(
        testHandler.currentLM.recordSingleCharacterPreference(
          reading: "ㄧㄠˋ",
          value: "耀",
          now: now.addingTimeInterval(Double(offset))
        ) != nil
      )
    }
    #expect(testHandler.applyMixTypeSingleCharacterPreference(to: candidates).map(\.value) == ["要", "藥", "耀"])

    #expect(
      testHandler.currentLM.recordSingleCharacterPreference(
        reading: "ㄧㄠˋ",
        value: "耀",
        now: now.addingTimeInterval(2)
      ) != nil
    )

    let reordered = testHandler.applyMixTypeSingleCharacterPreference(to: candidates)
    #expect(reordered.map(\.value) == ["耀", "要", "藥"])
  }

  @Test
  func test_IH526_ExplicitPinyinSingleCharacterSelectionPersistsPreference() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    var saveCount = 0
    SessionHost.shared.saveSingleCharacterPreferenceData = { _ in saveCount += 1 }
    defer {
      SessionHost.shared.saveSingleCharacterPreferenceData = { _ in }
      testHandler.currentLM.replaceSingleCharacterPreferenceEntries([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testHandler.currentLM.replaceSingleCharacterPreferenceEntries([])
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()

    testHandler.observeMixTypeExplicitSelection((keyArray: ["ㄧㄠˋ"], value: "耀"))

    #expect(testHandler.currentLM.singleCharacterPreference(reading: "ㄧㄠ", value: "耀")?.selectionCount == 1)
    #expect(saveCount == 1)
  }

  @Test
  func test_IH527_HybridPersonalLexiconSupportsFullMixedAndInitialsPinyin() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    let oldEnglishIntent = testHandler.prefs.mixTypeEnglishIntentEnabled

    let jiuHao = LXAssembly.PersonalLexiconEntry(
      phrase: "就好",
      readings: ["ㄐㄧㄡˋ", "ㄏㄠˇ"],
      pinyinTokens: ["jiu", "hao"],
      fullPinyinKey: "jiuhao",
      initialsKey: "jh",
      source: .manual,
      pinned: true
    )
    let jiuHaoLe = LXAssembly.PersonalLexiconEntry(
      phrase: "就好了",
      readings: ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"],
      pinyinTokens: ["jiu", "hao", "le"],
      fullPinyinKey: "jiuhaole",
      initialsKey: "jhl",
      source: .manual,
      pinned: true
    )
    defer {
      testHandler.prefs.mixTypeEnglishIntentEnabled = oldEnglishIntent
      testHandler.currentLM.replacePersonalLexiconEntries([])
    }

    testHandler.currentLM.replacePersonalLexiconEntries([jiuHao, jiuHaoLe])
    testHandler.prefs.mixTypeEnglishIntentEnabled = true
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    // `jhaole` 本身符合保守英文外形 heuristic；Personal mixed-prefix 是較強的
    // 使用者來源，因此即使英文意圖開啟也不可被隱藏。
    #expect(MixTypeEnglishIntent.looksLikeEnglishWord("jhaole"))

    let full = try #require(
      testHandler.hybridCandidateOffers(for: "jiuhaole").first(where: { $0.candidate.value == "就好了" })
    )
    #expect(full.source == .personalFullPinyin)

    let mixedPhrase = try #require(
      testHandler.hybridCandidateOffers(for: "jhaole").first(where: { $0.candidate.value == "就好了" })
    )
    #expect(mixedPhrase.source == .personalMixedPinyin)

    let mixedShort = try #require(
      testHandler.hybridCandidateOffers(for: "jhao").first(where: { $0.candidate.value == "就好" })
    )
    #expect(mixedShort.source == .personalMixedPinyin)

    let initials = try #require(
      testHandler.hybridCandidateOffers(for: "jhl").first(where: { $0.candidate.value == "就好了" })
    )
    #expect(initials.source == .personalInitials)
  }

  @Test
  func test_IH528_HybridMixedFactorySelectionAutoPromotesThenInitialsWork() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldAutoPromotionEnabled = testHandler.prefs.mixTypeAutoPromotionEnabled
    let oldThreshold = testHandler.prefs.mixTypeAutoPromotionThreshold
    let oldEnglishIntent = testHandler.prefs.mixTypeEnglishIntentEnabled
    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      testHandler.prefs.mixTypeAutoPromotionEnabled = oldAutoPromotionEnabled
      testHandler.prefs.mixTypeAutoPromotionThreshold = oldThreshold
      testHandler.prefs.mixTypeEnglishIntentEnabled = oldEnglishIntent
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.currentLM.replacePersonalLexiconPromotionObservations([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    testHandler.currentLM.replacePersonalLexiconEntries([])
    testHandler.currentLM.replacePersonalLexiconPromotionObservations([])
    testHandler.prefs.mixTypeAutoPromotionEnabled = true
    testHandler.prefs.mixTypeAutoPromotionThreshold = 3
    // 這個 regression 專測 mixed-prefix learning；避免 English-intent heuristic
    // 把形似英文的測試字串在候選 UI 前先隱藏。
    testHandler.prefs.mixTypeEnglishIntentEnabled = false
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    let initialOffer = try #require(
      testHandler.hybridCandidateOffers(for: "nliu").first(where: { $0.candidate.value == "能留" })
    )
    #expect(initialOffer.source == .pinyinAbbreviation)

    for expectedCount in 1 ... 3 {
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
      typeSentence("nliu")

      let candidateIndex = try #require(
        testSession.state.candidates.firstIndex(where: { $0.value == "能留" })
      )
      testSession.candidatePairSelectionConfirmed(at: candidateIndex)

      if expectedCount < 3 {
        #expect(testHandler.currentLM.personalLexiconEntries.isEmpty)
        #expect(testHandler.currentLM.personalLexiconPromotionObservations.first?.selectionCount == expectedCount)
      }
    }

    let promoted = try #require(
      testHandler.currentLM.personalLexiconEntries.first(where: { $0.phrase == "能留" })
    )
    #expect(promoted.fullPinyinKey == "nengliu")
    #expect(promoted.initialsKey == "nl")

    let initialsOffer = try #require(
      testHandler.hybridCandidateOffers(for: "nl").first(where: { $0.candidate.value == "能留" })
    )
    #expect(initialsOffer.source == .personalInitials)
  }

  @Test
  func test_IH529_CompositionPhraseCommitLearnsAndPromotesJiuHaoLe() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldAutoPromotionEnabled = testHandler.prefs.mixTypeAutoPromotionEnabled
    let oldThreshold = testHandler.prefs.mixTypeAutoPromotionThreshold
    let oldEnglishIntent = testHandler.prefs.mixTypeEnglishIntentEnabled
    var pendingSaveCount = 0
    var personalSaveCount = 0
    SessionHost.shared.saveCompositionPhraseLearningData = { _ in pendingSaveCount += 1 }
    SessionHost.shared.savePersonalLexiconData = { _ in personalSaveCount += 1 }

    let readings = ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"]
    let targetPhrase = "就好了"
    let grams = [
      Homa.Gram(keyArray: ["ㄐㄧㄡˋ"], value: "就", score: 10),
      Homa.Gram(keyArray: ["ㄏㄠˇ"], value: "好", score: 10),
      Homa.Gram(keyArray: ["ㄌㄜ˙"], value: "了", score: 10),
      Homa.Gram(keyArray: readings, value: targetPhrase, score: 50),
    ]

    defer {
      testHandler.prefs.mixTypeAutoPromotionEnabled = oldAutoPromotionEnabled
      testHandler.prefs.mixTypeAutoPromotionThreshold = oldThreshold
      testHandler.prefs.mixTypeEnglishIntentEnabled = oldEnglishIntent
      SessionHost.shared.saveCompositionPhraseLearningData = { _ in }
      SessionHost.shared.savePersonalLexiconData = { _ in }
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testHandler.currentLM.replacePersonalLexiconEntries([])
    testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    grams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    testHandler.prefs.mixTypeAutoPromotionEnabled = true
    testHandler.prefs.mixTypeAutoPromotionThreshold = 3
    testHandler.prefs.mixTypeEnglishIntentEnabled = true
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    for expectedCount in 1 ... 3 {
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
      try testHandler.assembler.insertKeys(readings.map { Homa.PossibleKey.singleKey($0) })
      #expect(testHandler.assembler.actualKeys == readings)
      #expect(testHandler.assembler.assembledSentence.values.joined() == targetPhrase)

      testSession.switchState(.ofCommitting(textToCommit: targetPhrase))

      if expectedCount < 3 {
        #expect(testHandler.currentLM.personalLexiconEntries.isEmpty)
        #expect(
          testHandler.currentLM.compositionPhraseLearningObservations.first?.occurrenceCount == expectedCount
        )
      }
    }

    let promoted = try #require(
      testHandler.currentLM.personalLexiconEntries.first(where: { $0.phrase == targetPhrase })
    )
    #expect(promoted.fullPinyinKey == "jiuhaole")
    #expect(promoted.initialsKey == "jhl")
    #expect(promoted.selectionCount == 3)
    #expect(testHandler.currentLM.compositionPhraseLearningObservations.isEmpty)
    #expect(pendingSaveCount == 3)
    #expect(personalSaveCount == 1)

    let initialsOffer = try #require(
      testHandler.hybridCandidateOffers(for: "jhl").first(where: { $0.candidate.value == targetPhrase })
    )
    #expect(initialsOffer.source == .personalInitials)
    let mixedOffer = try #require(
      testHandler.hybridCandidateOffers(for: "jhaole").first(where: { $0.candidate.value == targetPhrase })
    )
    #expect(mixedOffer.source == .personalMixedPinyin)
  }

  @Test
  func test_IH530_CompositionPhraseLearningRejectsMixedOrNonExactCommit() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }

    let oldAutoPromotionEnabled = testHandler.prefs.mixTypeAutoPromotionEnabled
    let readings = ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"]
    let grams = [
      Homa.Gram(keyArray: ["ㄐㄧㄡˋ"], value: "就", score: 10),
      Homa.Gram(keyArray: ["ㄏㄠˇ"], value: "好", score: 10),
      Homa.Gram(keyArray: ["ㄌㄜ˙"], value: "了", score: 10),
      Homa.Gram(keyArray: readings, value: "就好了", score: 50),
    ]
    defer {
      testHandler.prefs.mixTypeAutoPromotionEnabled = oldAutoPromotionEnabled
      testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    grams.forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }
    testHandler.prefs.mixTypeAutoPromotionEnabled = true
    try testHandler.assembler.insertKeys(readings.map { Homa.PossibleKey.singleKey($0) })
    #expect(testHandler.assembler.assembledSentence.values.joined() == "就好了")

    testHandler.observeMixTypeCompositionPhraseCommit(textToCommit: "就好了!")
    #expect(testHandler.currentLM.compositionPhraseLearningObservations.isEmpty)

    testHandler.calligrapher.append("x")
    testHandler.observeMixTypeCompositionPhraseCommit(textToCommit: "就好了")
    #expect(testHandler.currentLM.compositionPhraseLearningObservations.isEmpty)
  }

  @Test
  func test_IH531_HybridFullPinyinCanComposePhraseFromExistingFactorySegments() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldEnglishIntent = testHandler.prefs.mixTypeEnglishIntentEnabled
    defer {
      testHandler.prefs.mixTypeEnglishIntentEnabled = oldEnglishIntent
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    [
      Homa.Gram(keyArray: ["ㄍㄨㄛˋ", "ㄌㄞˊ"], value: "過來", score: 20),
      Homa.Gram(keyArray: ["ㄧ", "ㄒㄧㄚˋ"], value: "一下", score: 20),
      Homa.Gram(keyArray: ["ㄧˊ", "ㄒㄧㄚˋ"], value: "一下", score: 19),
      // 刻意放一個更高分的無聲調歧義結果，確認 composed provider 不是只留 top-1。
      Homa.Gram(keyArray: ["ㄧˇ", "ㄒㄧㄚˋ"], value: "以下", score: 25),
      Homa.Gram(keyArray: ["ㄍㄨㄛˋ"], value: "過", score: 5),
      Homa.Gram(keyArray: ["ㄌㄞˊ"], value: "來", score: 5),
      Homa.Gram(keyArray: ["ㄧ"], value: "一", score: 5),
      Homa.Gram(keyArray: ["ㄒㄧㄚˋ"], value: "下", score: 5),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.mixTypeEnglishIntentEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()
    testHandler.clear()

    let topOneScratch = Homa.Assembler(
      gramQuerier: testHandler.assembler.gramQuerier,
      gramAvailabilityChecker: testHandler.assembler.gramAvailabilityChecker
    )
    func allTones(_ toneless: String) -> Homa.PossibleKey {
      .multipleKeys(Tekkon.allowedIntonations.map { tone in
        toneless + (tone == " " ? "" : String(tone))
      })
    }
    try topOneScratch.insertKeys([
      allTones("ㄍㄨㄛ"),
      allTones("ㄌㄞ"),
      allTones("ㄧ"),
      allTones("ㄒㄧㄚ"),
    ])
    #expect(topOneScratch.assembledSentence.values.joined() == "過來以下")

    let offers = testHandler.hybridCandidateOffers(for: "guolaiyixia")
    let composed = try #require(offers.first(where: { $0.candidate.value == "過來一下" }))
    #expect(composed.source == .pinyinComposed)
    #expect(composed.candidate.keyArray.count == 4)

    typeSentence("guolaiyixia")
    #expect(testHandler.calligrapher == "guolaiyixia")
    let candidateIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "過來一下" })
    )
    testSession.candidatePairSelectionConfirmed(at: candidateIndex)

    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.actualKeys == composed.candidate.keyArray)
    #expect(testHandler.assembler.assembledSentence.values.joined() == "過來一下")
  }

  @Test
  func test_IH532_SequentialSingleCharacterSelectionsLearnWeiHongPhrase() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldAutoPromotionEnabled = testHandler.prefs.mixTypeAutoPromotionEnabled
    let oldThreshold = testHandler.prefs.mixTypeAutoPromotionThreshold
    let oldEnglishIntent = testHandler.prefs.mixTypeEnglishIntentEnabled
    var compositionPendingSaveCount = 0
    var personalSaveCount = 0
    SessionHost.shared.saveCompositionPhraseLearningData = { _ in compositionPendingSaveCount += 1 }
    SessionHost.shared.savePersonalLexiconData = { _ in personalSaveCount += 1 }

    defer {
      testHandler.prefs.mixTypeAutoPromotionEnabled = oldAutoPromotionEnabled
      testHandler.prefs.mixTypeAutoPromotionThreshold = oldThreshold
      testHandler.prefs.mixTypeEnglishIntentEnabled = oldEnglishIntent
      SessionHost.shared.saveCompositionPhraseLearningData = { _ in }
      SessionHost.shared.savePersonalLexiconData = { _ in }
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
      testHandler.currentLM.replaceSingleCharacterPreferenceEntries([])
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    testHandler.currentLM.replacePersonalLexiconEntries([])
    testHandler.currentLM.replaceCompositionPhraseLearningObservations([])
    testHandler.currentLM.replaceSingleCharacterPreferenceEntries([])
    testHandler.currentLM.clearTemporaryData(isFiltering: false)
    [
      Homa.Gram(keyArray: ["ㄨㄟˊ"], value: "韋", score: 20),
      Homa.Gram(keyArray: ["ㄨㄟˊ"], value: "為", score: 10),
      Homa.Gram(keyArray: ["ㄏㄨㄥˊ"], value: "宏", score: 20),
      Homa.Gram(keyArray: ["ㄏㄨㄥˊ"], value: "紅", score: 10),
    ].forEach { testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false) }

    testHandler.prefs.mixTypeAutoPromotionEnabled = true
    testHandler.prefs.mixTypeAutoPromotionThreshold = 3
    testHandler.prefs.mixTypeEnglishIntentEnabled = true
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    for expectedCount in 1 ... 3 {
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)

      typeSentence("wei")
      let weiIndex = try #require(testSession.state.candidates.firstIndex(where: { $0.value == "韋" }))
      testSession.candidatePairSelectionConfirmed(at: weiIndex)
      #expect(testHandler.assembler.assembledSentence.values.joined() == "韋")

      typeSentence("hong")
      let hongIndex = try #require(testSession.state.candidates.firstIndex(where: { $0.value == "宏" }))
      testSession.candidatePairSelectionConfirmed(at: hongIndex)
      #expect(testHandler.assembler.assembledSentence.values.joined() == "韋宏")

      #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
      #expect(testSession.recentCommissions.last == "韋宏")

      if expectedCount < 3 {
        #expect(testHandler.currentLM.personalLexiconEntries.isEmpty)
        #expect(
          testHandler.currentLM.compositionPhraseLearningObservations.first?.occurrenceCount == expectedCount
        )
      }
    }

    let promoted = try #require(
      testHandler.currentLM.personalLexiconEntries.first(where: { $0.phrase == "韋宏" })
    )
    #expect(promoted.source == .autoPromoted)
    #expect(promoted.readings == ["ㄨㄟˊ", "ㄏㄨㄥˊ"])
    #expect(promoted.fullPinyinKey == "weihong")
    #expect(promoted.initialsKey == "wh")
    #expect(promoted.selectionCount == 3)
    #expect(testHandler.currentLM.compositionPhraseLearningObservations.isEmpty)
    #expect(compositionPendingSaveCount == 3)
    #expect(personalSaveCount == 1)

    let fullOffer = try #require(
      testHandler.hybridCandidateOffers(for: "weihong").first(where: { $0.candidate.value == "韋宏" })
    )
    #expect(fullOffer.source == .personalFullPinyin)
    let initialsOffer = try #require(
      testHandler.hybridCandidateOffers(for: "wh").first(where: { $0.candidate.value == "韋宏" })
    )
    #expect(initialsOffer.source == .personalInitials)
  }

  @Test
  func test_IH533_MixedTokenSegmentationDefaultsOnAndFlagOffKeepsV02ShiftBehavior() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    #expect(testHandler.prefs.mixTypeMixedTokenSegmentationEnabled)

    let shiftM = KBEvent.KeyEventData(
      flags: .shift, chars: "M", charsSansModifiers: "m", keyCode: 46
    ).asEvent
    #expect(testHandler.triageInput(event: shiftM))
    #expect(testSession.recentCommissions.isEmpty)
    #expect(testHandler.calligrapher == "M")

    // Bare shifted punctuation still keeps its visible ASCII semantics with V0.3 on.
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    let shift2 = KBEvent.KeyEventData(
      flags: .shift, chars: "@", charsSansModifiers: "2", keyCode: 19
    ).asEvent
    #expect(testHandler.triageInput(event: shift2))
    #expect(testSession.recentCommissions.joined() == "@")
    #expect(testHandler.calligrapher.isEmpty)

    // Explicitly disabling the feature restores the accepted V0.2 uppercase behavior.
    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = false
    #expect(testHandler.triageInput(event: shiftM))
    #expect(testSession.recentCommissions.last == "M")
    #expect(testHandler.calligrapher.isEmpty)
  }

  @Test(arguments: [
    "MacBookM6",
    "MacBookM6gai",
    "ABC123",
    "server2026",
    "SOC80%",
  ])
  func test_IH534_MixedTokenSegmentationProtectsCaseAndAlnumTokens(token: String) throws {
    try verifyProtectedMixedToken(token)
  }

  @Test(arguments: [
    "email@example.com",
    "email@example.comgai",
    "https://example.com/path?q=1",
  ])
  func test_IH535_MixedTokenSegmentationProtectsEmailAndURLTokens(token: String) throws {
    try verifyProtectedMixedToken(token)
  }

  @Test
  func test_IH536_MixedTokenSegmentationSplitsEnglishPrefixFromPinyinSuffixWithoutAutoSelecting() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄐㄧㄣ"], value: "今", score: 20),
      Homa.Gram(keyArray: ["ㄊㄧㄢ"], value: "天", score: 20),
      Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 100),
      Homa.Gram(keyArray: ["ㄍㄞˇ"], value: "改", score: 100),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("jintian")
    let todayIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "今天" })
    )
    testSession.candidatePairSelectionConfirmed(at: todayIndex)
    #expect(testHandler.assembler.assembledSentence.map { $0.value } == ["今天"])
    #expect(testSession.recentCommissions.isEmpty)

    typeSentence("meetinggai")
    #expect(testSession.recentCommissions.joined() == "今天meeting")
    #expect(testHandler.calligrapher == "gai")
    #expect(testSession.state.candidates.contains { $0.value == "改" })
    #expect(testHandler.assembler.isEmpty)

    let changeIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "改" })
    )
    testSession.candidatePairSelectionConfirmed(at: changeIndex)
    #expect(testSession.recentCommissions.joined() == "今天meeting")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map { $0.value } == ["改"])

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions.joined() == "今天meeting改")
  }

  @Test
  func test_IH537_MixedTokenSegmentationDoesNotSplitValidPinyinPrefix() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: ["ㄍㄞˇ"], value: "改", score: 100),
      isFiltering: false
    )

    typeSentence("nengliu")
    #expect(testHandler.calligrapher == "nengliu")
    #expect(testSession.recentCommissions.isEmpty)
    #expect(testSession.state.candidates.contains { $0.value == "能留" })

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    typeSentence("taidagai")
    #expect(testHandler.calligrapher == "taidagai")
    #expect(testSession.recentCommissions.isEmpty)
  }

  @Test(arguments: [
    (token: "3pm", numericPrefix: "3", suffix: "pm"),
    (token: "20kW", numericPrefix: "20", suffix: "kW"),
    (token: "300RT", numericPrefix: "300", suffix: "RT"),
  ])
  func test_IH538_MixedTokenSegmentationKeepsDigitLeadingUnitAndTimeTokensLiteral(
    scenario: (token: String, numericPrefix: String, suffix: String)
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    var clientPassthrough = ""
    for char in scenario.token {
      let text = String(char)
      let event: KBEvent
      if char.isUppercase {
        event = KBEvent.KeyEventData(
          flags: .shift,
          chars: text,
          charsSansModifiers: text.lowercased(),
          keyCode: mapKeyCodesANSIForTests[text.lowercased()] ?? 65_535
        ).asEvent
      } else {
        event = KBEvent.KeyEventData(chars: text).asEvent
      }
      if !testHandler.triageInput(event: event) {
        clientPassthrough += text
      }
    }

    #expect(clientPassthrough == scenario.numericPrefix)
    #expect(testHandler.mixTypePassthroughNumericPrefix == scenario.numericPrefix)
    #expect(testHandler.calligrapher == scenario.suffix)
    #expect(testSession.state.candidates.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ").asEvent))
    #expect(clientPassthrough + testSession.recentCommissions.joined() == scenario.token + " ")
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.mixTypePassthroughNumericPrefix.isEmpty)
  }

  @Test
  func test_IH539_MixedTokenSegmentationHandlesChineseEnglishChineseThenDigitTime() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄐㄧㄣ"], value: "今", score: 20),
      Homa.Gram(keyArray: ["ㄊㄧㄢ"], value: "天", score: 20),
      Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 100),
      Homa.Gram(keyArray: ["ㄍㄞˇ"], value: "改", score: 100),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("jintian")
    let todayIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "今天" })
    )
    testSession.candidatePairSelectionConfirmed(at: todayIndex)

    typeSentence("meetinggai")
    #expect(testSession.recentCommissions.joined() == "今天meeting")
    let changeIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "改" })
    )
    testSession.candidatePairSelectionConfirmed(at: changeIndex)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["改"])

    let digitHandled = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "3").asEvent)
    #expect(!digitHandled)
    #expect(testSession.recentCommissions == ["今天", "meeting", "改"])
    #expect(testHandler.mixTypePassthroughNumericPrefix == "3")
    #expect(testHandler.assembler.isEmpty)

    typeSentence("pm")
    #expect(testHandler.calligrapher == "pm")
    #expect(testSession.state.candidates.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect(testSession.recentCommissions == ["今天", "meeting", "改", "pm"])
    #expect(testHandler.mixTypePassthroughNumericPrefix.isEmpty)

    // The real client receives the unhandled "3" between the second and third IME commits.
    let reconstructedClientText =
      testSession.recentCommissions[0]
        + testSession.recentCommissions[1]
        + testSession.recentCommissions[2]
        + "3"
        + testSession.recentCommissions[3]
    #expect(reconstructedClientText == "今天meeting改3pm")
  }

  @Test
  func test_IH540_DigitPrefixDoesNotForceFollowingValidPinyinToASCII() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()
    [
      Homa.Gram(keyArray: ["ㄋㄧˇ"], value: "你", score: 20),
      Homa.Gram(keyArray: ["ㄏㄠˇ"], value: "好", score: 20),
      Homa.Gram(keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"], value: "你好", score: 100),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    #expect(!testHandler.triageInput(event: KBEvent.KeyEventData(chars: "3").asEvent))
    #expect(testHandler.mixTypePassthroughNumericPrefix == "3")

    typeSentence("nihao")
    #expect(testHandler.calligrapher == "nihao")
    let helloIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "你好" })
    )
    testSession.candidatePairSelectionConfirmed(at: helloIndex)

    #expect(testHandler.mixTypePassthroughNumericPrefix.isEmpty)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["你好"])
    #expect(testHandler.triageInput(event: KBEvent.KeyEventData.dataEnterReturn.asEvent))
    #expect("3" + testSession.recentCommissions.joined() == "3你好")
  }

  @Test
  func test_IH541_ContinuousPinyinEnglishPinyinOffersWholeMixedCandidateWithoutAutoCommit() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄐㄧㄣ"], value: "今", score: 20),
      Homa.Gram(keyArray: ["ㄊㄧㄢ"], value: "天", score: 20),
      Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 200),
      Homa.Gram(keyArray: ["ㄍㄞˇ"], value: "改", score: 200),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("jintianmeetinggai")

    #expect(testHandler.calligrapher == "jintianmeetinggai")
    #expect(testSession.recentCommissions.isEmpty)
    let mixedIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "今天meeting改" })
    )
    #expect(mixedIndex == 0)

    testSession.candidatePairSelectionConfirmed(at: mixedIndex)
    #expect(testSession.recentCommissions == ["今天meeting改"])
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test
  func test_IH542_ContinuousMixedSegmentationRejectsWeakEnglishMiddle() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    [
      Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 200),
      Homa.Gram(keyArray: ["ㄍㄞˇ"], value: "改", score: 200),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    let offers = testHandler.hybridCandidateOffers(for: "jintianminggai")
    #expect(!offers.contains { $0.candidate.value.contains("ming") })
  }

  @Test
  func test_IH543_ContinuousPinyinEnglishTailOffersWholeMixedCandidateFirst() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    guard let cassetteURL = cassetteURLForTests("wubi", ext: "cin") else {
      Issue.record("Unable to access wubi.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)
    [
      Homa.Gram(keyArray: ["ㄐㄧㄣ"], value: "今", score: 20),
      Homa.Gram(keyArray: ["ㄊㄧㄢ"], value: "天", score: 20),
      Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 200),
    ].forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("jintianmeeting")

    #expect(testHandler.calligrapher == "jintianmeeting")
    #expect(testSession.recentCommissions.isEmpty)
    let mixedIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "今天meeting" })
    )
    #expect(mixedIndex == 0)

    testSession.candidatePairSelectionConfirmed(at: mixedIndex)
    #expect(testSession.recentCommissions == ["今天meeting"])
    #expect(testHandler.calligrapher.isEmpty)
    #expect(testHandler.assembler.isEmpty)
  }

  @Test
  func test_IH544_ContinuousPinyinTailDoesNotMisclassifyWeakEnglishSuffix() throws {
    guard let testHandler else {
      Issue.record("Test handler is nil.")
      return
    }
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.clear()
    }

    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.insertTemporaryData(
      unigram: Homa.Gram(keyArray: ["ㄐㄧㄣ", "ㄊㄧㄢ"], value: "今天", score: 200),
      isFiltering: false
    )

    let offers = testHandler.hybridCandidateOffers(for: "jintianming")
    #expect(!offers.contains { $0.source == .mixedSegmented })
  }

  @Test
  func test_IH545_CassettePunctuationCodeBeatsMixedTokenSyntax() throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)

    guard let cassetteURL = cassetteURLForTests("mixtype_punct", ext: "cin") else {
      Issue.record("Unable to access mixtype_punct.cin test fixture.")
      return
    }
    LXAssembly.LXFacade.loadCassetteData(path: cassetteURL.path)

    testHandler.clear()
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()

    typeSentence("s.")

    #expect(testHandler.calligrapher == "s.")
    #expect(testSession.recentCommissions.isEmpty)
    let punctuationIndex = try #require(
      testSession.state.candidates.firstIndex(where: { $0.value == "？" })
    )
    #expect(punctuationIndex == 0)

    testSession.candidatePairSelectionConfirmed(at: punctuationIndex)
    #expect(testSession.recentCommissions == ["？"])
    #expect(testHandler.calligrapher.isEmpty)
  }

  private func verifyProtectedMixedToken(_ token: String) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }
    let oldFlag = testHandler.prefs.mixTypeMixedTokenSegmentationEnabled
    defer {
      testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = oldFlag
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    }

    testHandler.clear()
    testSession.resetInputHandler(forceComposerCleanup: true, commitExisting: false)
    testHandler.prefs.cassetteEnabled = true
    testHandler.prefs.hybridCassettePinyinEnabled = true
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.prefs.mixTypeMixedTokenSegmentationEnabled = true
    testHandler.ensureKeyboardParser()

    for char in token {
      let text = String(char)
      let event: KBEvent
      if char.isUppercase {
        event = KBEvent.KeyEventData(
          flags: .shift,
          chars: text,
          charsSansModifiers: text.lowercased(),
          keyCode: mapKeyCodesANSIForTests[text.lowercased()] ?? 65_535
        ).asEvent
      } else if let shiftedBase = ["@": "2", ":": ";", "%": "5", "?": "/", "&": "7", "=": "0", "#": "3", "+": "="][text] {
        event = KBEvent.KeyEventData(
          flags: .shift,
          chars: text,
          charsSansModifiers: shiftedBase,
          keyCode: mapKeyCodesANSIForTests[shiftedBase] ?? 65_535
        ).asEvent
      } else {
        event = KBEvent.KeyEventData(chars: text).asEvent
      }
      #expect(testHandler.triageInput(event: event), "Hybrid rejected protected token char \(text) in \(token)")
    }

    #expect(testHandler.calligrapher == token)
    #expect(testSession.state.candidates.isEmpty)

    #expect(testHandler.triageInput(event: KBEvent.KeyEventData(chars: " ").asEvent))
    #expect(testSession.recentCommissions.joined() == token + " ")
    #expect(testHandler.calligrapher.isEmpty)
  }

  private func verifyNativePhoneticPersonalLexicon(
    parser: KeyboardParser,
    expectedProvider: Shared.MixTypeBaseInputProvider
  ) throws {
    guard let testHandler, let testSession else {
      Issue.record("Test handler or session is nil.")
      return
    }

    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "能留",
      readings: ["ㄋㄥˊ", "ㄌㄧㄡˊ"],
      pinyinTokens: ["neng", "liu"],
      fullPinyinKey: "nengliu",
      initialsKey: "nl",
      source: .manual,
      pinned: true
    )
    defer {
      testHandler.currentLM.replacePersonalLexiconEntries([])
      testHandler.clear()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }

    testHandler.currentLM.replacePersonalLexiconEntries([entry])
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.furiousTypingEnabled = false
    testHandler.prefs.keyboardParser = parser.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.currentLM.syncPrefs()
    testHandler.clear()

    #expect(testHandler.mixTypeBaseInputProvider == expectedProvider)
    try testHandler.assembler.insertKeys(entry.readings.map { Homa.PossibleKey.singleKey($0) })
    let overrideSucceeded = testHandler.assembler.overrideCandidate(
      Homa.CandidatePair(keyArray: entry.readings, value: entry.phrase),
      at: 0,
      overrideType: .withSpecified,
      isExplicitlyOverridden: true
    )
    #expect(overrideSucceeded)
    #expect(testHandler.assembler.assembledSentence.map(\.value) == ["能留"])
  }
}
