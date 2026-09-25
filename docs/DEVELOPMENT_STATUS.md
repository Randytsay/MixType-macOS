# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.1 — Hybrid CIN + Pinyin**

Specification:

`docs/MIXTYPE_V0.1_HYBRID_PLAN.md`

## Current phase

**Pre-development Mac baseline — build and package tests pass; install/CIN verification pending**

No MixType hybrid engine implementation has started yet.

## Repository state

- Fork created: ✅
- MixType README/project positioning: ✅
- V0.1 Hybrid technical plan: ✅
- Development workflow / multi-agent rules: ✅
- WebCodex VPS managed project registered and synced to `origin/main`: ✅
- macOS local clone under CoS Mac: ✅ (`~/Coding/MixType-macOS`)
- clean upstream-derived Mac build baseline: ⚠️ partial; full Xcode 27 is installed, LibVanguard package tests pass, and both Debug app bundles build and validate; real IME installation and CIN typing remain unverified
- real IME installation baseline: ⬜
- real CIN/Boshiamy cassette baseline: ⬜
- V0.1 feature branch: ⬜
- Hybrid implementation: ⬜
- V0.1 Phase A read-only implementation audit: ✅ (`docs/MIXTYPE_V0.1_PHASE_A_AUDIT.md`)
- V0.2 Personal Lexicon + Auto Promotion specification: ✅ (`docs/MIXTYPE_V0.2_PERSONAL_LEXICON_PLAN.md`)

## Mac baseline reconciliation — 2026-09-25

- Host: macOS 26.6.2 (25G83), Apple Silicon `arm64`, Apple M4 Pro.
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), satisfying the repository's Swift 6.4 minimum.
- Active developer directory: `/Applications/Xcode.app/Contents/Developer`.
- Full Xcode: Xcode 27.0, build `27A266a`; macOS 27 SDK is available. `xcodebuild -checkFirstLaunchStatus` passes.
- Fork reconciliation: local `main` and `origin/main` both at `3164ca66273f30fbbe8b8e82dd9961b65a35a80d`; upstream base remains `62936e41e9319dce482a291bf13b6bfaa194c6f7`.
- Local core build: `swift build -c debug --product Vanguard` from `Packages/vChewing_OSNeutral_LibVanguard` — **PASS**.
- Local LibVanguard tests: `make test` from `Packages/vChewing_OSNeutral_LibVanguard` — **PASS**.
- Local root SwiftPM debug build: `make spmDebug` — **PASS**.
- Local Debug app bundle assembly: `make debug` — **PASS** for both `vChewing.app` and `vChewingInstaller.app`; both pass strict codesign verification and Info.plist lint.
- Running `make test` at the repository root stops at `swift test --no-parallel` with `no tests found`; use the LibVanguard package test command above for the current package-test gate.
- Upstream CI for the shared code base `62936e41e9319dce482a291bf13b6bfaa194c6f7`: Linux LibVanguard, Windows LibVanguard, and macOS SPM tests/package workflows all completed successfully. This supports that the observed local failures are toolchain-environment failures rather than known source regressions.
- No IME installation, OpenVanilla coexistence, private CIN loading, or real cassette typing test has been performed yet.

## Planning completed before implementation

- Phase A exact preference/routing/typewriter/test touchpoints have been audited read-only.
- Phase A is intentionally not implemented until the IME installation, coexistence, and CIN typing baseline gates pass.
- V0.2 Personal Lexicon architecture, reading resolution, auto-promotion policy, persistence, ranking and acceptance tests are now specified.

## Required next steps

1. Install the baseline IME and verify that it coexists with OpenVanilla without deleting or overwriting OpenVanilla.
2. Verify baseline cassette/CIN behavior with a local private CIN file without committing that file.
3. Only after those gates pass, create and switch to:
   `feat/hybrid-input-v01`.
4. Begin V0.1 Phase A.

## V0.1 phase checklist

### Phase A — Hybrid mode plumbing

- [ ] add Hybrid preference
- [ ] add `hybridCassettePinyin` typing mode
- [ ] add dedicated hybrid dispatch path
- [ ] add regression coverage proving Hybrid-off preserves upstream cassette behavior

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

The build/test environment blocker is resolved with full Xcode 27. Per the baseline gate, Phase A must wait until the IME is installed and verified alongside OpenVanilla, and cassette/CIN typing has been tested with a private local CIN file.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Canonical branch: main
Baseline evidence commit: 6755ccec644ac46ca566aeb71ab4a10675999055
Baseline status merged by PR #1
Completed: local clone; origin/upstream reconciliation; host/toolchain audit; local Vanguard product build
Tests: `make test` blocked before execution by missing FoundationMacros in Command Line Tools; `swift build -c debug --product Vanguard` PASS
CI: no fork run observed for the docs-only fork commits; upstream shared base 62936e41 has passing Linux, Windows, and macOS workflows
Mac runtime validation: not started; full IME build/install/CIN validation blocked until full Xcode 27 is available
Known issues: active developer directory is Command Line Tools only; missing FoundationMacros and PreviewsMacros
Next unfinished item: install/select full Xcode 27, rerun baseline, then create feat/hybrid-input-v01 and start Phase A
```
