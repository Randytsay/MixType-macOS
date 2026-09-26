// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

extension LXAssembly {
  public struct PersonalLexiconPromotionObservation: Codable, Hashable, Sendable, Identifiable {
    public init(
      id: UUID = UUID(),
      phrase: String,
      readings: [String],
      selectionCount: Int = 1,
      firstSelectedAt: Date = Date(),
      lastSelectedAt: Date = Date(),
      schemaVersion: Int = PersonalLexiconPromotionStore.schemaVersion
    ) {
      self.id = id
      self.phrase = phrase
      self.readings = readings
      self.selectionCount = selectionCount
      self.firstSelectedAt = firstSelectedAt
      self.lastSelectedAt = lastSelectedAt
      self.schemaVersion = schemaVersion
    }

    public var id: UUID
    public var phrase: String
    public var readings: [String]
    public var selectionCount: Int
    public var firstSelectedAt: Date
    public var lastSelectedAt: Date
    public var schemaVersion: Int
  }

  public struct PersonalLexiconPromotionDocument: Codable, Sendable, Equatable {
    public init(
      schemaVersion: Int = PersonalLexiconPromotionStore.schemaVersion,
      observations: [PersonalLexiconPromotionObservation]
    ) {
      self.schemaVersion = schemaVersion
      self.observations = observations
    }

    public var schemaVersion: Int
    public var observations: [PersonalLexiconPromotionObservation]
  }

  public enum PersonalLexiconPromotionError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidObservation(UUID)
  }

  public enum PersonalLexiconPromotionResult: Sendable, Equatable {
    case ignored
    case pending(count: Int)
    case thresholdReached(observation: PersonalLexiconPromotionObservation)
  }

  public enum PersonalLexiconAutoPromotionOutcome: Sendable, Equatable {
    case ignored
    case alreadyPersonal
    case pending(count: Int)
    case rejectedUnsupportedFactoryReading
    case promoted(PersonalLexiconEntry)
  }

  /// Pending explicit-selection observations live separately from the long-term Personal Lexicon.
  /// This keeps Personal Lexicon schema migration independent from the promotion policy/lifecycle.
  public final class PersonalLexiconPromotionStore {
    public static let schemaVersion = 1

    public init(observations: [PersonalLexiconPromotionObservation] = []) {
      replaceObservations(observations)
    }

    public private(set) var observations: [PersonalLexiconPromotionObservation] = []

    public func replaceObservations(_ newObservations: [PersonalLexiconPromotionObservation]) {
      observations = newObservations.filter(Self.isValid)
    }

    public func observation(phrase: String, readings: [String]) -> PersonalLexiconPromotionObservation? {
      observations.first { $0.phrase == phrase && $0.readings == readings }
    }

    @discardableResult
    public func observe(
      phrase: String,
      readings: [String],
      threshold: Int,
      now: Date = Date()
    ) -> PersonalLexiconPromotionResult {
      let normalizedThreshold = max(2, min(20, threshold))
      guard Self.isValidPhraseAndReadings(phrase: phrase, readings: readings) else { return .ignored }

      if let index = observations.firstIndex(where: { $0.phrase == phrase && $0.readings == readings }) {
        observations[index].selectionCount += 1
        observations[index].lastSelectedAt = now
        let updated = observations[index]
        if updated.selectionCount >= normalizedThreshold {
          return .thresholdReached(observation: updated)
        }
        return .pending(count: updated.selectionCount)
      }

      let observation = PersonalLexiconPromotionObservation(
        phrase: phrase,
        readings: readings,
        selectionCount: 1,
        firstSelectedAt: now,
        lastSelectedAt: now
      )
      observations.append(observation)
      if normalizedThreshold <= 1 {
        return .thresholdReached(observation: observation)
      }
      return .pending(count: 1)
    }

    @discardableResult
    public func remove(phrase: String, readings: [String]) -> Bool {
      let oldCount = observations.count
      observations.removeAll { $0.phrase == phrase && $0.readings == readings }
      return observations.count != oldCount
    }

    public func encode() throws -> Data {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return try encoder.encode(PersonalLexiconPromotionDocument(observations: observations))
    }

    public func load(data: Data) throws {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let document = try decoder.decode(PersonalLexiconPromotionDocument.self, from: data)
      guard document.schemaVersion == Self.schemaVersion else {
        throw PersonalLexiconPromotionError.unsupportedSchema(document.schemaVersion)
      }
      guard document.observations.allSatisfy(Self.isValid) else {
        let badID = document.observations.first(where: { !Self.isValid($0) })?.id ?? UUID()
        throw PersonalLexiconPromotionError.invalidObservation(badID)
      }
      replaceObservations(document.observations)
    }

    private static func isValid(_ observation: PersonalLexiconPromotionObservation) -> Bool {
      observation.schemaVersion == schemaVersion
        && observation.selectionCount >= 1
        && isValidPhraseAndReadings(phrase: observation.phrase, readings: observation.readings)
    }

    private static func isValidPhraseAndReadings(phrase: String, readings: [String]) -> Bool {
      guard phrase.count >= 2, phrase.count <= 128 else { return false }
      guard !readings.isEmpty, readings.count <= 32 else { return false }
      guard readings.allSatisfy({ !$0.isEmpty }) else { return false }
      // Promotion targets actual Chinese phrases/words, not raw ASCII tokens or punctuation-only candidates.
      return phrase.unicodeScalars.contains { !$0.isASCII }
    }
  }
}
