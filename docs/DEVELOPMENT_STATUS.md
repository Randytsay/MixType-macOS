# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.1 — Hybrid CIN + Pinyin**

Specification:

`docs/MIXTYPE_V0.1_HYBRID_PLAN.md`

## Current phase

**Pre-development baseline / environment setup — blocked on full Xcode 27**

No MixType hybrid engine implementation has started yet.

## Repository state

- Fork created: ✅
- MixType README/project positioning: ✅
- V0.1 Hybrid technical plan: ✅
- Development workflow / multi-agent rules: ✅
- WebCodex VPS managed project registered and synced to `origin/main`: ✅
- macOS local clone under CoS Mac: ✅ (`~/Coding/MixType-macOS`)
- clean upstream-derived Mac build baseline: ⚠️ partial; core `Vanguard` product builds locally, but the required full package tests and IME build are blocked because this Mac currently has Command Line Tools 27 only, not full Xcode 27
- real IME installation baseline: ⬜
- real CIN/Boshiamy cassette baseline: ⬜
- V0.1 feature branch: ⬜
- Hybrid implementation: ⬜

## Mac baseline reconciliation — 2026-09-25

- Host: macOS 26.6.2 (25G83), Apple Silicon `arm64`, Apple M4 Pro.
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), satisfying the repository's Swift 6.4 minimum.
- Active developer directory: `/Library/Developer/CommandLineTools`.
- Full Xcode: not found in `/Applications` or Spotlight; `xcodebuild -version` therefore cannot run.
- Fork reconciliation: `origin/main` at `9d04b724cb9e64b2a953012f5e54bd6cec3cbb37`; upstream base at `62936e41e9319dce482a291bf13b6bfaa194c6f7`. The fork is seven documentation commits ahead and zero commits behind upstream.
- Local core build: `swift build -c debug --product Vanguard` from `Packages/vChewing_OSNeutral_LibVanguard` — **PASS**.
- Local LibVanguard test command: `make test` — **BLOCKED by environment** before tests execute because Command Line Tools lacks `FoundationMacros.BundleMacro` required by `#bundle` in the test-material target.
- Local root SwiftPM debug build: `make spmDebug` — **BLOCKED by environment** because Command Line Tools lacks `PreviewsMacros` used by AppKit/SwiftUI preview macros.
- Local targeted IME product build: `swift build -c debug --product vChewing` — **BLOCKED by the same missing `PreviewsMacros` plugin**.
- Upstream CI for the shared code base `62936e41e9319dce482a291bf13b6bfaa194c6f7`: Linux LibVanguard, Windows LibVanguard, and macOS SPM tests/package workflows all completed successfully. This supports that the observed local failures are toolchain-environment failures rather than known source regressions.
- No IME installation, OpenVanilla coexistence, private CIN loading, or real cassette typing test was attempted because the build/test baseline gate has not passed locally.

## Required next steps

1. Install full Xcode 27 compatible with macOS 26.6.2, then select its developer directory with `xcode-select` and verify `xcodebuild -version`.
2. Re-run the baseline commands, including LibVanguard package tests and the repo-recommended debug app build, without changing deployment targets or bypassing macro failures.
3. Produce/install the baseline IME and verify that it coexists with OpenVanilla without deleting or overwriting OpenVanilla.
4. Verify baseline cassette/CIN behavior with a local private CIN file without committing that file.
5. Only after those gates pass, create and switch to:
   `feat/hybrid-input-v01`.
6. Begin V0.1 Phase A.

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

Full Xcode 27 is not currently installed/discoverable on the Mac. The installed Command Line Tools provide Swift 6.4 but omit Apple macro plugins needed by this repository's tests and macOS UI targets (`FoundationMacros` / `PreviewsMacros`). Per the baseline gate, Phase A must not begin until the required local Mac baseline is rerun successfully with full Xcode.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch: chore/mac-baseline-reconciliation
Latest commit: 6755ccec644ac46ca566aeb71ab4a10675999055 (Mac baseline reconciliation/status update)
Completed: local clone; origin/upstream reconciliation; host/toolchain audit; local Vanguard product build
Tests: `make test` blocked before execution by missing FoundationMacros in Command Line Tools; `swift build -c debug --product Vanguard` PASS
CI: no fork run observed for the docs-only fork commits; upstream shared base 62936e41 has passing Linux, Windows, and macOS workflows
Mac runtime validation: not started; full IME build/install/CIN validation blocked until full Xcode 27 is available
Known issues: active developer directory is Command Line Tools only; missing FoundationMacros and PreviewsMacros
Next unfinished item: install/select full Xcode 27, rerun baseline, then create feat/hybrid-input-v01 and start Phase A
```
