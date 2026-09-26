// (c) 2026 and onwards The MixType Project.
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared

extension LXMgr {
  public struct MixTypeBackupSummary: Sendable, Equatable {
    public let hasCassette: Bool
    public let modeCount: Int
    public let payloadCount: Int
  }

  public enum MixTypeBackupError: Error, LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidDocument
    case invalidPreferences
    case invalidMode(String)
    case duplicateMode(String)
    case invalidCassetteFileName
    case invalidPayload(String)
    case payloadTooLarge
    case preferenceImportFailed

    public var errorDescription: String? {
      switch self {
      case let .unsupportedSchema(version):
        return "Unsupported MixType backup schema: \(version)."
      case .invalidDocument:
        return "The selected file is not a valid MixType backup."
      case .invalidPreferences:
        return "The backup contains invalid preference data."
      case let .invalidMode(mode):
        return "The backup contains an unsupported input mode: \(mode)."
      case let .duplicateMode(mode):
        return "The backup contains duplicate input-mode data: \(mode)."
      case .invalidCassetteFileName:
        return "The backup contains an invalid CIN cassette file name."
      case let .invalidPayload(role):
        return "The backup contains invalid data for \(role)."
      case .payloadTooLarge:
        return "The MixType backup is larger than the supported safety limit."
      case .preferenceImportFailed:
        return "The backup preferences could not be restored safely."
      }
    }
  }

  private struct MixTypeBackupDocument: Codable {
    static let schemaVersion = 1
    static let productIdentifier = "org.randytsay.MixType.backup"

    struct Cassette: Codable {
      let fileName: String
      let data: Data
    }

    struct ModePayload: Codable {
      let mode: String
      let phrases: Data?
      let filter: Data?
      let replacements: Data?
      let associates: Data?
      let symbols: Data?
      let personalLexicon: Data?
      let promotionPending: Data?
      let compositionPending: Data?
      let singleCharacterPreferences: Data?
    }

    let schemaVersion: Int
    let productIdentifier: String
    let createdAt: Date
    let preferences: Data
    let cassette: Cassette?
    let modes: [ModePayload]
    let symbolMenu: Data?
  }

  private static let mixTypeBackupMaximumBytes = 64 * 1024 * 1024
  private static let mixTypeBackupMaximumPayloadBytes = 16 * 1024 * 1024

  @discardableResult
  public static func exportMixTypeBackup(to destinationURL: URL) throws -> MixTypeBackupSummary {
    guard let preferences = UserDef.exportAsJSON() else {
      throw MixTypeBackupError.invalidPreferences
    }

    let cassettePayload: MixTypeBackupDocument.Cassette? = try {
      let path = cassettePath()
      guard !path.isEmpty, FileManager.default.isReadableFile(atPath: path) else { return nil }
      let url = URL(fileURLWithPath: path)
      let fileName = url.lastPathComponent
      try validateCassetteFileName(fileName)
      let data = try Data(contentsOf: url)
      try validatePayloadSize(data)
      return .init(fileName: fileName, data: data)
    }()

    let modes = try Shared.InputMode.validCases.map { mode in
      try MixTypeBackupDocument.ModePayload(
        mode: mode.rawValue,
        phrases: readOptionalBackupPayload(userDictDataURL(mode: mode, type: .thePhrases)),
        filter: readOptionalBackupPayload(userDictDataURL(mode: mode, type: .theFilter)),
        replacements: readOptionalBackupPayload(userDictDataURL(mode: mode, type: .theReplacements)),
        associates: readOptionalBackupPayload(userDictDataURL(mode: mode, type: .theAssociates)),
        symbols: readOptionalBackupPayload(userDictDataURL(mode: mode, type: .theSymbols)),
        personalLexicon: readOptionalBackupPayload(personalLexiconDataURL(mode: mode)),
        promotionPending: readOptionalBackupPayload(personalLexiconPromotionDataURL(mode: mode)),
        compositionPending: readOptionalBackupPayload(compositionPhraseLearningDataURL(mode: mode)),
        singleCharacterPreferences: readOptionalBackupPayload(singleCharacterPreferenceDataURL(mode: mode))
      )
    }
    let symbolMenu = try readOptionalBackupPayload(userSymbolMenuDataURL())

    let document = MixTypeBackupDocument(
      schemaVersion: MixTypeBackupDocument.schemaVersion,
      productIdentifier: MixTypeBackupDocument.productIdentifier,
      createdAt: Date(),
      preferences: preferences,
      cassette: cassettePayload,
      modes: modes,
      symbolMenu: symbolMenu
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(document)
    guard data.count <= mixTypeBackupMaximumBytes else {
      throw MixTypeBackupError.payloadTooLarge
    }

    let accessGranted = destinationURL.startAccessingSecurityScopedResource()
    defer { if accessGranted { destinationURL.stopAccessingSecurityScopedResource() } }
    try data.write(to: destinationURL, options: [.atomic])
    return backupSummary(document)
  }

  @discardableResult
  public static func restoreMixTypeBackup(from sourceURL: URL) throws -> MixTypeBackupSummary {
    let accessGranted = sourceURL.startAccessingSecurityScopedResource()
    defer { if accessGranted { sourceURL.stopAccessingSecurityScopedResource() } }

    let sourceData = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
    guard sourceData.count <= mixTypeBackupMaximumBytes else {
      throw MixTypeBackupError.payloadTooLarge
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let document = try? decoder.decode(MixTypeBackupDocument.self, from: sourceData) else {
      throw MixTypeBackupError.invalidDocument
    }
    try validateBackupDocument(document)

    let preferencesDictionary = try preferencesDictionary(from: document.preferences)
    let preferenceValidation = UserDef.diffAgainstCurrent(preferencesDictionary).result
    guard preferenceValidation.failures.isEmpty else {
      throw MixTypeBackupError.invalidPreferences
    }

    let defaultDataFolder = dataFolderPath(isDefaultFolder: true)
    let destinationMap = try destinationPayloadMap(document: document, basePath: defaultDataFolder)
    let oldFileData = destinationMap.reduce(into: [URL: Data?]()) { result, pair in
      result[pair.key] = .some(try? Data(contentsOf: pair.key))
    }
    let snapshot = UserDef.Snapshot()

    var cassetteDestination: URL?
    var cassetteDestinationOldData: Data?
    if let cassette = document.cassette {
      let destination = cassetteCacheDirectoryURL.appendingPathComponent(cassette.fileName)
      cassetteDestination = destination
      cassetteDestinationOldData = try? Data(contentsOf: destination)
    }

    do {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: defaultDataFolder, isDirectory: true),
        withIntermediateDirectories: true
      )
      for (url, payload) in destinationMap {
        if let payload {
          try payload.write(to: url, options: [.atomic])
        } else if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
      }

      if let cassette = document.cassette, let destination = cassetteDestination {
        try FileManager.default.createDirectory(
          at: cassetteCacheDirectoryURL,
          withIntermediateDirectories: true
        )
        try cassette.data.write(to: destination, options: [.atomic])
      }

      for userDef in UserDef.allCases where !UserDef.jsonExchangeBlacklist.contains(userDef) {
        UserDefaults.current.removeObject(forKey: userDef.rawValue)
      }
      let importResult = UserDef.importFromDictionary(preferencesDictionary)
      guard importResult.failures.isEmpty else {
        throw MixTypeBackupError.preferenceImportFailed
      }

      // Portable restore always lands in the local default data directory.
      UserDefaults.current.set("", forKey: UserDef.kUserDataFolderSpecified.rawValue)
      if let destination = cassetteDestination {
        UserDefaults.current.set(destination.path, forKey: UserDef.kCassettePath.rawValue)
      } else {
        UserDefaults.current.set("", forKey: UserDef.kCassettePath.rawValue)
      }

      initUserLexicons()
      loadCassetteData()
      syncLMPrefs()
      return backupSummary(document)
    } catch {
      for (url, oldData) in oldFileData {
        if let oldData {
          try? oldData.write(to: url, options: [.atomic])
        } else {
          try? FileManager.default.removeItem(at: url)
        }
      }
      if let cassetteDestination {
        if let cassetteDestinationOldData {
          try? cassetteDestinationOldData.write(to: cassetteDestination, options: [.atomic])
        } else {
          try? FileManager.default.removeItem(at: cassetteDestination)
        }
      }
      UserDef.resetAll()
      UserDef.load(from: snapshot)
      initUserLexicons()
      loadCassetteData()
      syncLMPrefs()
      throw error
    }
  }

  private static func validateBackupDocument(_ document: MixTypeBackupDocument) throws {
    guard document.schemaVersion == MixTypeBackupDocument.schemaVersion else {
      throw MixTypeBackupError.unsupportedSchema(document.schemaVersion)
    }
    guard document.productIdentifier == MixTypeBackupDocument.productIdentifier else {
      throw MixTypeBackupError.invalidDocument
    }
    try validatePayloadSize(document.preferences)
    _ = try preferencesDictionary(from: document.preferences)

    if let cassette = document.cassette {
      try validateCassetteFileName(cassette.fileName)
      try validatePayloadSize(cassette.data)
    }

    var seenModes = Set<String>()
    for payload in document.modes {
      guard Shared.InputMode(rawValue: payload.mode).map(Shared.InputMode.validCases.contains) == true else {
        throw MixTypeBackupError.invalidMode(payload.mode)
      }
      guard seenModes.insert(payload.mode).inserted else {
        throw MixTypeBackupError.duplicateMode(payload.mode)
      }
      for (_, data) in modePayloadPairs(payload) {
        guard let data else { continue }
        try validatePayloadSize(data)
      }
      try validateVersionedLearningPayloads(payload)
    }
    if let symbolMenu = document.symbolMenu {
      try validatePayloadSize(symbolMenu)
    }
  }

  private static func validateVersionedLearningPayloads(
    _ payload: MixTypeBackupDocument.ModePayload
  ) throws {
    if let data = payload.personalLexicon {
      let store = LXAssembly.PersonalLexiconStore()
      do { try store.load(data: data) } catch {
        throw MixTypeBackupError.invalidPayload("personalLexicon")
      }
    }
    if let data = payload.promotionPending {
      let store = LXAssembly.PersonalLexiconPromotionStore()
      do { try store.load(data: data) } catch {
        throw MixTypeBackupError.invalidPayload("promotionPending")
      }
    }
    if let data = payload.compositionPending {
      let store = LXAssembly.CompositionPhraseLearningStore()
      do { try store.load(data: data) } catch {
        throw MixTypeBackupError.invalidPayload("compositionPending")
      }
    }
    if let data = payload.singleCharacterPreferences {
      let store = LXAssembly.SingleCharacterPreferenceStore()
      do { try store.load(data: data) } catch {
        throw MixTypeBackupError.invalidPayload("singleCharacterPreferences")
      }
    }
  }

  private static func preferencesDictionary(from data: Data) throws -> [String: Any] {
    guard let json = try? JSONSerialization.jsonObject(with: data),
          let dict = json as? [String: Any]
    else {
      throw MixTypeBackupError.invalidPreferences
    }
    return dict
  }

  private static func destinationPayloadMap(
    document: MixTypeBackupDocument,
    basePath: String
  ) throws -> [URL: Data?] {
    var result = [URL: Data?]()
    for payload in document.modes {
      guard let mode = Shared.InputMode(rawValue: payload.mode),
            Shared.InputMode.validCases.contains(mode)
      else {
        throw MixTypeBackupError.invalidMode(payload.mode)
      }
      result[userDictDataURL(mode: mode, type: .thePhrases, basePath: basePath)] = .some(payload.phrases)
      result[userDictDataURL(mode: mode, type: .theFilter, basePath: basePath)] = .some(payload.filter)
      result[userDictDataURL(mode: mode, type: .theReplacements, basePath: basePath)] =
        .some(payload.replacements)
      result[userDictDataURL(mode: mode, type: .theAssociates, basePath: basePath)] =
        .some(payload.associates)
      result[userDictDataURL(mode: mode, type: .theSymbols, basePath: basePath)] = .some(payload.symbols)
      result[personalLexiconDataURL(mode: mode, basePath: basePath)] = .some(payload.personalLexicon)
      result[personalLexiconPromotionDataURL(mode: mode, basePath: basePath)] =
        .some(payload.promotionPending)
      result[compositionPhraseLearningDataURL(mode: mode, basePath: basePath)] =
        .some(payload.compositionPending)
      result[singleCharacterPreferenceDataURL(mode: mode, basePath: basePath)] =
        .some(payload.singleCharacterPreferences)
    }
    result[URL(fileURLWithPath: basePath).appendingPathComponent("symbols.dat")] =
      .some(document.symbolMenu)
    return result
  }

  private static func modePayloadPairs(
    _ payload: MixTypeBackupDocument.ModePayload
  ) -> [(String, Data?)] {
    [
      ("phrases", payload.phrases),
      ("filter", payload.filter),
      ("replacements", payload.replacements),
      ("associates", payload.associates),
      ("symbols", payload.symbols),
      ("personalLexicon", payload.personalLexicon),
      ("promotionPending", payload.promotionPending),
      ("compositionPending", payload.compositionPending),
      ("singleCharacterPreferences", payload.singleCharacterPreferences),
    ]
  }

  private static func readOptionalBackupPayload(_ url: URL) throws -> Data? {
    guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    try validatePayloadSize(data)
    return data
  }

  private static func validatePayloadSize(_ data: Data) throws {
    guard data.count <= mixTypeBackupMaximumPayloadBytes else {
      throw MixTypeBackupError.payloadTooLarge
    }
  }

  private static func validateCassetteFileName(_ fileName: String) throws {
    let canonical = URL(fileURLWithPath: fileName).lastPathComponent
    let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
    guard !fileName.isEmpty,
          fileName == canonical,
          fileName.utf8.count <= 255,
          !fileName.contains("\0"),
          ["cin", "cin2"].contains(ext)
    else {
      throw MixTypeBackupError.invalidCassetteFileName
    }
  }

  private static func backupSummary(_ document: MixTypeBackupDocument) -> MixTypeBackupSummary {
    let payloadCount = document.modes.reduce(0) { partial, payload in
      partial + modePayloadPairs(payload).compactMap(\.1).count
    } + (document.symbolMenu == nil ? 0 : 1) + (document.cassette == nil ? 0 : 1)
    return .init(
      hasCassette: document.cassette != nil,
      modeCount: document.modes.count,
      payloadCount: payloadCount
    )
  }
}
