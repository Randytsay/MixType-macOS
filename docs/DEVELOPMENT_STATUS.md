# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.1 — Hybrid CIN + Pinyin**

Specification:

`docs/MIXTYPE_V0.1_HYBRID_PLAN.md`

## Current phase

**Pre-development baseline / environment setup**

No MixType hybrid engine implementation has started yet.

## Repository state

- Fork created: ✅
- MixType README/project positioning: ✅
- V0.1 Hybrid technical plan: ✅
- Development workflow / multi-agent rules: ✅
- WebCodex VPS managed project registered and synced to `origin/main`: ✅
- macOS local clone under CoS Mac: ⬜
- clean upstream-derived Mac build baseline: ⬜
- real IME installation baseline: ⬜
- real CIN/Boshiamy cassette baseline: ⬜
- V0.1 feature branch: ⬜
- Hybrid implementation: ⬜

## Required next steps

1. Clone `Randytsay/MixType-macOS` to the user's Mac, recommended at:
   `~/Coding/MixType-macOS`.
2. Let CoS Mac reconcile the repository and local toolchain.
3. Establish the baseline defined in `docs/DEVELOPMENT_WORKFLOW.md`.
4. Record the actual Mac build/install/CIN results in this file.
5. Create and switch to:
   `feat/hybrid-input-v01`.
6. Begin V0.1 Phase A only after baseline is trustworthy.

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

None recorded yet. The next dependency is the Mac baseline.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch:
Latest commit:
Completed:
Tests:
CI:
Mac runtime validation:
Known issues:
Next unfinished item:
```
