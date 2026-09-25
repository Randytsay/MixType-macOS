// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

#if compiler(>=6.2)

  import AppKit
  import SwiftUI
  import UniformTypeIdentifiers

  // MARK: - VwrMixTypeBaseProviderPicker

  @available(macOS 14, *)
  struct VwrMixTypeBaseProviderPicker: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Picker("i18n:MixType.BaseInput.label".i18n, selection: $selection) {
          Text("i18n:MixType.BaseInput.zhuyin".i18n).tag(Shared.MixTypeBaseInputProvider.zhuyin)
          Text("i18n:MixType.BaseInput.pinyin".i18n).tag(Shared.MixTypeBaseInputProvider.pinyin)
          Text("i18n:MixType.BaseInput.cin".i18n).tag(Shared.MixTypeBaseInputProvider.cin)
        }
        .pickerStyle(.segmented)
        .onChange(of: selection) { oldValue, newValue in
          guard !isApplyingSelection, oldValue != newValue else { return }
          apply(newValue, fallback: oldValue)
        }

        switch selection {
        case .zhuyin:
          Text("i18n:MixType.BaseInput.zhuyin.description".i18n)
            .settingsDescription()
        case .pinyin:
          Text("i18n:MixType.BaseInput.pinyin.description".i18n)
            .settingsDescription()
        case .cin:
          Text("i18n:MixType.BaseInput.cin.description".i18n)
            .settingsDescription()
        }
      }
      .onAppear {
        selection = PrefMgr.shared.mixTypeBaseInputProvider
      }
      .alert("i18n:MixType.BaseInput.cinUnavailable.title".i18n, isPresented: $isShowingCassetteAlert) {
        Button("i18n:Common.OK".i18n, role: .cancel) {}
      } message: {
        Text("i18n:MixType.BaseInput.cinUnavailable.message".i18n)
      }
    }

    @State private var selection = Shared.MixTypeBaseInputProvider.zhuyin
    @State private var isApplyingSelection = false
    @State private var isShowingCassetteAlert = false

    private func apply(
      _ provider: Shared.MixTypeBaseInputProvider,
      fallback: Shared.MixTypeBaseInputProvider
    ) {
      isApplyingSelection = true
      defer { isApplyingSelection = false }

      switch provider {
      case .zhuyin:
        PrefMgr.shared.cassetteEnabled = false
        PrefMgr.shared.keyboardParser = 0
      case .pinyin:
        PrefMgr.shared.cassetteEnabled = false
        PrefMgr.shared.keyboardParser = 100
      case .cin:
        guard !SettingsUIHost.shared.cassettePath().isEmpty else {
          selection = fallback
          isShowingCassetteAlert = true
          return
        }
        PrefMgr.shared.cassetteEnabled = true
        PrefMgr.shared.hybridCassettePinyinEnabled = true
        PrefMgr.shared.keyboardParser = 100
        SettingsUIHost.shared.loadCassetteData()
      }
      SettingsUIHost.shared.syncLMPrefs()
      selection = PrefMgr.shared.mixTypeBaseInputProvider
    }
  }

  // MARK: - VwrPersonalLexiconManager

  @available(macOS 14, *)
  struct VwrPersonalLexiconManager: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Picker("i18n:MixType.PersonalLexicon.title".i18n, selection: $mode) {
            Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
            Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 260)

          Spacer()

          TextField("i18n:MixType.PersonalLexicon.search".i18n, text: $searchText)
            .textFieldStyle(.roundedBorder)
            .frame(width: 240)
        }

        Table(filteredEntries, selection: $selectedID) {
          TableColumn("i18n:MixType.PersonalLexicon.phrase".i18n) { entry in
            HStack(spacing: 6) {
              if entry.pinned {
                Image(systemName: "pin.fill")
                  .foregroundStyle(.secondary)
              }
              Text(entry.phrase)
                .foregroundStyle(entry.disabled ? .secondary : .primary)
            }
          }
          TableColumn("i18n:MixType.PersonalLexicon.initials".i18n) { entry in
            Text(entry.initialsKey)
              .font(.system(.body, design: .monospaced))
          }
          TableColumn("i18n:MixType.PersonalLexicon.fullPinyin".i18n) { entry in
            Text(entry.pinyinTokens.joined(separator: " "))
              .font(.system(.caption, design: .monospaced))
              .lineLimit(1)
          }
          TableColumn("i18n:MixType.PersonalLexicon.source".i18n) { entry in
            Text(
              entry.source == .manual
                ? "i18n:MixType.PersonalLexicon.source.manual".i18n
                : "i18n:MixType.PersonalLexicon.source.learned".i18n
            )
              .foregroundStyle(.secondary)
          }
          TableColumn("i18n:MixType.PersonalLexicon.usage".i18n) { entry in
            Text("\(entry.selectionCount)")
              .monospacedDigit()
          }
        }
        .frame(minHeight: 230, idealHeight: 260, maxHeight: 300)

        HStack(spacing: 8) {
          Button {
            editor = .new
          } label: {
            Label("i18n:MixType.PersonalLexicon.add".i18n, systemImage: "plus")
          }

          Button {
            guard let selectedEntry else { return }
            editor = .edit(selectedEntry)
          } label: {
            Label("i18n:MixType.PersonalLexicon.edit".i18n, systemImage: "pencil")
          }
          .disabled(selectedEntry == nil)

          Button {
            toggleDisabled()
          } label: {
            Label(
              selectedEntry?.disabled == true
                ? "i18n:MixType.PersonalLexicon.enable".i18n
                : "i18n:MixType.PersonalLexicon.disable".i18n,
              systemImage: "pause.circle"
            )
          }
          .disabled(selectedEntry == nil)

          Button(role: .destructive) {
            isShowingDeleteConfirmation = true
          } label: {
            Label("i18n:MixType.PersonalLexicon.delete".i18n, systemImage: "trash")
          }
          .disabled(selectedEntry == nil)

          Spacer()

          Button("i18n:MixType.PersonalLexicon.import".i18n) {
            isShowingImporter = true
          }
          Button("i18n:MixType.PersonalLexicon.export".i18n) {
            exportCurrentLexicon()
          }
          .disabled(entries.isEmpty)
        }

        Text("i18n:MixType.PersonalLexicon.help".i18n)
          .settingsDescription()
      }
      .onAppear(perform: reload)
      .onChange(of: mode) { _, _ in
        selectedID = nil
        reload()
      }
      .sheet(item: $editor) { context in
        PersonalLexiconEditor(
          context: context,
          mode: mode,
          onSaved: {
            editor = nil
            reload()
          },
          onError: presentError
        )
      }
      .fileImporter(
        isPresented: $isShowingImporter,
        allowedContentTypes: [.json],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case let .success(urls):
          guard let url = urls.first else { return }
          do {
            let count = try SettingsUIHost.shared.importPersonalLexicon(url, mode, false)
            reload()
            alertTitle = "i18n:MixType.PersonalLexicon.importDone".i18n
            alertMessage = String(
              format: "i18n:MixType.PersonalLexicon.importCount:%d".i18n,
              count
            )
            isShowingAlert = true
          } catch {
            presentError(error)
          }
        case let .failure(error):
          presentError(error)
        }
      }
      .alert(alertTitle, isPresented: $isShowingAlert) {
        Button("i18n:Common.OK".i18n, role: .cancel) {}
      } message: {
        Text(alertMessage)
      }
      .confirmationDialog(
        String(
          format: "i18n:MixType.PersonalLexicon.deleteConfirm:%@".i18n,
          selectedEntry?.phrase ?? ""
        ),
        isPresented: $isShowingDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("i18n:MixType.PersonalLexicon.delete".i18n, role: .destructive) { removeSelected() }
        Button("i18n:Common.Cancel".i18n, role: .cancel) {}
      }
    }

    @State private var mode: Shared.InputMode = .imeModeCHT
    @State private var entries: [LXAssembly.PersonalLexiconEntry] = []
    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var editor: EditorContext?
    @State private var isShowingImporter = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var selectedEntry: LXAssembly.PersonalLexiconEntry? {
      guard let selectedID else { return nil }
      return entries.first { $0.id == selectedID }
    }

    private var filteredEntries: [LXAssembly.PersonalLexiconEntry] {
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard !query.isEmpty else { return entries }
      return entries.filter { entry in
        entry.phrase.localizedCaseInsensitiveContains(query)
          || entry.fullPinyinKey.lowercased().contains(query)
          || entry.initialsKey.lowercased().contains(query)
          || entry.pinyinTokens.joined(separator: " ").lowercased().contains(query)
      }
    }

    private func reload() {
      entries = SettingsUIHost.shared.personalLexiconEntries(mode)
        .sorted { lhs, rhs in
          if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
          if lhs.selectionCount != rhs.selectionCount { return lhs.selectionCount > rhs.selectionCount }
          let lhsLast = lhs.lastUsedAt ?? .distantPast
          let rhsLast = rhs.lastUsedAt ?? .distantPast
          if lhsLast != rhsLast { return lhsLast > rhsLast }
          return lhs.phrase.localizedStandardCompare(rhs.phrase) == .orderedAscending
        }
      if let selectedID, !entries.contains(where: { $0.id == selectedID }) {
        self.selectedID = nil
      }
    }

    private func toggleDisabled() {
      guard let entry = selectedEntry else { return }
      do {
        _ = try SettingsUIHost.shared.updatePersonalLexiconEntry(
          entry.id,
          entry.phrase,
          entry.readings,
          entry.pinned,
          !entry.disabled,
          mode
        )
        reload()
      } catch {
        presentError(error)
      }
    }

    private func removeSelected() {
      guard let entry = selectedEntry else { return }
      do {
        _ = try SettingsUIHost.shared.removePersonalLexiconEntry(entry.id, mode)
        selectedID = nil
        reload()
      } catch {
        presentError(error)
      }
    }

    private func exportCurrentLexicon() {
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = mode == .imeModeCHT
        ? "personal-lexicon-cht.json"
        : "personal-lexicon-chs.json"
      guard panel.runModal() == .OK, let url = panel.url else { return }
      do {
        try SettingsUIHost.shared.exportPersonalLexicon(url, mode)
      } catch {
        presentError(error)
      }
    }

    private func presentError(_ error: Error) {
      alertTitle = "i18n:MixType.PersonalLexicon.operationFailed".i18n
      alertMessage = error.localizedDescription
      isShowingAlert = true
    }
  }

  // MARK: - EditorContext

  @available(macOS 14, *)
  private enum EditorContext: Identifiable {
    case new
    case edit(LXAssembly.PersonalLexiconEntry)

    var id: String {
      switch self {
      case .new: return "new"
      case let .edit(entry): return entry.id.uuidString
      }
    }
  }

  // MARK: - PersonalLexiconEditor

  @available(macOS 14, *)
  private struct PersonalLexiconEditor: View {
    init(
      context: EditorContext,
      mode: Shared.InputMode,
      onSaved: @escaping () -> Void,
      onError: @escaping (Error) -> Void
    ) {
      self.context = context
      self.mode = mode
      self.onSaved = onSaved
      self.onError = onError
      switch context {
      case .new:
        _phrase = State(initialValue: "")
        _readingsText = State(initialValue: "")
        _pinned = State(initialValue: true)
        _disabled = State(initialValue: false)
      case let .edit(entry):
        _phrase = State(initialValue: entry.phrase)
        _readingsText = State(initialValue: entry.readings.joined(separator: " "))
        _pinned = State(initialValue: entry.pinned)
        _disabled = State(initialValue: entry.disabled)
      }
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text(
          isEditing
            ? "i18n:MixType.PersonalLexicon.editor.editTitle".i18n
            : "i18n:MixType.PersonalLexicon.editor.addTitle".i18n
        )
          .font(.title2.bold())

        Form {
          TextField("i18n:MixType.PersonalLexicon.phrase".i18n, text: $phrase)

          if isEditing {
            TextField("i18n:MixType.PersonalLexicon.readingsFlexible".i18n, text: $readingsText)
            if let generatedKeys {
              LabeledContent(
                "i18n:MixType.PersonalLexicon.fullPinyin".i18n,
                value: generatedKeys.pinyinTokens.joined(separator: " ")
              )
              LabeledContent("i18n:MixType.PersonalLexicon.initials".i18n, value: generatedKeys.initialsKey)
            } else {
              Text("i18n:MixType.PersonalLexicon.invalidReading".i18n)
                .foregroundStyle(.red)
            }
            Toggle("i18n:MixType.PersonalLexicon.pinned".i18n, isOn: $pinned)
            Toggle("i18n:MixType.PersonalLexicon.disabled".i18n, isOn: $disabled)
          } else {
            Toggle("i18n:MixType.PersonalLexicon.pinned".i18n, isOn: $pinned)
            Text("i18n:MixType.PersonalLexicon.autoDerive".i18n)
              .settingsDescription()
          }
        }

        HStack {
          Spacer()
          Button("i18n:Common.Cancel".i18n) { dismiss() }
          Button("i18n:MixType.PersonalLexicon.save".i18n) { save() }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
      }
      .padding(20)
      .frame(width: 520)
    }

    @Environment(\.dismiss) private var dismiss
    let context: EditorContext
    let mode: Shared.InputMode
    let onSaved: () -> Void
    let onError: (Error) -> Void

    @State private var phrase: String
    @State private var readingsText: String
    @State private var pinned: Bool
    @State private var disabled: Bool

    private var isEditing: Bool {
      if case .edit = context { return true }
      return false
    }

    private var readings: [String] {
      LXAssembly.PersonalLexiconReadingParser.parse(readingsText) ?? []
    }

    private var generatedKeys: LXAssembly.PersonalLexiconKeyGenerator.Keys? {
      guard isEditing else { return nil }
      return LXAssembly.PersonalLexiconKeyGenerator.generate(readings: readings)
    }

    private var canSave: Bool {
      guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
      return !isEditing || generatedKeys != nil
    }

    private func save() {
      do {
        switch context {
        case .new:
          _ = try SettingsUIHost.shared.addPersonalLexiconPhrase(phrase, mode, pinned)
        case let .edit(entry):
          _ = try SettingsUIHost.shared.updatePersonalLexiconEntry(
            entry.id,
            phrase,
            readings,
            pinned,
            disabled,
            mode
          )
        }
        dismiss()
        onSaved()
      } catch {
        onError(error)
      }
    }
  }

#endif
