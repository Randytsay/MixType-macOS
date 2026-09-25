// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa

extension LXAssembly {
  public struct PersonalLexiconEntry: Codable, Hashable, Sendable, Identifiable {
    public enum Source: String, Codable, Sendable {
      case manual
      case autoPromoted
    }

    public init(
      id: UUID = UUID(),
      phrase: String,
      readings: [String],
      pinyinTokens: [String],
      fullPinyinKey: String,
      initialsKey: String,
      source: Source = .manual,
      selectionCount: Int = 0,
      createdAt: Date = Date(),
      updatedAt: Date = Date(),
      lastUsedAt: Date? = nil,
      pinned: Bool = false,
      disabled: Bool = false,
      schemaVersion: Int = PersonalLexiconStore.schemaVersion
    ) {
      self.id = id
      self.phrase = phrase
      self.readings = readings
      self.pinyinTokens = pinyinTokens
      self.fullPinyinKey = fullPinyinKey
      self.initialsKey = initialsKey
      self.source = source
      self.selectionCount = selectionCount
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.lastUsedAt = lastUsedAt
      self.pinned = pinned
      self.disabled = disabled
      self.schemaVersion = schemaVersion
    }

    public var id: UUID
    public var phrase: String
    public var readings: [String]
    public var pinyinTokens: [String]
    public var fullPinyinKey: String
    public var initialsKey: String
    public var source: Source
    public var selectionCount: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var pinned: Bool
    public var disabled: Bool
    public var schemaVersion: Int
  }

  public struct PersonalLexiconDocument: Codable, Sendable, Equatable {
    public init(schemaVersion: Int = PersonalLexiconStore.schemaVersion, entries: [PersonalLexiconEntry]) {
      self.schemaVersion = schemaVersion
      self.entries = entries
    }

    public var schemaVersion: Int
    public var entries: [PersonalLexiconEntry]
  }

  public enum PersonalLexiconMatchKind: String, Sendable {
    case fullPinyin
    case initials
  }

  public struct PersonalLexiconMatch: Sendable {
    public let entry: PersonalLexiconEntry
    public let kind: PersonalLexiconMatchKind
    public let score: Double
  }

  public enum PersonalLexiconError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidEntry(UUID)
  }

  public final class PersonalLexiconStore {
    public static let schemaVersion = 1

    public init(entries: [PersonalLexiconEntry] = []) {
      replaceEntries(entries)
    }

    public private(set) var entries: [PersonalLexiconEntry] = []

    public func replaceEntries(_ newEntries: [PersonalLexiconEntry]) {
      entries = newEntries.filter(Self.isValid)
      rebuildIndexes()
    }

    @discardableResult
    public func upsert(_ entry: PersonalLexiconEntry) -> Bool {
      guard Self.isValid(entry) else { return false }
      if let index = entries.firstIndex(where: {
        $0.id == entry.id || ($0.phrase == entry.phrase && $0.readings == entry.readings)
      }) {
        entries[index] = entry
      } else {
        entries.append(entry)
      }
      rebuildIndexes()
      return true
    }

    @discardableResult
    public func remove(id: UUID) -> Bool {
      let oldCount = entries.count
      entries.removeAll { $0.id == id }
      guard entries.count != oldCount else { return false }
      rebuildIndexes()
      return true
    }

    @discardableResult
    public func recordSelection(id: UUID, now: Date = Date()) -> Bool {
      guard let index = entries.firstIndex(where: { $0.id == id && !$0.disabled }) else {
        return false
      }
      entries[index].selectionCount += 1
      entries[index].lastUsedAt = now
      rebuildIndexes()
      return true
    }

    public func matches(for rawKey: String) -> [PersonalLexiconMatch] {
      let key = Self.normalizeLookupKey(rawKey)
      guard !key.isEmpty else { return [] }

      var result: [PersonalLexiconMatch] = []
      var seen = Set<UUID>()
      for entry in fullIndex[key] ?? [] where !entry.disabled {
        guard seen.insert(entry.id).inserted else { continue }
        result.append(.init(entry: entry, kind: .fullPinyin, score: Self.score(entry, full: true)))
      }
      for entry in initialsIndex[key] ?? [] where !entry.disabled {
        guard seen.insert(entry.id).inserted else { continue }
        result.append(.init(entry: entry, kind: .initials, score: Self.score(entry, full: false)))
      }
      return result.sorted {
        if $0.score != $1.score { return $0.score > $1.score }
        let lhsLastUsed = $0.entry.lastUsedAt ?? .distantPast
        let rhsLastUsed = $1.entry.lastUsedAt ?? .distantPast
        if lhsLastUsed != rhsLastUsed { return lhsLastUsed > rhsLastUsed }
        if $0.entry.updatedAt != $1.entry.updatedAt { return $0.entry.updatedAt > $1.entry.updatedAt }
        return $0.entry.phrase < $1.entry.phrase
      }
    }

    public func grams(for keyArray: [Homa.PossibleKey]) -> [Homa.Gram] {
      guard !keyArray.isEmpty else { return [] }
      return entries.compactMap { entry in
        guard !entry.disabled, entry.readings.count == keyArray.count else { return nil }
        let matches = zip(entry.readings, keyArray).allSatisfy { reading, possibleKey in
          possibleKey.allValues.contains(reading)
        }
        guard matches else { return nil }
        return Homa.Gram(
          keyArray: entry.readings,
          value: entry.phrase,
          score: Self.score(entry, full: true)
        )
      }.sorted { lhs, rhs in
        if lhs.probability != rhs.probability { return lhs.probability > rhs.probability }
        return lhs.current < rhs.current
      }
    }

    public func hasGrams(for keyArray: [String]) -> Bool {
      guard !keyArray.isEmpty else { return false }
      if keyArray.count == 1, let reading = keyArray.first {
        return entries.contains { entry in
          !entry.disabled && entry.readings.contains(reading)
        }
      }
      return entries.contains { entry in
        !entry.disabled && entry.readings == keyArray
      }
    }

    public func encode() throws -> Data {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return try encoder.encode(PersonalLexiconDocument(entries: entries))
    }

    public func load(data: Data) throws {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let document = try decoder.decode(PersonalLexiconDocument.self, from: data)
      guard document.schemaVersion == Self.schemaVersion else {
        throw PersonalLexiconError.unsupportedSchema(document.schemaVersion)
      }
      guard document.entries.allSatisfy(Self.isValid) else {
        let badID = document.entries.first(where: { !Self.isValid($0) })?.id ?? UUID()
        throw PersonalLexiconError.invalidEntry(badID)
      }
      replaceEntries(document.entries)
    }

    public static func normalizeLookupKey(_ raw: String) -> String {
      raw.lowercased().filter { $0.isASCII && $0.isLetter }
    }

    // MARK: Private

    private var fullIndex: [String: [PersonalLexiconEntry]] = [:]
    private var initialsIndex: [String: [PersonalLexiconEntry]] = [:]

    private func rebuildIndexes() {
      fullIndex.removeAll(keepingCapacity: true)
      initialsIndex.removeAll(keepingCapacity: true)
      for entry in entries where !entry.disabled {
        fullIndex[Self.normalizeLookupKey(entry.fullPinyinKey), default: []].append(entry)
        initialsIndex[Self.normalizeLookupKey(entry.initialsKey), default: []].append(entry)
      }
    }

    private static func isValid(_ entry: PersonalLexiconEntry) -> Bool {
      guard entry.schemaVersion == schemaVersion else { return false }
      guard !entry.phrase.isEmpty, entry.phrase.count <= 128 else { return false }
      guard !entry.readings.isEmpty, entry.readings.count == entry.pinyinTokens.count else { return false }
      guard entry.readings.count <= 32 else { return false }
      guard entry.selectionCount >= 0 else { return false }
      let full = normalizeLookupKey(entry.fullPinyinKey)
      let initials = normalizeLookupKey(entry.initialsKey)
      guard !full.isEmpty, !initials.isEmpty else { return false }
      guard full == entry.fullPinyinKey.lowercased(), initials == entry.initialsKey.lowercased() else {
        return false
      }
      return true
    }

    private static func score(_ entry: PersonalLexiconEntry, full: Bool) -> Double {
      var score = full ? 50.0 : 40.0
      if entry.source == .manual { score += 5 }
      if entry.pinned { score += 10 }
      score += min(Double(entry.selectionCount), 20) * 0.1
      return score
    }
  }
}
