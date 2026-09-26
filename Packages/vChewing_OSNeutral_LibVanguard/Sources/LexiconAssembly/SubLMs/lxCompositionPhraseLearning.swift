// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

extension LXAssembly {
  public struct CompositionPhraseObservation: Codable, Hashable, Sendable, Identifiable {
    public init(
      id: UUID = UUID(),
      phrase: String,
      readings: [String],
      occurrenceCount: Int = 1,
      firstSeenAt: Date = Date(),
      lastSeenAt: Date = Date(),
      schemaVersion: Int = CompositionPhraseLearningStore.schemaVersion
    ) {
      self.id = id
      self.phrase = phrase
      self.readings = readings
      self.occurrenceCount = occurrenceCount
      self.firstSeenAt = firstSeenAt
      self.lastSeenAt = lastSeenAt
      self.schemaVersion = schemaVersion
    }

    public var id: UUID
    public var phrase: String
    public var readings: [String]
    public var occurrenceCount: Int
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var schemaVersion: Int
  }

  public struct CompositionPhraseLearningDocument: Codable, Sendable, Equatable {
    public init(
      schemaVersion: Int = CompositionPhraseLearningStore.schemaVersion,
      observations: [CompositionPhraseObservation]
    ) {
      self.schemaVersion = schemaVersion
      self.observations = observations
    }

    public var schemaVersion: Int
    public var observations: [CompositionPhraseObservation]
  }

  public enum CompositionPhraseLearningError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidObservation(UUID)
  }

  public enum CompositionPhraseLearningResult: Sendable, Equatable {
    case ignored
    case pending(count: Int)
    case thresholdReached(observation: CompositionPhraseObservation)
  }

  /// MixType 組句短語學習的 pending observation store。
  ///
  /// 與「候選明確選字 Auto Promotion」分開保存，避免兩種訊號互相灌票；
  /// 兩者最後都只會升級到同一個 Personal Lexicon。
  public final class CompositionPhraseLearningStore {
    public static let schemaVersion = 1
    public static let minimumPhraseLength = 2
    public static let maximumPhraseLength = 6

    public init(observations: [CompositionPhraseObservation] = []) {
      replaceObservations(observations)
    }

    public private(set) var observations: [CompositionPhraseObservation] = []

    public func replaceObservations(_ newObservations: [CompositionPhraseObservation]) {
      observations = newObservations.filter(Self.isValid)
    }

    public func observation(phrase: String, readings: [String]) -> CompositionPhraseObservation? {
      observations.first { $0.phrase == phrase && $0.readings == readings }
    }

    @discardableResult
    public func observe(
      phrase: String,
      readings: [String],
      threshold: Int,
      now: Date = Date()
    ) -> CompositionPhraseLearningResult {
      let normalizedThreshold = max(2, min(20, threshold))
      guard Self.isValidPhraseAndReadings(phrase: phrase, readings: readings) else { return .ignored }

      if let index = observations.firstIndex(where: { $0.phrase == phrase && $0.readings == readings }) {
        observations[index].occurrenceCount += 1
        observations[index].lastSeenAt = now
        let updated = observations[index]
        if updated.occurrenceCount >= normalizedThreshold {
          return .thresholdReached(observation: updated)
        }
        return .pending(count: updated.occurrenceCount)
      }

      let observation = CompositionPhraseObservation(
        phrase: phrase,
        readings: readings,
        occurrenceCount: 1,
        firstSeenAt: now,
        lastSeenAt: now
      )
      observations.append(observation)
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
      return try encoder.encode(CompositionPhraseLearningDocument(observations: observations))
    }

    public func load(data: Data) throws {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let document = try decoder.decode(CompositionPhraseLearningDocument.self, from: data)
      guard document.schemaVersion == Self.schemaVersion else {
        throw CompositionPhraseLearningError.unsupportedSchema(document.schemaVersion)
      }
      guard document.observations.allSatisfy(Self.isValid) else {
        let badID = document.observations.first(where: { !Self.isValid($0) })?.id ?? UUID()
        throw CompositionPhraseLearningError.invalidObservation(badID)
      }
      replaceObservations(document.observations)
    }

    public static func isValidPhraseAndReadings(phrase: String, readings: [String]) -> Bool {
      guard (minimumPhraseLength ... maximumPhraseLength).contains(phrase.count) else { return false }
      guard readings.count == phrase.count, readings.allSatisfy({ !$0.isEmpty }) else { return false }
      guard phrase.unicodeScalars.allSatisfy(isCJKScalar) else { return false }
      return PersonalLexiconKeyGenerator.generate(readings: readings) != nil
    }

    private static func isValid(_ observation: CompositionPhraseObservation) -> Bool {
      observation.schemaVersion == schemaVersion
        && observation.occurrenceCount >= 1
        && isValidPhraseAndReadings(phrase: observation.phrase, readings: observation.readings)
    }

    private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
      switch scalar.value {
      case 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF,
           0x20000 ... 0x2FA1F:
        return true
      default:
        return false
      }
    }
  }
}
