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
}
