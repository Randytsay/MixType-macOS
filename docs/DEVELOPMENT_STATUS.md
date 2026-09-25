# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.1 — Hybrid CIN + Pinyin**

Specification:

`docs/MIXTYPE_V0.1_HYBRID_PLAN.md`

## Current phase

**V0.1 Phase A — Hybrid mode plumbing implemented; validation in progress**

The clean Mac baseline has passed, including real IME installation and cassette/CIN input.
Phase A establishes the Hybrid routing seam only; real CIN + Pinyin candidate fusion remains Phase B.

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
- Hybrid Phase A implementation: ✅; dedicated routing seam implemented, candidate fusion intentionally not started in this batch
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
- V0.2 Personal Lexicon architecture, reading resolution, auto-promotion policy, persistence, ranking and acceptance tests are now specified.

## Required next steps

1. Validate the Phase A feature commit in GitHub CI and on the Mac once the CoS Mac tunnel is available again.
2. Begin Phase B on `feat/hybrid-input-v01`: add non-mutating CIN/full-Pinyin/abbreviated-Pinyin candidate providers and deterministic merge/deduplication.
3. Preserve the invariant that one physical key event has one Hybrid coordinator owner; never invoke the cassette and BPMF typewriters sequentially against shared state.
4. Keep Personal Lexicon, mixed English detection, and Settings UI work out of Phase B.

## V0.1 phase checklist

### Phase A — Hybrid mode plumbing

- [x] add Hybrid preference (default off)
- [x] add `hybridCassettePinyin` typing mode with fail-closed activation
- [x] add dedicated hybrid dispatch path
- [x] add focused regression coverage for Hybrid-off mode selection and the single Hybrid route

### Phase B — candidate providers and merge

- [ ] CIN candidate provider
- [ ] full-Pinyin candidate provider
- [ ] abbreviated-Pinyin candidate provider
- [ ] deterministic source ordering
- [ ] candidate deduplication
- [ ] CIN exact candidate remains first by default

### Phase C — selection semantics

- [ ] CIN selection preserves cassette semantics
- [ ] Pinyin selection uses Homa insertion/override semantics
- [ ] abbreviation selection uses the same stable insertion path
- [ ] regression tests

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

The Mac baseline blocker is resolved. The WebCodex VPS does not currently have a Swift executable, so it cannot compile or run LibVanguard tests locally; the attempted focused test command fails at environment lookup with `swift: not found`. GitHub CI and CoS Mac are therefore the authoritative compile/test gates for the Phase A feature commit.

The CoS Mac connector tunnel is temporarily unavailable after the input-source login/refresh sequence. This does not invalidate the already completed clean-baseline evidence, but feature-branch macOS runtime validation must wait for that connector to reconnect.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch: feat/hybrid-input-v01
Latest commit: pending Phase A commit
Completed: Mac baseline; IME/OpenVanilla coexistence; private-CIN cassette runtime check; Phase A preference/mode/dedicated route/test implementation
Tests: pre-feature Mac LibVanguard make test PASS; pre-feature make debug PASS; WebCodex feature test attempt blocked because Swift is not installed on the VPS
CI: pending Phase A push
Mac runtime validation: clean baseline PASS; Phase A feature commit validation pending CoS Mac reconnect
Known issues: no Phase B candidate fusion yet, so Hybrid Phase A intentionally behaves as the cassette-compatible routing skeleton
Next unfinished item: validate Phase A commit, then implement Phase B actual CIN + Pinyin candidate providers and merge
```
