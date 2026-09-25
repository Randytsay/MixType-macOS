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
}
