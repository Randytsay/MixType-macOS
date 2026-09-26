// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - LXMgrTests

/// LXMgr（Darwin 宿主的使用者資料管理器）單元測試。
///
/// 收納原 `MainAssemblyTests` 的 001 家族——使用者資料沙盒 IO、磁帶快取路徑與退路、
/// iCloud 指引、符號連結解析、使用者資料夾規格空值判定——與原 `LXMgrMigrateTests`
/// 的位元組級使用者資料遷移。測試編號沿用原檔，便於與歷史紀錄對照。
@Suite(.serialized)
final class LXMgrTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
    // 生產路徑的 LXMgr.shared 已改由 phraseEditorDelegateProvider 延遲實體化；
    // 測試需要其 KVO 觀察器在場以錄製路徑失效警示，故在此顯式武裝。
    _ = LXMgr.shared
    LXMgr.prepareForUnitTests()
    LXMgr.resetRecordedPathInvalidityAlerts()
  }

  deinit {
    mainSync {
      LXMgr.resetAfterUnitTests()
      LXMgr.resetRecordedPathInvalidityAlerts()
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  @Test
  func test011_LXMgr_UnitTestSandboxIO() throws {
    let directories = [
      (label: "default", url: LXMgr.unitTestDataURL(isDefaultFolder: true)),
      (label: "custom", url: LXMgr.unitTestDataURL(isDefaultFolder: false)),
    ]
    let fileManager = FileManager.default

    for (label, folderURL) in directories {
      let path = folderURL.path
      var isDirectory = ObjCBool(false)
      #expect(
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
        "Missing \(label) folder at: \(path)"
      )
      #expect(isDirectory.boolValue, "Path is not directory for \(label) folder at: \(path)")
      #expect(
        fileManager.isReadableFile(atPath: path),
        "Unreadable \(label) folder at: \(path)"
      )
      #expect(
        fileManager.isWritableFile(atPath: path),
        "Unwritable \(label) folder at: \(path)"
      )

      let payload = "io-check-\(UUID().uuidString)"
      let fileURL = folderURL.appendingPathComponent("io-check-\(UUID().uuidString).txt")

      try Data(payload.utf8).write(to: fileURL, options: [.atomic])
      let readBack = try String(contentsOf: fileURL, encoding: .utf8)
      #expect(readBack == payload, "Mismatched content for \(label) folder at: \(path)")
      try fileManager.removeItem(at: fileURL)
    }
  }

  @Test
  func test012_LXMgr_CassetteCacheUsesUnitTestSandbox() {
    let expectedURL = LXMgr.unitTestDataURL(isDefaultFolder: true).appendingPathComponent("Cassettes")
    #expect(LXMgr.cassetteCacheDirectoryURL.path == expectedURL.path)
  }

  @Test
  func test013_LXMgr_CassettePathFallsBackToCachedCopy() throws {
    let fileManager = FileManager.default
    let externalURL = LXMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-fallback-\(UUID().uuidString).cin2")
    let cacheURL = LXMgr.cassetteCacheDirectoryURL.appendingPathComponent(externalURL.lastPathComponent)

    defer {
      try? fileManager.removeItem(at: externalURL)
      try? fileManager.removeItem(at: cacheURL)
      LXMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LXMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-fallback".utf8).write(to: externalURL, options: [.atomic])
    #expect(LXMgr.importCassetteFileToCache(from: externalURL))

    PrefMgr.shared.cassettePath = externalURL.path
    try fileManager.removeItem(at: externalURL)

    #expect(LXMgr.cassettePath() == cacheURL.path)

    // Verify that a path-invalidity alert was captured (instead of a blocking modal).
    let cassetteAlerts = LXMgr.recordedPathInvalidityAlerts.filter {
      $0.infoText.contains(externalURL.lastPathComponent)
    }
    #expect(
      !cassetteAlerts.isEmpty,
      "Expected a cassette-path-invalidity alert for \(externalURL.lastPathComponent)."
    )
  }

  @Test
  func test014_LXMgr_ResetCassettePathKeepsDirectCacheSource() throws {
    let fileManager = FileManager.default
    let cacheURL = LXMgr.cassetteCacheDirectoryURL
      .appendingPathComponent("phase25-direct-cache-\(UUID().uuidString).cin2")

    defer {
      try? fileManager.removeItem(at: cacheURL)
      LXMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LXMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-direct-cache".utf8).write(to: cacheURL, options: [.atomic])

    PrefMgr.shared.cassettePath = cacheURL.path
    LXMgr.resetCassettePath()

    #expect(fileManager.fileExists(atPath: cacheURL.path))
  }

  @Test
  func test015_LXMgr_ResetCassettePathRemovesImportedCacheCopy() throws {
    let fileManager = FileManager.default
    let externalURL = LXMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-reset-\(UUID().uuidString).cin2")
    let cacheURL = LXMgr.cassetteCacheDirectoryURL.appendingPathComponent(externalURL.lastPathComponent)

    defer {
      try? fileManager.removeItem(at: externalURL)
      try? fileManager.removeItem(at: cacheURL)
      LXMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LXMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-reset".utf8).write(to: externalURL, options: [.atomic])
    #expect(LXMgr.importCassetteFileToCache(from: externalURL))

    PrefMgr.shared.cassettePath = externalURL.path
    LXMgr.resetCassettePath()

    #expect(fileManager.fileExists(atPath: externalURL.path))
    #expect(!fileManager.fileExists(atPath: cacheURL.path))
  }

  @Test
  func test016_LXMgr_CassetteAccessFailureAddsICloudGuidanceForCloudDocsPaths() {
    let mirroredPath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Mobile Documents", isDirectory: true)
      .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
      .appendingPathComponent("phase25-guidance.cin2")
      .path
    let advice = "i18n:LXMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LXMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LXMgr.cassetteAccessFailureDescription(path: mirroredPath)

    #expect(description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test017_LXMgr_CassetteAccessFailureAddsICloudGuidanceForMirroredFoldersWhenSyncEnabled() {
    let originalOverride = LXMgr.iCloudPathDetectionOverride
    LXMgr.iCloudPathDetectionOverride = { candidatePath in
      candidatePath.contains("/Documents/")
    }
    defer { LXMgr.iCloudPathDetectionOverride = originalOverride }

    let mirroredPath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("phase25-mirrored-guidance.cin2")
      .path
    let advice = "i18n:LXMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LXMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LXMgr.cassetteAccessFailureDescription(path: mirroredPath)

    #expect(description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test018_LXMgr_CassetteAccessFailureSkipsICloudGuidanceOutsideMirroredFolders() {
    let originalOverride = LXMgr.iCloudPathDetectionOverride
    LXMgr.iCloudPathDetectionOverride = { _ in false }
    defer { LXMgr.iCloudPathDetectionOverride = originalOverride }

    let localPath = LXMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-local-guidance.cin2")
      .path
    let base = "i18n:LXMgr.accessFailure.cassette.description".i18n
    let advice = "i18n:LXMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LXMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LXMgr.cassetteAccessFailureDescription(path: localPath)

    #expect(description.contains(base))
    #expect(!description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test019_LXMgr_ResolveUserSpecifiedURLResolvesCassetteSymlink() throws {
    let fileManager = FileManager.default
    let baseURL = LXMgr.unitTestDataURL(isDefaultFolder: false)
    let targetURL = baseURL.appendingPathComponent("phase25-real-\(UUID().uuidString).cin2")
    let symlinkURL = baseURL.appendingPathComponent("phase25-link-\(UUID().uuidString).cin2")

    defer {
      try? fileManager.removeItem(at: symlinkURL)
      try? fileManager.removeItem(at: targetURL)
    }

    try Data("phase25-symlink-target".utf8).write(to: targetURL, options: [.atomic])
    try fileManager.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: targetURL.path)

    let resolvedURL = LXMgr.resolveUserSpecifiedURL(symlinkURL)

    #expect(resolvedURL.path == targetURL.standardizedFileURL.path)
  }

  @Test
  func test020_LXMgr_ResolveUserSpecifiedURLResolvesUserDataFolderSymlink() throws {
    let fileManager = FileManager.default
    let baseURL = LXMgr.unitTestDataURL(isDefaultFolder: false)
    let targetURL = baseURL.appendingPathComponent("phase25-real-folder-\(UUID().uuidString)", isDirectory: true)
    let symlinkURL = baseURL.appendingPathComponent("phase25-link-folder-\(UUID().uuidString)", isDirectory: true)

    defer {
      try? fileManager.removeItem(at: symlinkURL)
      try? fileManager.removeItem(at: targetURL)
    }

    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: targetURL.path)

    let resolvedURL = LXMgr.resolveUserSpecifiedURL(symlinkURL)

    #expect(resolvedURL.path == targetURL.standardizedFileURL.path)
  }

  // 單元測試模式下 dataFolderPath() 會提早跳入測試沙盒，無法直接驅動其產品分支；
  // 故直接測試空值判定函式與合規性驗證器的行為（空字串不得被解讀成 "/" 而誤報失效）。

  @Test
  func test021_LXMgr_EmptyUserDataFolderSpecIsEffectivelyUnset() {
    // AppProperty 初次初始化會把空字串預設值寫入 prefs，使「從未指定」看起來像「指定了空路徑」。
    // 空字串與其補尾斜槓產物 "/" 皆必須視為「未指定」。
    #expect(LXMgr.userDataFolderPathIsEffectivelyUnset(""))
    #expect(LXMgr.userDataFolderPathIsEffectivelyUnset("/"))
    #expect(!LXMgr.userDataFolderPathIsEffectivelyUnset("/Users/Shared/vChewing/"))
    #expect(!LXMgr.userDataFolderPathIsEffectivelyUnset("~"))
  }

  @Test
  func test022_LXMgr_EmptyUserDataFolderSpecSkipsValidityAlert() {
    LXMgr.resetRecordedPathInvalidityAlerts()
    defer { LXMgr.resetRecordedPathInvalidityAlerts() }
    Broadcaster.shared.clearLmMgrDataFolderPathInvalidity()

    // 空值（nil／空字串）＝「尚未指定自訂目錄」：視為合規、不得觸發失效警示。
    #expect(LXMgr.checkIfSpecifiedUserDataFolderValid(""))
    #expect(LXMgr.checkIfSpecifiedUserDataFolderValid(nil))
    #expect(LXMgr.recordedPathInvalidityAlerts.isEmpty)

    // 真實存在且可寫入的目錄依然照常通過。
    #expect(
      LXMgr.checkIfSpecifiedUserDataFolderValid(LXMgr.unitTestDataURL(isDefaultFolder: true).path)
    )
    #expect(LXMgr.recordedPathInvalidityAlerts.isEmpty)
  }

  @Test
  func test023_LXMgr_AppPropertyAutoSeedsEmptyDefaultIntoPrefs() {
    // 前提驗證：AppProperty 的 init 會在 key 缺席時把預設值寫入 prefs——這使「從未手動指定」
    // 的 kUserDataFolderSpecified 以空字串形式存在於 prefs，成為被誤讀成 "/" 的來源。
    let defaults = UserDefaults.current
    defaults.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    defer { defaults.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue) }
    _ = PrefMgr() // 每次實體化皆會重新觸發所有 @AppProperty 的 seeding。
    #expect(defaults.string(forKey: UserDef.kUserDataFolderSpecified.rawValue) == "")
  }

  @Test
  func test024_LXMgr_PersonalLexiconPathUsesUnitTestSandbox() {
    let url = LXMgr.personalLexiconDataURL(mode: .imeModeCHT)
    #expect(url.deletingLastPathComponent().path == LXMgr.unitTestDataURL(isDefaultFolder: false).path)
    #expect(url.lastPathComponent == "personal-lexicon-cht.json")

    let chsURL = LXMgr.personalLexiconDataURL(mode: .imeModeCHS)
    #expect(chsURL.lastPathComponent == "personal-lexicon-chs.json")
  }

  @Test
  func test025_LXMgr_PersonalLexiconAtomicSaveAndReload() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconDataURL(mode: mode)
    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      createdAt: fixedDate,
      updatedAt: fixedDate,
      pinned: true
    )
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replacePersonalLexiconEntries([entry])
    try LXMgr.savePersonalLexiconData(mode: mode)
    #expect(FileManager.default.isReadableFile(atPath: url.path))

    mode.lexicon.replacePersonalLexiconEntries([])
    #expect(mode.lexicon.personalLexiconEntries.isEmpty)
    LXMgr.loadPersonalLexiconData(mode: mode)

    #expect(mode.lexicon.personalLexiconEntries == [entry])
    #expect(mode.lexicon.lxQuerier.personalLexiconMatches(for: "tdny").first?.entry.phrase == "台達能源")
  }

  @Test
  func test026_LXMgr_AddPersonalPhraseDerivesKeysAndPersists() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconDataURL(mode: mode)
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
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      LXAssembly.LXFacade.disconnectFactoryDictionary()
      try? FileManager.default.removeItem(at: url)
    }
    #expect(LXAssembly.LXFacade.connectToTestFactoryDictionary(textMapData: fixture))

    let entry = try LXMgr.addPersonalLexiconPhrase("  台達能源  ", mode: mode)

    #expect(entry.phrase == "台達能源")
    #expect(entry.readings == ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"])
    #expect(entry.fullPinyinKey == "taidanengyuan")
    #expect(entry.initialsKey == "tdny")
    #expect(entry.pinned)
    #expect(mode.lexicon.lxQuerier.personalLexiconMatches(for: "tdny").first?.entry.phrase == "台達能源")
    #expect(FileManager.default.isReadableFile(atPath: url.path))

    mode.lexicon.replacePersonalLexiconEntries([])
    LXMgr.loadPersonalLexiconData(mode: mode)
    #expect(mode.lexicon.lxQuerier.personalLexiconMatches(for: "taidanengyuan").first?.entry.phrase == "台達能源")
  }

  @Test
  func test027_LXMgr_InitUserLexiconsReloadsPersonalLexiconFromDisk() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconDataURL(mode: mode)
    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      createdAt: fixedDate,
      updatedAt: fixedDate,
      pinned: true
    )
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replacePersonalLexiconEntries([entry])
    try LXMgr.savePersonalLexiconData(mode: mode)
    mode.lexicon.replacePersonalLexiconEntries([])
    #expect(mode.lexicon.personalLexiconEntries.isEmpty)

    LXMgr.initUserLexicons()

    #expect(mode.lexicon.personalLexiconEntries == [entry])
    #expect(mode.lexicon.lxQuerier.personalLexiconMatches(for: "tdny").first?.entry.phrase == "台達能源")
  }

  @Test
  func test028_LXMgr_EnsurePersonalLexiconLoadedRepairsEmptyRuntimeStore() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconDataURL(mode: mode)
    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      createdAt: fixedDate,
      updatedAt: fixedDate,
      pinned: true
    )
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replacePersonalLexiconEntries([entry])
    try LXMgr.savePersonalLexiconData(mode: mode)
    mode.lexicon.replacePersonalLexiconEntries([])
    #expect(mode.lexicon.personalLexiconEntries.isEmpty)

    LXMgr.ensurePersonalLexiconLoaded(mode: mode)

    #expect(mode.lexicon.personalLexiconEntries == [entry])
    #expect(mode.lexicon.lxQuerier.personalLexiconMatches(for: "tdny").first?.entry.phrase == "台達能源")
  }

  @Test
  func test029_LXMgr_PersonalLexiconUpdateAndDeletePersist() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconDataURL(mode: mode)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      selectionCount: 7,
      pinned: true
    )
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? FileManager.default.removeItem(at: url)
    }
    mode.lexicon.replacePersonalLexiconEntries([entry])
    try LXMgr.savePersonalLexiconData(mode: mode)

    let updated = try LXMgr.updatePersonalLexiconEntry(
      id: entry.id,
      phrase: "台達能源",
      readings: entry.readings,
      pinned: false,
      disabled: true,
      mode: mode
    )
    #expect(updated.id == entry.id)
    #expect(updated.selectionCount == 7)
    #expect(!updated.pinned)
    #expect(updated.disabled)

    mode.lexicon.replacePersonalLexiconEntries([])
    LXMgr.loadPersonalLexiconData(mode: mode)
    let reloaded = try #require(mode.lexicon.personalLexiconEntries.first)
    #expect(reloaded.id == entry.id)
    #expect(reloaded.disabled)

    #expect(try LXMgr.removePersonalLexiconEntry(id: entry.id, mode: mode))
    #expect(mode.lexicon.personalLexiconEntries.isEmpty)
    mode.lexicon.replacePersonalLexiconEntries([entry])
    LXMgr.loadPersonalLexiconData(mode: mode)
    #expect(mode.lexicon.personalLexiconEntries.isEmpty)
  }

  @Test
  func test030_LXMgr_PersonalLexiconImportMergeAndExportRoundTrip() throws {
    let mode = Shared.InputMode.imeModeCHT
    let persistedURL = LXMgr.personalLexiconDataURL(mode: mode)
    let importURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("personal-import-\(UUID().uuidString).json")
    let exportURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("personal-export-\(UUID().uuidString).json")
    let existing = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      pinned: true
    )
    let imported = LXAssembly.PersonalLexiconEntry(
      phrase: "節能方案",
      readings: ["ㄐㄧㄝˊ", "ㄋㄥˊ", "ㄈㄤ", "ㄢˋ"],
      pinyinTokens: ["jie", "neng", "fang", "an"],
      fullPinyinKey: "jienengfangan",
      initialsKey: "jnfa",
      source: .manual
    )
    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? FileManager.default.removeItem(at: persistedURL)
      try? FileManager.default.removeItem(at: importURL)
      try? FileManager.default.removeItem(at: exportURL)
    }

    mode.lexicon.replacePersonalLexiconEntries([existing])
    try LXMgr.savePersonalLexiconData(mode: mode)
    let importStore = LXAssembly.PersonalLexiconStore(entries: [imported])
    try importStore.encode().write(to: importURL, options: [.atomic])

    #expect(try LXMgr.importPersonalLexicon(from: importURL, mode: mode) == 1)
    #expect(Set(mode.lexicon.personalLexiconEntries.map(\.phrase)) == ["台達能源", "節能方案"])

    try LXMgr.exportPersonalLexicon(to: exportURL, mode: mode)
    let exportedStore = LXAssembly.PersonalLexiconStore()
    try exportedStore.load(data: Data(contentsOf: exportURL))
    #expect(Set(exportedStore.entries.map(\.phrase)) == ["台達能源", "節能方案"])
  }

  @Test
  func test031_LXMgr_PersonalLexiconPromotionPendingSaveAndReload() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.personalLexiconPromotionDataURL(mode: mode)
    defer {
      mode.lexicon.replacePersonalLexiconPromotionObservations([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replacePersonalLexiconPromotionObservations([])
    #expect(
      mode.lexicon.observePersonalLexiconPromotion(
        phrase: "蔡耀文",
        readings: ["ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ"],
        threshold: 3,
        now: Date(timeIntervalSince1970: 1_700_000_000)
      ) == .pending(count: 1)
    )
    try LXMgr.savePersonalLexiconPromotionData(mode: mode)
    #expect(FileManager.default.isReadableFile(atPath: url.path))

    mode.lexicon.replacePersonalLexiconPromotionObservations([])
    #expect(mode.lexicon.personalLexiconPromotionObservations.isEmpty)
    LXMgr.loadPersonalLexiconPromotionData(mode: mode)

    let restored = try #require(mode.lexicon.personalLexiconPromotionObservations.first)
    #expect(restored.phrase == "蔡耀文")
    #expect(restored.readings == ["ㄘㄞˋ", "ㄧㄠˋ", "ㄨㄣˊ"])
    #expect(restored.selectionCount == 1)
  }

  @Test
  func test032_LXMgr_ProductionFactoryDerivesHuiLingCorrectly() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let path = try #require(LXMgr.getCoreDictionaryDBPath(factory: true))
    LXMgr.connectCoreDB(dbPath: path)

    let readings = try #require(
      LXAssembly.PersonalLexiconReadingResolver.resolveFactoryReadings(for: "卉羚")
    )
    #expect(readings == ["ㄏㄨㄟˋ", "ㄌㄧㄥˊ"])

    let entry = try #require(
      LXAssembly.PersonalLexiconReadingResolver.makeManualEntry(phrase: "卉羚")
    )
    #expect(entry.pinyinTokens == ["hui", "ling"])
    #expect(entry.fullPinyinKey == "huiling")
    #expect(entry.initialsKey == "hl")
  }

  @Test
  func test033_LXMgr_SingleCharacterPreferenceSaveAndReload() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.singleCharacterPreferenceDataURL(mode: mode)
    defer {
      mode.lexicon.replaceSingleCharacterPreferenceEntries([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replaceSingleCharacterPreferenceEntries([])
    #expect(mode.lexicon.recordSingleCharacterPreference(reading: "ㄧㄠˋ", value: "耀") != nil)
    #expect(mode.lexicon.recordSingleCharacterPreference(reading: "ㄧㄠˋ", value: "耀") != nil)
    try LXMgr.saveSingleCharacterPreferenceData(mode: mode)

    mode.lexicon.replaceSingleCharacterPreferenceEntries([])
    #expect(mode.lexicon.singleCharacterPreferenceEntries.isEmpty)
    LXMgr.loadSingleCharacterPreferenceData(mode: mode)

    #expect(mode.lexicon.singleCharacterPreference(reading: "ㄧㄠ", value: "耀")?.selectionCount == 2)
  }

  @Test
  func test034_LXMgr_CompositionPhraseLearningSaveAndReload() throws {
    let mode = Shared.InputMode.imeModeCHT
    let url = LXMgr.compositionPhraseLearningDataURL(mode: mode)
    defer {
      mode.lexicon.replaceCompositionPhraseLearningObservations([])
      try? FileManager.default.removeItem(at: url)
    }

    mode.lexicon.replaceCompositionPhraseLearningObservations([])
    #expect(
      mode.lexicon.observeCompositionPhrasePromotion(
        phrase: "就好了",
        readings: ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"],
        threshold: 3,
        now: Date(timeIntervalSince1970: 1_700_000_000)
      ) == .pending(count: 1)
    )
    try LXMgr.saveCompositionPhraseLearningData(mode: mode)
    #expect(FileManager.default.isReadableFile(atPath: url.path))

    mode.lexicon.replaceCompositionPhraseLearningObservations([])
    #expect(mode.lexicon.compositionPhraseLearningObservations.isEmpty)
    LXMgr.loadCompositionPhraseLearningData(mode: mode)

    let restored = try #require(mode.lexicon.compositionPhraseLearningObservations.first)
    #expect(restored.phrase == "就好了")
    #expect(restored.readings == ["ㄐㄧㄡˋ", "ㄏㄠˇ", "ㄌㄜ˙"])
    #expect(restored.occurrenceCount == 1)
  }

  @Test
  func test035_LXMgr_ProductionFactoryContainsGuoLaiYiXiaSegments() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let path = try #require(LXMgr.getCoreDictionaryDBPath(factory: true))
    LXMgr.connectCoreDB(dbPath: path)

    let mode = Shared.InputMode.imeModeCHT
    let guoLai = mode.lexicon.lxQuerier.hybridPhoneticGrams(for: [
      .singleKey("ㄍㄨㄛˋ"),
      .singleKey("ㄌㄞˊ"),
    ])
    #expect(guoLai.contains { $0.isUnigram && $0.current == "過來" })

    let yiXiaTone1 = mode.lexicon.lxQuerier.hybridPhoneticGrams(for: [
      .singleKey("ㄧ"),
      .singleKey("ㄒㄧㄚˋ"),
    ])
    let yiXiaTone2 = mode.lexicon.lxQuerier.hybridPhoneticGrams(for: [
      .singleKey("ㄧˊ"),
      .singleKey("ㄒㄧㄚˋ"),
    ])
    #expect((yiXiaTone1 + yiXiaTone2).contains { $0.isUnigram && $0.current == "一下" })
  }

  @Test
  func test036_LXMgr_ProductionFactoryReadingGatePreservesLegitimateVariants() throws {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let path = try #require(LXMgr.getCoreDictionaryDBPath(factory: true))
    LXMgr.connectCoreDB(dbPath: path)

    let chains = LXAssembly.LXFacade.getFactoryExactReadingChains(for: ["什麼"])["什麼"] ?? []
    #expect(chains.contains(["ㄕㄜˊ", "ㄇㄛ˙"]))
    #expect(chains.contains(["ㄕㄜˊ", "ㄇㄜ˙"]))
    #expect(chains.contains(["ㄕㄣˊ", "ㄇㄛ˙"]))
    #expect(chains.contains(["ㄕㄣˊ", "ㄇㄜ˙"]))

    #expect(
      LXAssembly.LXFacade.factoryExactReadingStatus(
        phrase: "什麼",
        readings: ["ㄕㄜˊ", "ㄇㄛ˙"]
      ) == .supported
    )
    #expect(
      LXAssembly.LXFacade.factoryExactReadingStatus(
        phrase: "什麼",
        readings: ["ㄕㄜˇ", "ㄇㄚ"]
      ) == .unsupported
    )

    let validFacade = LXAssembly.LXFacade(isCHS: false)
    validFacade.replacePersonalLexiconEntries([])
    validFacade.replacePersonalLexiconPromotionObservations([])
    let validReadings = ["ㄕㄜˊ", "ㄇㄛ˙"]
    #expect(validFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: validReadings, threshold: 3
    ) == .pending(count: 1))
    #expect(validFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: validReadings, threshold: 3
    ) == .pending(count: 2))
    let validThird = validFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: validReadings, threshold: 3
    )
    guard case let .promoted(validEntry) = validThird else {
      Issue.record("A production-supported reading variant must remain promotable.")
      return
    }
    #expect(validEntry.readings == validReadings)

    let invalidFacade = LXAssembly.LXFacade(isCHS: false)
    invalidFacade.replacePersonalLexiconEntries([])
    invalidFacade.replacePersonalLexiconPromotionObservations([])
    let invalidReadings = ["ㄕㄜˇ", "ㄇㄚ"]
    #expect(invalidFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: invalidReadings, threshold: 3
    ) == .pending(count: 1))
    #expect(invalidFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: invalidReadings, threshold: 3
    ) == .pending(count: 2))
    #expect(invalidFacade.observePersonalLexiconPromotion(
      phrase: "什麼", readings: invalidReadings, threshold: 3
    ) == .rejectedUnsupportedFactoryReading)
    #expect(invalidFacade.personalLexiconPromotionObservations.isEmpty)
    #expect(invalidFacade.personalLexiconEntries.isEmpty)
  }

  @Test
  func test037_LXMgr_MixTypeBackupRoundTripUsesPortableLocalPaths() throws {
    let fileManager = FileManager.default
    let mode = Shared.InputMode.imeModeCHT
    let sourceDataFolder = LXMgr.dataFolderPath(isDefaultFolder: false)
    let restoredDataFolder = LXMgr.dataFolderPath(isDefaultFolder: true)
    let sourcePersonalURL = LXMgr.personalLexiconDataURL(mode: mode, basePath: sourceDataFolder)
    let restoredPersonalURL = LXMgr.personalLexiconDataURL(mode: mode, basePath: restoredDataFolder)
    let sourcePhraseURL = LXMgr.userDictDataURL(
      mode: mode,
      type: .thePhrases,
      basePath: sourceDataFolder
    )
    let restoredPhraseURL = LXMgr.userDictDataURL(
      mode: mode,
      type: .thePhrases,
      basePath: restoredDataFolder
    )
    let sourceFilterURL = LXMgr.userDictDataURL(
      mode: mode,
      type: .theFilter,
      basePath: sourceDataFolder
    )
    let restoredFilterURL = LXMgr.userDictDataURL(
      mode: mode,
      type: .theFilter,
      basePath: restoredDataFolder
    )
    let externalCassetteURL = LXMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("portable-(UUID().uuidString).cin")
    let restoredCassetteURL = LXMgr.cassetteCacheDirectoryURL
      .appendingPathComponent(externalCassetteURL.lastPathComponent)
    let backupURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("MixType-(UUID().uuidString).mixtypebackup")
    let preferenceKey = UserDef.kMixTypeAutoPromotionThreshold.rawValue
    let originalPreference = UserDefaults.current.object(forKey: preferenceKey)
    let originalCassettePath = UserDefaults.current.object(forKey: UserDef.kCassettePath.rawValue)
    let originalUserDataPath = UserDefaults.current.object(
      forKey: UserDef.kUserDataFolderSpecified.rawValue
    )

    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let entry = LXAssembly.PersonalLexiconEntry(
      phrase: "台達能源",
      readings: ["ㄊㄞˊ", "ㄉㄚˊ", "ㄋㄥˊ", "ㄩㄢˊ"],
      pinyinTokens: ["tai", "da", "neng", "yuan"],
      fullPinyinKey: "taidanengyuan",
      initialsKey: "tdny",
      source: .manual,
      createdAt: fixedDate,
      updatedAt: fixedDate,
      pinned: true
    )
    let cassetteFixture = """
    %ename MixTypeBackup
    %cname MixTypeBackup
    %selkey 1234567890
    %keyname begin
    a a
    %keyname end
    %chardef begin
    a 啊
    %chardef end
    """
    let phraseFixture = "台達能源 ㄊㄞˊ-ㄉㄚˊ-ㄋㄥˊ-ㄩㄢˊ\n"

    defer {
      mode.lexicon.replacePersonalLexiconEntries([])
      try? fileManager.removeItem(at: sourcePersonalURL)
      try? fileManager.removeItem(at: restoredPersonalURL)
      try? fileManager.removeItem(at: sourcePhraseURL)
      try? fileManager.removeItem(at: restoredPhraseURL)
      try? fileManager.removeItem(at: sourceFilterURL)
      try? fileManager.removeItem(at: restoredFilterURL)
      try? fileManager.removeItem(at: externalCassetteURL)
      try? fileManager.removeItem(at: restoredCassetteURL)
      try? fileManager.removeItem(at: backupURL)
      if let originalPreference {
        UserDefaults.current.set(originalPreference, forKey: preferenceKey)
      } else {
        UserDefaults.current.removeObject(forKey: preferenceKey)
      }
      if let originalCassettePath {
        UserDefaults.current.set(originalCassettePath, forKey: UserDef.kCassettePath.rawValue)
      } else {
        UserDefaults.current.removeObject(forKey: UserDef.kCassettePath.rawValue)
      }
      if let originalUserDataPath {
        UserDefaults.current.set(
          originalUserDataPath,
          forKey: UserDef.kUserDataFolderSpecified.rawValue
        )
      } else {
        UserDefaults.current.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue)
      }
      LXMgr.loadCassetteData()
    }

    try fileManager.createDirectory(
      at: URL(fileURLWithPath: sourceDataFolder, isDirectory: true),
      withIntermediateDirectories: true
    )
    mode.lexicon.replacePersonalLexiconEntries([entry])
    try entryDocumentData([entry]).write(to: sourcePersonalURL, options: [.atomic])
    try Data(phraseFixture.utf8).write(to: sourcePhraseURL, options: [.atomic])
    try? fileManager.removeItem(at: sourceFilterURL)
    try Data(cassetteFixture.utf8).write(to: externalCassetteURL, options: [.atomic])
    UserDefaults.current.set(externalCassetteURL.path, forKey: UserDef.kCassettePath.rawValue)
    UserDefaults.current.set(9, forKey: preferenceKey)

    let exportSummary = try LXMgr.exportMixTypeBackup(to: backupURL)
    #expect(exportSummary.hasCassette)
    #expect(exportSummary.modeCount == 2)
    #expect(fileManager.isReadableFile(atPath: backupURL.path))
    let exportedText = try String(contentsOf: backupURL, encoding: .utf8)
    #expect(!exportedText.contains(externalCassetteURL.path))
    #expect(!exportedText.contains(sourceDataFolder))

    // Simulate a new Mac: old absolute path and old user data no longer exist.
    UserDefaults.current.set(2, forKey: preferenceKey)
    UserDefaults.current.set("/old/mac/path/that/does/not/exist.cin", forKey: UserDef.kCassettePath.rawValue)
    try fileManager.removeItem(at: externalCassetteURL)
    try fileManager.removeItem(at: sourcePersonalURL)
    try fileManager.removeItem(at: sourcePhraseURL)
    mode.lexicon.replacePersonalLexiconEntries([])
    try Data("stale-filter-from-new-mac".utf8).write(to: restoredFilterURL, options: [.atomic])
    #expect(fileManager.fileExists(atPath: restoredFilterURL.path))

    let restoreSummary = try LXMgr.restoreMixTypeBackup(from: backupURL)
    #expect(restoreSummary == exportSummary)
    #expect(UserDefaults.current.integer(forKey: preferenceKey) == 9)
    #expect(UserDefaults.current.string(forKey: UserDef.kUserDataFolderSpecified.rawValue) == "")
    #expect(UserDefaults.current.string(forKey: UserDef.kCassettePath.rawValue) == restoredCassetteURL.path)
    #expect(try Data(contentsOf: restoredCassetteURL) == Data(cassetteFixture.utf8))
    #expect(try String(contentsOf: restoredPhraseURL, encoding: .utf8) == phraseFixture)
    #expect(!fileManager.fileExists(atPath: restoredFilterURL.path))

    let restoredStore = LXAssembly.PersonalLexiconStore()
    try restoredStore.load(data: Data(contentsOf: restoredPersonalURL))
    #expect(restoredStore.entries == [entry])
  }

  @Test
  func test038_LXMgr_InvalidMixTypeBackupFailsClosedWithoutChangingState() throws {
    let fileManager = FileManager.default
    let backupURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Broken-(UUID().uuidString).mixtypebackup")
    let preferenceKey = UserDef.kMixTypeAutoPromotionThreshold.rawValue
    let oldValue = 7
    UserDefaults.current.set(oldValue, forKey: preferenceKey)
    defer {
      try? fileManager.removeItem(at: backupURL)
      UserDefaults.current.removeObject(forKey: preferenceKey)
    }

    try Data(#"{"schemaVersion":999,"productIdentifier":"org.randytsay.MixType.backup"}"#.utf8)
      .write(to: backupURL, options: [.atomic])

    #expect(throws: Error.self) {
      try LXMgr.restoreMixTypeBackup(from: backupURL)
    }
    #expect(UserDefaults.current.integer(forKey: preferenceKey) == oldValue)
  }

  // MARK: - 使用者資料遷移

  @Test
  func testMigratePreservesInvalidUTF8() throws {
    // migrateUserDataFrom 全程以位元組進行：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
    let (oldDir, newDir) = try Self.makeDirs()
    defer {
      try? FileManager.default.removeItem(at: oldDir)
      try? FileManager.default.removeItem(at: newDir)
    }

    let type = LXAssembly.ReplacableUserDataType.theAssociates
    let mode = Shared.InputMode.imeModeCHT
    let oldURL = LXMgr.userDictDataURL(mode: mode, type: type, basePath: oldDir.path)
    let newURL = LXMgr.userDictDataURL(mode: mode, type: type, basePath: newDir.path)

    let newBytes = Array("芳 苑 鄰 香\n".utf8)
    let oldBytes: [UInt8] = Array("芳 芳香 苑\n".utf8) + [0xFF, 0xFE]
    try Data(newBytes).write(to: newURL)
    try Data(oldBytes).write(to: oldURL)

    let migrated = LXMgr.migrateUserDataFrom(oldPath: oldDir.path, to: newDir.path)
    #expect(migrated == 1)
    let merged = try Data(contentsOf: newURL)
    #expect(Array(merged) == newBytes + [0x0A] + oldBytes)
  }

  @Test
  func testMigrateSkipsWhitespaceOnlyOldFile() throws {
    // 舊檔全為空白／斷行時跳過合併（byte 層級空檔判斷，對齊 CharacterSet.whitespacesAndNewlines）。
    let (oldDir, newDir) = try Self.makeDirs()
    defer {
      try? FileManager.default.removeItem(at: oldDir)
      try? FileManager.default.removeItem(at: newDir)
    }

    let type = LXAssembly.ReplacableUserDataType.theAssociates
    let mode = Shared.InputMode.imeModeCHT
    let oldURL = LXMgr.userDictDataURL(mode: mode, type: type, basePath: oldDir.path)
    let newURL = LXMgr.userDictDataURL(mode: mode, type: type, basePath: newDir.path)

    let newBytes = Array("芳 苑 鄰 香\n".utf8)
    let oldBytes: [UInt8] = Array("\u{3000} \t\n\u{00A0}\u{2028}".utf8) // 全為空白／斷行字元
    try Data(newBytes).write(to: newURL)
    try Data(oldBytes).write(to: oldURL)

    let migrated = LXMgr.migrateUserDataFrom(oldPath: oldDir.path, to: newDir.path)
    #expect(migrated == 0)
    let merged = try Data(contentsOf: newURL)
    #expect(Array(merged) == newBytes) // 舊檔未合併，新檔原樣。
  }

  // MARK: Private

  private static func makeDirs() throws -> (old: URL, new: URL) {
    let oldDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_migrate_old_\(UUID().uuidString)")
    let newDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_migrate_new_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
    return (oldDir, newDir)
  }

  private func entryDocumentData(_ entries: [LXAssembly.PersonalLexiconEntry]) throws -> Data {
    try LXAssembly.PersonalLexiconStore(entries: entries).encode()
  }
}
