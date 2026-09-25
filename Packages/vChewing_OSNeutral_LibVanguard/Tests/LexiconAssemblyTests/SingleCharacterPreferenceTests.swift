// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import LexiconAssembly

@Suite(.serialized)
struct SingleCharacterPreferenceTests {
  @Test
  func testTonelessReadingBucketAndSelectionCount() throws {
    let store = LXAssembly.SingleCharacterPreferenceStore()
    let t1 = Date(timeIntervalSince1970: 1_700_000_000)
    let t2 = Date(timeIntervalSince1970: 1_700_000_100)

    let first = try #require(store.recordSelection(reading: "ㄧㄠˋ", value: "耀", now: t1))
    #expect(first.readingBase == "ㄧㄠ")
    #expect(first.selectionCount == 1)

    let second = try #require(store.recordSelection(reading: "ㄧㄠ", value: "耀", now: t2))
    #expect(second.id == first.id)
    #expect(second.selectionCount == 2)
    #expect(second.lastSelectedAt == t2)
    #expect(store.preference(reading: "ㄧㄠˊ", value: "耀")?.selectionCount == 2)
  }

  @Test
  func testJSONRoundTrip() throws {
    let store = LXAssembly.SingleCharacterPreferenceStore()
    #expect(store.recordSelection(reading: "ㄧㄠˋ", value: "耀") != nil)
    #expect(store.recordSelection(reading: "ㄧㄠˋ", value: "耀") != nil)

    let data = try store.encode()
    let restored = LXAssembly.SingleCharacterPreferenceStore()
    try restored.load(data: data)

    #expect(restored.preference(reading: "ㄧㄠ", value: "耀")?.selectionCount == 2)
  }
}
