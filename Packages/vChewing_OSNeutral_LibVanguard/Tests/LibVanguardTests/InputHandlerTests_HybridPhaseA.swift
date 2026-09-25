// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
}
