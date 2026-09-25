# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.1 — Hybrid CIN + Pinyin**

Specification:

`docs/MIXTYPE_V0.1_HYBRID_PLAN.md`

## Current phase

**V0.1 Phase D — Settings UI and macOS runtime validation**

The clean Mac baseline has passed, including real IME installation and cassette/CIN input.
Phase A routing and Phase B/C Hybrid candidate/selection semantics are implemented and pass Mac tests.

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
- V0.1 Phase A read-only implementation audit: ✅ (`docs/MIXTYPE_V0.1_PHASE_A_AUDIT.md`)
- V0.2 Personal Lexicon + Auto Promotion specification: ✅ (`docs/MIXTYPE_V0.2_PERSONAL_LEXICON_PLAN.md`)

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

1. Add the Phase D Settings UI switch and localization for the Hybrid preference.
2. Install the feature build on the Mac, enable Hybrid + Pinyin, and verify real factory-dictionary Pinyin alongside the private CIN.
3. Verify real candidate ordering and selection in representative macOS applications.
4. Keep Personal Lexicon and mixed English detection out of V0.1.

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

- [ ] Hybrid enable/disable switch
- [ ] clear explanation that CIN exact remains preferred
- [ ] localization updates

### Phase E — validation

- [ ] package/unit tests pass
- [ ] GitHub CI passes
- [ ] macOS build succeeds
- [ ] IME installs successfully
- [ ] real Boshiamy CIN loads
- [ ] real candidate ordering verified
- [ ] real typing tested in representative macOS applications

## Current blockers

The Mac baseline blocker is resolved. Phase A commit `125bea1161b9f76d1b4be798adad9e93776c9531` passed its focused Hybrid tests on Xcode 27 / Swift 6.4. The current Phase B/C work passes 5 focused Hybrid tests, the full LibVanguard package suite (including 241 InputHandler tests), and `make debug` on the Mac. The WebCodex VPS does not currently have a Swift executable, so it cannot compile or run these tests locally.

Draft PR #3 exists to provide a review surface. No GitHub Actions run was observed for the feature branch, so Mac validation is the current authoritative compile/test evidence.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch: feat/hybrid-input-v01
Latest commit: pending Phase B/C commit
Completed: Mac baseline; IME/OpenVanilla coexistence; private-CIN cassette runtime check; Phase A routing; Phase B candidate fusion; Phase C selection semantics
Tests: Hybrid filter 5/5 PASS; full LibVanguard package tests PASS (241 InputHandler tests); `make debug` PASS on Xcode 27 / Swift 6.4
CI: Draft PR #3 exists; no GitHub Actions run observed for the feature commit
Mac runtime validation: clean baseline PASS; Phase B/C compile/tests/build PASS; feature build installation and real Hybrid typing still pending
Known issues: Phase D Settings UI is not implemented yet; Hybrid can currently be enabled only through the persisted preference
Next unfinished item: commit/push Phase B/C, then add Phase D Settings UI and perform real Hybrid typing validation
```
