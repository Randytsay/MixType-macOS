// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

@Suite(.serialized)
struct PersonalLexiconTests {
  private func makeEntry(disabled: Bool = false) -> LXAssembly.PersonalLexiconEntry {
    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    return .init(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      createdAt: fixedDate,
      updatedAt: fixedDate,
      pinned: true,
      disabled: disabled
    )
  }

  @Test
  func testPersonalLexiconIndexesFullPinyinAndInitials() {
    let store = LXAssembly.PersonalLexiconStore(entries: [makeEntry()])

    let full = store.matches(for: "TAI-DA NENG YUAN")
    #expect(full.count == 1)
    #expect(full.first?.entry.phrase == "台達能源")
    #expect(full.first?.kind == .fullPinyin)

    let initials = store.matches(for: "TDNY")
    #expect(initials.count == 1)
    #expect(initials.first?.entry.phrase == "台達能源")
    #expect(initials.first?.kind == .initials)
  }

  @Test
  func testPersonalLexiconMatchesMixedPinyinPrefixesWithoutAliasExpansion() throws {
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "就好了",
      readings: ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"],
      pinyinTokens: ["jiu", "hao", "le"],
      fullPinyinKey: "jiuhaole",
      initialsKey: "jhl",
      source: .manual,
      pinned: true
    )
    let store = LXAssembly.PersonalLexiconStore(entries: [entry])

    for prefixes in [["j", "hao", "le"], ["jiu", "h", "le"], ["j", "h", "l"]] {
      let match = try #require(store.matches(pinyinPrefixes: prefixes).first)
      #expect(match.entry.phrase == "就好了")
      #expect(match.kind == .mixedPinyinPrefix)
    }

    #expect(store.matches(pinyinPrefixes: ["j", "hao"]).isEmpty)
    #expect(store.matches(pinyinPrefixes: ["x", "hao", "le"]).isEmpty)
  }

  @Test
  func testPersonalLexiconDisabledEntryIsNotIndexed() {
    let store = LXAssembly.PersonalLexiconStore(entries: [makeEntry(disabled: true)])
    #expect(store.matches(for: "taidanengyuan").isEmpty)
    #expect(store.matches(for: "tdny").isEmpty)
  }

  @Test
  func testPersonalLexiconJSONRoundTrip() throws {
    let original = LXAssembly.PersonalLexiconStore(entries: [makeEntry()])
    let data = try original.encode()
    let restored = LXAssembly.PersonalLexiconStore()
    try restored.load(data: data)

    #expect(restored.entries == original.entries)
    #expect(restored.matches(for: "tdny").first?.entry.phrase == "台達能源")
  }

  @Test
  func testPersonalLexiconRejectsFutureSchemaWithoutDestroyingCurrentData() throws {
    let store = LXAssembly.PersonalLexiconStore(entries: [makeEntry()])
    let future = LXAssembly.PersonalLexiconDocument(schemaVersion: 999, entries: [])
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(future)

    #expect(throws: LXAssembly.PersonalLexiconError.unsupportedSchema(999)) {
      try store.load(data: data)
    }
    #expect(store.entries.count == 1)
    #expect(store.entries.first?.phrase == "台達能源")
  }

  @Test
  func testPersonalLexiconKeyGeneration() throws {
    let delta = try #require(LXAssembly.PersonalLexiconKeyGenerator.generate(readings: [
      "ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ",
    ]))
    #expect(delta.pinyinTokens == ["tai", "da", "neng", "yuan"])
    #expect(delta.fullPinyinKey == "taidanengyuan")
    #expect(delta.initialsKey == "tdny")

    let name = try #require(LXAssembly.PersonalLexiconKeyGenerator.generate(readings: [
      "ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ",
    ]))
    #expect(name.fullPinyinKey == "caiyaowen")
    #expect(name.initialsKey == "cyw")
  }

  @Test
  func testPersonalLexiconReadingParserAcceptsZhuyinAndTonedPinyin() throws {
    let zhuyin = try #require(
      LXAssembly.PersonalLexiconReadingParser.parse("ㄏㄨㄟˋ ㄌㄧㄥˊ")
    )
    let numbered = try #require(
      LXAssembly.PersonalLexiconReadingParser.parse("hui4 ling2")
    )
    let marked = try #require(
      LXAssembly.PersonalLexiconReadingParser.parse("huì líng")
    )

    #expect(zhuyin == ["ㄏㄨㄟˋ", "ㄌㄧㄥˊ"])
    #expect(numbered == zhuyin)
    #expect(marked == zhuyin)

    let keys = try #require(LXAssembly.PersonalLexiconKeyGenerator.generate(readings: marked))
    #expect(keys.pinyinTokens == ["hui", "ling"])
    #expect(keys.fullPinyinKey == "huiling")
    #expect(keys.initialsKey == "hl")

    #expect(LXAssembly.PersonalLexiconReadingParser.parse("hui ling") == nil)
  }

  @Test
  func testPersonalLexiconReadingResolverUsesLongestFactorySegments() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let fixture = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1.1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t4
    KEY_COUNT\t4
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    台達\t-1\t5
    能源\t-1\t5
    台\t-1\t5
    達\t-1\t5
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄊㄞˊ-ㄉㄚˊ\t0\t1
    ㄋㄥˊ-ㄩㄢˊ\t1\t1
    ㄊㄞˊ\t2\t1
    ㄉㄚˊ\t3\t1
    """
    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: fixture))

    let readings = try #require(
      LXAssembly.PersonalLexiconReadingResolver.resolveFactoryReadings(for: "台達能源")
    )
    #expect(readings == ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"])

    let entry = try #require(
      LXAssembly.PersonalLexiconReadingResolver.makeManualEntry(phrase: "台達能源")
    )
    #expect(entry.fullPinyinKey == "taidanengyuan")
    #expect(entry.initialsKey == "tdny")
    #expect(entry.pinned)
  }

  @Test
  func testFactoryExactReadingCacheInvalidatesWhenFactoryReloads() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let fixtureA = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1.1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    測試\t-1\t5
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄘㄜˋ-ㄕˋ\t0\t1
    """
    let fixtureB = """
    #PRAGMA:VANGUARD_HOMA_LEXICON_HEADER
    VERSION\t1.1
    TYPE\tTYPING
    READING_SEPARATOR\t-
    ENTRY_COUNT\t1
    KEY_COUNT\t1
    #PRAGMA:VANGUARD_HOMA_LEXICON_VALUES
    測試\t-1\t5
    #PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP
    ㄘㄜˋ-ㄕˊ\t0\t1
    """

    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: fixtureA))
    #expect(
      LXAssembly.LXFacade.factoryExactReadingStatus(
        phrase: "測試", readings: ["ㄘㄜˋ", "ㄕˋ"]
      ) == .supported
    )

    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: fixtureB))
    #expect(
      LXAssembly.LXFacade.factoryExactReadingStatus(
        phrase: "測試", readings: ["ㄘㄜˋ", "ㄕˋ"]
      ) == .unsupported
    )
    #expect(
      LXAssembly.LXFacade.factoryExactReadingStatus(
        phrase: "測試", readings: ["ㄘㄜˋ", "ㄕˊ"]
      ) == .supported
    )
  }

  @Test
  func testPersonalLexiconSelectionLearningReordersSameInitials() throws {
    let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
    let newerDate = Date(timeIntervalSince1970: 1_700_100_000)
    let learnedDate = Date(timeIntervalSince1970: 1_700_200_000)

    let target = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      selectionCount: 0,
      createdAt: oldDate,
      updatedAt: oldDate,
      pinned: true
    )
    let peer = LXAssembly.PersonalLexiconEntry(
      phrase: "替代能源",
      readings: ["ㄊㄧˋ", "ㄉㄞˋ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["ti", "dai", "neng", "yuan"],
      fullPinyinKey: "tidainengyuan",
      initialsKey: "tdny",
      source: .manual,
      selectionCount: 0,
      createdAt: newerDate,
      updatedAt: newerDate,
      pinned: true
    )
    let store = LXAssembly.PersonalLexiconStore(entries: [target, peer])

    #expect(store.matches(for: "tdny").first?.entry.phrase == "替代能源")
    #expect(store.recordSelection(id: target.id, now: learnedDate))

    let reordered = store.matches(for: "tdny")
    #expect(reordered.map(\.entry.phrase) == ["台達能源", "替代能源"])
    #expect(reordered.first?.entry.selectionCount == 1)
    #expect(reordered.first?.entry.lastUsedAt == learnedDate)
  }

  @Test
  func testPersonalLexiconPromotionStoreCountsOnlyToThreshold() throws {
    let store = LXAssembly.PersonalLexiconPromotionStore()
    let readings = ["ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ"]
    let t1 = Date(timeIntervalSince1970: 1_700_000_000)
    let t2 = Date(timeIntervalSince1970: 1_700_000_100)
    let t3 = Date(timeIntervalSince1970: 1_700_000_200)

    #expect(store.observe(phrase: "蔡耀文", readings: readings, threshold: 3, now: t1) == .pending(count: 1))
    #expect(store.observe(phrase: "蔡耀文", readings: readings, threshold: 3, now: t2) == .pending(count: 2))
    let third = store.observe(phrase: "蔡耀文", readings: readings, threshold: 3, now: t3)
    guard case let .thresholdReached(observation) = third else {
      Issue.record("Third explicit selection must reach promotion threshold.")
      return
    }
    #expect(observation.selectionCount == 3)
    #expect(observation.firstSelectedAt == t1)
    #expect(observation.lastSelectedAt == t3)
  }

  @Test
  func testPersonalLexiconPromotionJSONRoundTrip() throws {
    let store = LXAssembly.PersonalLexiconPromotionStore()
    _ = store.observe(
      phrase: "蔡耀文",
      readings: ["ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ"],
      threshold: 3,
      now: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let restored = LXAssembly.PersonalLexiconPromotionStore()
    try restored.load(data: store.encode())
    #expect(restored.observations == store.observations)
  }

  @Test
  func testCompositionPhraseLearningStorePromotesOnlyExactShortChinesePhrase() throws {
    let store = LXAssembly.CompositionPhraseLearningStore()
    let readings = ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"]
    let t1 = Date(timeIntervalSince1970: 1_700_000_000)
    let t2 = Date(timeIntervalSince1970: 1_700_000_100)
    let t3 = Date(timeIntervalSince1970: 1_700_000_200)

    #expect(store.observe(phrase: "就好了", readings: readings, threshold: 3, now: t1) == .pending(count: 1))
    #expect(store.observe(phrase: "就好了", readings: readings, threshold: 3, now: t2) == .pending(count: 2))
    let third = store.observe(phrase: "就好了", readings: readings, threshold: 3, now: t3)
    guard case let .thresholdReached(observation) = third else {
      Issue.record("Third committed occurrence must reach composition-learning threshold.")
      return
    }
    #expect(observation.occurrenceCount == 3)
    #expect(observation.firstSeenAt == t1)
    #expect(observation.lastSeenAt == t3)

    #expect(store.observe(phrase: "就", readings: ["ㄐㄧㄡˋ"], threshold: 3) == .ignored)
    #expect(store.observe(phrase: "就好了！", readings: readings, threshold: 3) == .ignored)
    #expect(store.observe(phrase: "我今天下午去公司", readings: Array(repeating: "ㄨㄛˇ", count: 7), threshold: 3) == .ignored)
  }

  @Test
  func testCompositionPhraseLearningJSONRoundTripAndFacadePromotion() throws {
    let store = LXAssembly.CompositionPhraseLearningStore()
    let readings = ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"]
    _ = store.observe(phrase: "就好了", readings: readings, threshold: 3)
    let data = try store.encode()
    let restored = LXAssembly.CompositionPhraseLearningStore()
    try restored.load(data: data)
    #expect(restored.observation(phrase: "就好了", readings: readings)?.occurrenceCount == 1)

    let facade = LXAssembly.LXFacade(isCHS: false)
    facade.replacePersonalLexiconEntries([])
    facade.replaceCompositionPhraseLearningObservations([])
    #expect(facade.observeCompositionPhrasePromotion(phrase: "就好了", readings: readings, threshold: 3) == .pending(count: 1))
    #expect(facade.observeCompositionPhrasePromotion(phrase: "就好了", readings: readings, threshold: 3) == .pending(count: 2))
    let outcome = facade.observeCompositionPhrasePromotion(phrase: "就好了", readings: readings, threshold: 3)
    guard case let .promoted(entry) = outcome else {
      Issue.record("Third composition occurrence must promote into Personal Lexicon.")
      return
    }
    #expect(entry.phrase == "就好了")
    #expect(entry.fullPinyinKey == "jiuhaole")
    #expect(entry.initialsKey == "jhl")
    #expect(entry.selectionCount == 3)
    #expect(facade.compositionPhraseLearningObservations.isEmpty)
  }

  @Test
  func testPersonalLexiconFacadePromotesExactlyOnceUsingActualReadings() throws {
    let facade = LXAssembly.LXFacade()
    let readings = ["ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ"]
    let base = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(
      facade.observePersonalLexiconPromotion(
        phrase: "蔡耀文", readings: readings, threshold: 3, now: base
      ) == .pending(count: 1)
    )
    #expect(
      facade.observePersonalLexiconPromotion(
        phrase: "蔡耀文", readings: readings, threshold: 3, now: base.addingTimeInterval(10)
      ) == .pending(count: 2)
    )
    let third = facade.observePersonalLexiconPromotion(
      phrase: "蔡耀文", readings: readings, threshold: 3, now: base.addingTimeInterval(20)
    )
    guard case let .promoted(entry) = third else {
      Issue.record("Third explicit selection must auto-promote.")
      return
    }
    #expect(entry.source == .autoPromoted)
    #expect(entry.fullPinyinKey == "caiyaowen")
    #expect(entry.initialsKey == "cyw")
    #expect(entry.selectionCount == 3)
    #expect(facade.personalLexiconPromotionObservations.isEmpty)
    #expect(facade.personalLexiconEntries.count == 1)

    #expect(
      facade.observePersonalLexiconPromotion(
        phrase: "蔡耀文", readings: readings, threshold: 3, now: base.addingTimeInterval(30)
      ) == .alreadyPersonal
    )
    #expect(facade.personalLexiconEntries.count == 1)
  }
}
