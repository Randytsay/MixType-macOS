// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Tekkon

extension LXAssembly {
  public struct SingleCharacterPreferenceEntry: Codable, Hashable, Sendable, Identifiable {
    public init(
      id: UUID = UUID(),
      readingBase: String,
      value: String,
      selectionCount: Int = 1,
      firstSelectedAt: Date = Date(),
      lastSelectedAt: Date = Date(),
      schemaVersion: Int = SingleCharacterPreferenceStore.schemaVersion
    ) {
      self.id = id
      self.readingBase = readingBase
      self.value = value
      self.selectionCount = selectionCount
      self.firstSelectedAt = firstSelectedAt
      self.lastSelectedAt = lastSelectedAt
      self.schemaVersion = schemaVersion
    }

    public var id: UUID
    public var readingBase: String
    public var value: String
    public var selectionCount: Int
    public var firstSelectedAt: Date
    public var lastSelectedAt: Date
    public var schemaVersion: Int
  }

  public struct SingleCharacterPreferenceDocument: Codable, Sendable, Equatable {
    public init(
      schemaVersion: Int = SingleCharacterPreferenceStore.schemaVersion,
      entries: [SingleCharacterPreferenceEntry]
    ) {
      self.schemaVersion = schemaVersion
      self.entries = entries
    }

    public var schemaVersion: Int
    public var entries: [SingleCharacterPreferenceEntry]
  }

  public enum SingleCharacterPreferenceError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidEntry(UUID)
  }

  /// MixType 的「無聲調拼音單字偏好」資料層。
  ///
  /// key 使用去聲調注音（例如 `ㄧㄠ`），因此 `yao` 這種無聲調拼音可讓
  /// `要 / 藥 / 耀 / 曜 ...` 共用同一個 preference bucket；value 則保留使用者
  /// 真正選中的單一漢字。這層與 Personal Lexicon 分離，避免大量單字污染詞庫。
  public final class SingleCharacterPreferenceStore {
    public static let schemaVersion = 1

    public init(entries: [SingleCharacterPreferenceEntry] = []) {
      replaceEntries(entries)
    }

    public private(set) var entries: [SingleCharacterPreferenceEntry] = []

    public static func normalizeReadingBase(_ reading: String) -> String {
      let toneScalars = Set(Tekkon.allowedIntonations)
      return String(reading.unicodeScalars.filter { !toneScalars.contains($0) })
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func replaceEntries(_ newEntries: [SingleCharacterPreferenceEntry]) {
      entries = newEntries.filter(Self.isValid)
    }

    @discardableResult
    public func recordSelection(
      reading: String,
      value: String,
      now: Date = Date()
    ) -> SingleCharacterPreferenceEntry? {
      let base = Self.normalizeReadingBase(reading)
      guard Self.isValidReadingValue(readingBase: base, value: value) else { return nil }

      if let index = entries.firstIndex(where: { $0.readingBase == base && $0.value == value }) {
        entries[index].selectionCount += 1
        entries[index].lastSelectedAt = now
        return entries[index]
      }

      let entry = SingleCharacterPreferenceEntry(
        readingBase: base,
        value: value,
        selectionCount: 1,
        firstSelectedAt: now,
        lastSelectedAt: now
      )
      entries.append(entry)
      return entry
    }

    public func preference(
      reading: String,
      value: String
    ) -> SingleCharacterPreferenceEntry? {
      let base = Self.normalizeReadingBase(reading)
      guard !base.isEmpty else { return nil }
      return entries.first { $0.readingBase == base && $0.value == value }
    }

    public func encode() throws -> Data {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return try encoder.encode(SingleCharacterPreferenceDocument(entries: entries))
    }

    public func load(data: Data) throws {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let document = try decoder.decode(SingleCharacterPreferenceDocument.self, from: data)
      guard document.schemaVersion == Self.schemaVersion else {
        throw SingleCharacterPreferenceError.unsupportedSchema(document.schemaVersion)
      }
      guard document.entries.allSatisfy(Self.isValid) else {
        let badID = document.entries.first(where: { !Self.isValid($0) })?.id ?? UUID()
        throw SingleCharacterPreferenceError.invalidEntry(badID)
      }
      replaceEntries(document.entries)
    }

    private static func isValid(_ entry: SingleCharacterPreferenceEntry) -> Bool {
      entry.schemaVersion == schemaVersion
        && entry.selectionCount >= 1
        && isValidReadingValue(readingBase: entry.readingBase, value: entry.value)
    }

    private static func isValidReadingValue(readingBase: String, value: String) -> Bool {
      guard !readingBase.isEmpty, value.count == 1 else { return false }
      guard value.unicodeScalars.contains(where: { !$0.isASCII }) else { return false }
      return true
    }
  }
}
