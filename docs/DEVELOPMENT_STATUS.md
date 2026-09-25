# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.2 — Personal Lexicon + ASCII fallback**

Specifications:

- `docs/MIXTYPE_V0.1_HYBRID_PLAN.md` — V0.1 accepted baseline
- `docs/MIXTYPE_V0.2_PERSONAL_LEXICON_PLAN.md` — active milestone

## Current phase

**V0.2 first vertical slice — core/persistence/Hybrid lookup implemented**

The clean Mac baseline and V0.1 installed-IME runtime acceptance have passed, including real
Cassette/CIN input, full Pinyin, abbreviated Pinyin, numeric candidate selection, and ordinary digits.
V0.2 now has a local Personal Lexicon model, full-Pinyin/initials Hybrid integration, deterministic
local reading/key generation, atomic macOS persistence, and zero-candidate ASCII fallback.

## Repository state

- Fork created: ✅
- MixType README/project positioning: ✅
- V0.1 Hybrid technical plan: ✅
- Development workflow / multi-agent rules: ✅
- WebCodex VPS managed project registered and synced to `origin/main`: ✅
- macOS local clone under CoS Mac: ✅ (`~/Coding/MixType-macOS`)
- clean upstream-derived Mac build baseline: ✅
- real IME installation baseline: ✅; Debug vChewing installs alongside OpenVanilla without overwrite
- real CIN/Boshiamy cassette baseline: ✅; a local private CIN was loaded and real cassette composition/commit was verified
- V0.1 feature branch: ✅ (`feat/hybrid-input-v01`)
- Hybrid Phase A implementation: ✅; dedicated routing seam implemented and validated on the Mac
- Hybrid Phase B implementation: ✅; CIN exact/quick + full-Pinyin + abbreviated-Pinyin providers, source ordering, and deduplication
- Hybrid Phase C implementation: ✅; CIN preserves cassette commit semantics, Pinyin/abbreviation selections write real readings into Homa
- Hybrid Phase D Settings UI: ✅; SwiftUI/AppKit cassette panes expose the Hybrid toggle and enable the existing Pinyin parser when Hybrid is turned on
- V0.1 Phase A read-only implementation audit: ✅ (`docs/MIXTYPE_V0.1_PHASE_A_AUDIT.md`)
- V0.2 Personal Lexicon + Auto Promotion specification: ✅ (`docs/MIXTYPE_V0.2_PERSONAL_LEXICON_PLAN.md`)
- V0.2 feature branch: ✅ (`feat/personal-lexicon-v02`)
- Personal Lexicon versioned local model + JSON round-trip: ✅
- full-Pinyin / initials Hybrid candidate integration: ✅
- local factory reading resolution + Tekkon Pinyin-key generation: ✅
- atomic macOS persistence under the existing user-data directory: ✅
- zero-candidate ASCII fallback, including prior Chinese composition: ✅

## Mac baseline reconciliation — 2026-09-25

- Host: macOS 26.6.2 (25G83), Apple Silicon `arm64`, Apple M4 Pro.
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), satisfying the repository's Swift 6.4 minimum.
- Active developer directory: `/Applications/Xcode.app/Contents/Developer`.
- Full Xcode: Xcode 27.0, build `27A266a`; macOS 27 SDK is available. `xcodebuild -checkFirstLaunchStatus` passes.
- Fork reconciliation before Phase A: `origin/main` at `d606bc7499f05dc25e2e85e29a844f9af81d5d55`; upstream base remains `62936e41e9319dce482a291bf13b6bfaa194c6f7`.
- Local core build: `swift build -c debug --product Vanguard` from `Packages/vChewing_OSNeutral_LibVanguard` — **PASS**.
- Local LibVanguard tests: `make test` from `Packages/vChewing_OSNeutral_LibVanguard` — **PASS**.
- Local root SwiftPM debug build: `make spmDebug` — **PASS**.
- Local Debug app bundle assembly: `make debug` — **PASS** for both `vChewing.app` and `vChewingInstaller.app`; both pass strict codesign verification and Info.plist lint.
- Running `make test` at the repository root stops at `swift test --no-parallel` with `no tests found`; use the LibVanguard package test command above for the current package-test gate.
- Upstream CI for the shared code base `62936e41e9319dce482a291bf13b6bfaa194c6f7`: Linux LibVanguard, Windows LibVanguard, and macOS SPM tests/package workflows all completed successfully. This supports that the observed local failures are toolchain-environment failures rather than known source regressions.
- Debug `vChewing.app` was installed in the current user's Input Methods directory and passed strict codesign verification.
- OpenVanilla remained installed and operational; bundle names and identifiers are distinct and no OpenVanilla files were deleted or overwritten.
- A local private CIN was copied only into vChewing's sandbox cassette cache; the private CIN contents and paths are not committed to Git.
- Real cassette input was verified on macOS: a known private-CIN code produced the expected Chinese character in the composition buffer and Enter committed it. The composition-first behavior is the clean upstream baseline, not a Hybrid regression.

## Planning completed before implementation

- Phase A exact preference/routing/typewriter/test touchpoints were audited before implementation.
- The Mac baseline gate passed before the feature branch was created.
- Phase A adds a default-off Hybrid preference, semantic `hybridCassettePinyin` mode, and a dedicated single-event typewriter route. The Phase A typewriter deliberately delegates to cassette behavior only; it does not invoke cassette and Pinyin typewriters sequentially.
- Focused Phase A tests cover the mode matrix and a cassette-compatible single-route sentinel.
- Phase B replaces the temporary cassette delegation with one Hybrid-owned raw-key buffer and read-only candidate providers. The coordinator never sequentially invokes the cassette and BPMF typewriters on the same event.
- Phase B candidate order is deterministic: CIN exact → CIN quick → full Pinyin → abbreviated Pinyin; duplicate output values keep the earliest source, preserving CIN priority.
- Phase C applies Pinyin and abbreviation selections to Homa using each candidate's real Zhuyin `keyArray`; CIN selections retain the existing cassette direct-commit behavior.
- Hybrid raw input displays the literal typed keys rather than translated cassette radicals, so Pinyin input remains readable while composing.
- V0.2 Personal Lexicon architecture, reading resolution, auto-promotion policy, persistence, ranking and acceptance tests are now specified.

## Required next steps

1. Install the V0.2 feature build and seed one local, uncommitted `台達能源` entry for E2E validation.
2. Verify `taidanengyuan → 台達能源`, `tdny → 台達能源`, and zero-candidate ASCII fallback on macOS.
3. Add Settings UI CRUD/edit-pronunciation support, then automatic promotion/learning.

## V0.2 implementation status

- [x] versioned Personal Lexicon entry/document/store
- [x] full-Pinyin and initials indexes
- [x] Hybrid ordering: CIN exact remains first; Personal full/initials participate deterministically
- [x] Personal entries feed Homa instead of bypassing composition semantics
- [x] local reading resolution via one low-frequency exact-value TextMap scan + longest-segment DP
- [x] Tekkon-derived normalized full Pinyin / initials
- [x] JSON load/save with future-schema fail-closed behavior
- [x] macOS atomic persistence (`personal-lexicon-cht.json` / `personal-lexicon-chs.json`)
- [x] manual host API taking only a Chinese phrase
- [x] no-candidate Space/Enter ASCII fallback without buzzer
- [x] Chinese composition + unknown ASCII fallback regression
- [ ] installed-Mac E2E for `台達能源`
- [ ] Settings UI add/edit/remove/search
- [ ] pronunciation correction UI for ambiguous readings
- [ ] auto-promotion after explicit selections
- [ ] broader English-intent reuse from MixedAlphanumerical heuristics

## V0.1 phase checklist

### Phase A — Hybrid mode plumbing

- [x] add Hybrid preference (default off)
- [x] add `hybridCassettePinyin` typing mode with fail-closed activation
- [x] add dedicated hybrid dispatch path
- [x] add focused regression coverage for Hybrid-off mode selection and the single Hybrid route

### Phase B — candidate providers and merge

- [x] CIN candidate provider
- [x] full-Pinyin candidate provider
- [x] abbreviated-Pinyin candidate provider
- [x] deterministic source ordering
- [x] candidate deduplication
- [x] CIN exact candidate remains first by default

### Phase C — selection semantics

- [x] CIN selection preserves cassette semantics
- [x] Pinyin selection uses Homa insertion/override semantics
- [x] abbreviation selection uses the same stable insertion path
- [x] regression tests

### Phase D — Settings UI

- [x] Hybrid enable/disable switch
- [x] clear explanation that CIN exact remains preferred
- [x] localization updates

### Phase E — validation

- [x] package/unit tests pass
- [ ] GitHub CI passes
- [x] macOS build succeeds
- [x] IME installs successfully
- [x] real Boshiamy CIN loads
- [x] real candidate ordering verified
- [x] real typing tested in representative macOS applications

## Current blockers

The Mac baseline blocker is resolved. Phase A commit `125bea1161b9f76d1b4be798adad9e93776c9531` passed its focused Hybrid tests on Xcode 27 / Swift 6.4. Phase B/C commit `d250f29fee919ce69fd0f51688bd4c8ab1f74075` implements candidate fusion and selection semantics. Phase D Settings UI changes pass all 17 SettingsUI tests and all four localization plist lints.

Commit `3845737c` fixes the first real full-Pinyin runtime blocker found during Phase E: normal `LXQuerier.grams(for:)` intentionally suppresses the factory phonetic lexicon while Cassette is enabled, so Hybrid could parse Pinyin but still return no factory Pinyin candidate. Hybrid now uses a read-only factory-phonetic query that bypasses only the Cassette source gate, then merges factory results with the existing user/temporary lexicon results without mutating `Config.isCassetteEnabled`.

Commit `54eca706` fixes the next real-runtime issues reported from the installed Hybrid build: numeric labels in the inline candidate window can now be selected by their plain main-keyboard digit (for example, UI label `5` selects that candidate), and a leading plain digit passes through to the client when the loaded CIN has no code beginning with that digit. The latter is prefix-aware, so CIN tables that genuinely contain digit-leading codes retain that behavior.

Draft PR #3 exists to provide a review surface. No GitHub Actions run was observed for the feature branch, so Mac validation is the current authoritative compile/test evidence.

Commit `5d08a081` fixes a production-only Hybrid selection failure where the candidate UI state and a second candidate-source lookup could carry the same displayed value with a different internal `keyArray`. Because Hybrid candidates are already deduplicated by displayed value, selection now resolves the current canonical offer by displayed value and uses that canonical candidate for the final Pinyin/CIN action. A dedicated regression test covers stale/different internal key arrays for the same displayed candidate.

Runtime file tracing on the installed build then isolated the remaining `cai → 5 → 蔡` buzzer precisely: numeric routing was correct (`5 → candidateIndex 5 → 蔡`), source resolution was correct (`蔡 / ㄘㄞˋ / pinyinFull`), but `confirmHybridPinyinCandidate()` failed when Homa attempted to insert the selected factory reading. The cause was a second Cassette source gate inside Homa's normal `gramQuerier` / `gramAvailabilityChecker`: Hybrid could *display* factory phonetic candidates but the assembler still considered those readings unavailable while Cassette was enabled.

Commit `90972db0` fixes that root cause. Homa's LM hooks are now configured through one shared `InputHandlerProtocol.configureAssemblerGramAccess()` path used by both production and tests. Only while `.hybridCassettePinyin` is active, Homa uses phonetic-aware gram and availability queries that combine factory phonetic data with the existing user/temporary data without mutating the global Cassette setting. Hybrid OFF retains the original query path. Regression `IH100` reproduces the failure using only the test factory lexicon (`nengliu → 能留`) with Cassette enabled; it failed before the fix and passes after it. Focused Hybrid tests are now **11/11 PASS**; the full LibVanguard package suite is **PASS** with **247 InputHandler tests**; `make debug` is **PASS** on Xcode 27 / Swift 6.4.

The feature build containing `90972db0` is installed in the current user's Input Methods directory.
The previous IME was backed up under the ignored `Build/Backups/` directory before replacement.
Codesign verification passes, OpenVanilla remains installed with its distinct bundle identifier,
and the persisted runtime preferences report Cassette + Hybrid + Pinyin enabled. The private cassette
baseline is already verified. Full-Pinyin lookup is visible in the real candidate window; the remaining
real runtime now confirms `cai` candidate label `5` selects `蔡` without buzzer, ordinary digit
passthrough remains working, and `nihao → 你好` full-Pinyin phrase lookup/selection works in the
installed IME. Real `nl` input also produces abbreviated-Pinyin multiword candidates and numeric
selection successfully chooses `能力`, completing the V0.1 abbreviation runtime gate.

Regression `IH101` adds a factory-only abbreviation path check: with Cassette + Hybrid enabled,
`nl` resolves the test factory phrase `能留`, selection enters Homa with readings `ㄋㄥˊ / ㄌㄧㄡˊ`,
and no temporary user gram is required. The same phrase is present in the bundled production factory
dictionary, making `nl → 能留` the canonical final real-runtime abbreviation check. Focused Hybrid
tests are now **12/12 PASS** and the full LibVanguard package suite is **PASS** with **248 InputHandler tests**.

Regression `IH102` verifies that every key of the long raw sequence `taidanengyuan` is accepted by
Hybrid and retained in the raw buffer. The production factory dictionary contains `台達` and `台達電`
but not `台達能源`; therefore the observed buzzer on finalization is a no-candidate UX gap rather than
a long-Pinyin input-length failure. That fallback and the missing custom phrase belong to V0.2.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch: feat/hybrid-input-v01
Latest commit: 90972db0
Completed: Mac baseline; IME/OpenVanilla coexistence; private-CIN cassette runtime check; Phase A routing; Phase B candidate fusion; Phase C selection semantics; Phase D Settings UI/localization; Phase E factory-Pinyin source-gate fix; Hybrid numeric-selection and digit-passthrough fix; stable Hybrid candidate-source resolution; Hybrid Homa phonetic assembly path
Tests: Hybrid filter 12/12 PASS; full LibVanguard package tests PASS (248 InputHandler tests); SettingsUI 17 tests PASS; localization lint PASS; `make debug` PASS on Xcode 27 / Swift 6.4
CI: Draft PR #3 exists; no GitHub Actions run observed for the feature commit
Mac runtime validation: clean baseline PASS; private CIN PASS; `cai → displayed 5 → 蔡` PASS; ordinary standalone digits PASS; `nihao → 你好` PASS; `nl` abbreviated-Pinyin candidates + numeric selection PASS; Cassette + Hybrid + Pinyin prefs enabled
Known issues: GitHub Actions has not run for the feature branch; V0.1 runtime acceptance itself is complete
Next unfinished item: branch V0.2 and implement no-candidate ASCII fallback plus Personal Lexicon lookup/persistence
```
