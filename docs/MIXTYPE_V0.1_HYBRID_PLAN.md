# MixType V0.1 — Hybrid CIN + Pinyin Plan

> **Historical specification.** V0.1 has been implemented and accepted. For current production/release status, see `docs/DEVELOPMENT_STATUS.md`.

## Goal

Deliver a minimal, testable hybrid typing mode for MixType:

- The same raw key stream is evaluated by both the configured CIN cassette (initial target: Boshiamy) and the existing Pinyin/Furious-Typing stack.
- Exact CIN matches stay first by default.
- Pinyin and abbreviated-Pinyin candidates can appear after CIN candidates without switching input modes.
- Existing vChewing cassette behavior must remain available when Hybrid mode is disabled.
- V0.1 must not depend on networking or an LLM.

## Non-goals for V0.1

The following are intentionally deferred:

- Persistent personal abbreviation learning such as teaching `cyw → 蔡耀文` permanently.
- Full mixed Chinese/English intent detection.
- Cross-device synchronization.
- Re-ranking based on a long-term personal vocabulary database.
- Replacing or rewriting Homa, Tekkon, or the cassette parser.

## Current upstream constraints

### 1. Cassette currently suppresses phonetic typing

`InputHandler_TypingMode.swift` gives cassette absolute priority:

```swift
if prefs.cassetteEnabled { return .cassette }
```

As a result, Pinyin/Furious Typing is never active while cassette mode is enabled.

### 2. Input dispatch is mutually exclusive

`InputHandler_HandleComposition.swift` dispatches exactly one typewriter:

- `.cassette` → `CassetteTypewriter`
- `.pinyinKeyblock` / `.pinyinFuriousTyping` → `BPMFFullMatchTypewriter`

MixType therefore needs an explicit hybrid path rather than trying to execute both existing typewriters sequentially.

### 3. The required Pinyin abbreviation machinery already exists

The current codebase already contains:

- `Tekkon.PinyinTrie`
- Pinyin chopping/deduction
- `furiousAbbreviatedCells(romaji:)`
- `LXQuerier.abbreviatedWordCandidates(keysChopped:)`
- Furious Typing candidate ranking
- Homa candidate insertion/override helpers
- POM short-term learning

V0.1 should reuse these components rather than reimplement Pinyin or abbreviation parsing.

## Proposed architecture

```text
Raw key event
    |
    v
HybridCassettePinyinTypewriter
    |
    +----> CIN probe --------------------+
    |       exact / quick / wildcard     |
    |                                    v
    +----> Pinyin probe ------------> HybridCandidateMerger
            full Pinyin                  |
            abbreviated Pinyin           v
                                     Candidate window
                                          |
                         +----------------+----------------+
                         |                                 |
                    CIN selected                      Pinyin selected
                         |                                 |
                  existing cassette                 Homa insert/override
                     behavior                          existing helpers
```

## New concepts

### Hybrid typing mode

Add a new semantic typing mode:

```swift
case hybridCassettePinyin
```

It becomes active only when:

- cassette is enabled;
- a new MixType Hybrid setting is enabled; and
- the selected phonetic parser is Pinyin-capable.

When Hybrid is off, original cassette behavior remains unchanged.

### Hybrid candidate offer

Do not overload `CandidateInState` with source metadata globally.

Introduce an internal MixType-only representation:

```swift
struct HybridCandidateOffer {
  enum Source {
    case cassetteExact
    case cassetteQuick
    case pinyinFull
    case pinyinAbbreviation
  }

  let candidate: CandidateInState
  let source: Source
  let score: Double
}
```

Convert back to `CandidateInState` only when publishing candidates to the existing state/candidate-window layer.

This keeps the candidate UI untouched in V0.1.

## Candidate ordering for V0.1

Default order:

1. CIN exact match
2. CIN quick candidates
3. Full Pinyin candidates
4. Abbreviated-Pinyin candidates

Within the same source group, preserve the existing engine's score/order.

Deduplicate by candidate value while preserving the first occurrence.

Important invariant:

> A valid exact Boshiamy/CIN candidate must not silently lose first position merely because Pinyin produces a high-frequency word.

This protects existing Boshiamy muscle memory.

## Selection behavior

### CIN candidate

Route through existing cassette behavior wherever possible.

### Pinyin / abbreviation candidate

Reuse existing Homa/Furious-Typing insertion and override semantics instead of committing raw text directly.

The selected candidate already carries a phonetic `keyArray`, allowing the hybrid layer to insert its readings into Homa and override the selected value consistently.

V0.1 should avoid direct-text commit except as a defensive fallback.

## Expected code changes

### Core routing

- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_TypingMode.swift`
  - add `.hybridCassettePinyin`
  - update mode selection precedence

- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_HandleComposition.swift`
  - route hybrid mode to a dedicated typewriter

### New Hybrid typewriter/provider

Suggested new files:

- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/Typewriter/Typewriter_HybridCassettePinyin.swift`
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_HybridCandidates.swift`

Responsibilities:

- maintain one raw-key buffer for the hybrid decision path;
- obtain CIN candidates without mutating Pinyin state;
- obtain full-Pinyin and abbreviation candidates using existing Tekkon/LX APIs;
- merge and rank offers;
- apply the selected offer using source-specific semantics.

### Preferences

- `Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/UserDef/UserDef.swift`
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/PrefMgr_Core.swift`
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/Protocols/PrefMgrProtocol.swift`

Add a disabled-by-default preference such as:

```text
HybridCassettePinyinEnabled
```

### Settings UI

Add a MixType-specific option to the cassette settings pane:

> Enable Hybrid CIN + Pinyin candidates

It must clearly indicate that CIN exact candidates remain preferred.

Relevant files:

- `Packages/vChewing_SettingsUI/Sources/SettingsUI/SettingsUI/VwrSettingsPaneCassette.swift`
- `Packages/vChewing_SettingsUI/Sources/SettingsUI/SettingsCocoa/VwrSettingsPaneCocoaCassette.swift`
- localization files under `Sources/vChewingIME_macOS/Resources/*.lproj/`

## Reuse targets

Prefer extracting small reusable helpers rather than copying Furious Typing logic.

High-value existing APIs:

- `Tekkon.PinyinTrie.shared(parser:)`
- `furiousAbbreviatedCells(romaji:)`
- `buildFuriousAbbreviatedCandidates(cells:)`
- `LXQuerier.abbreviatedWordCandidates(keysChopped:)`
- `applyFuriousFrontCandidate(...)`

Where current guards require `.pinyinFuriousTyping`, refactor the pure calculation into guard-free helper functions and keep mode guards at the caller.

## V0.1 acceptance tests

### Regression

1. Hybrid disabled + cassette enabled behaves exactly like upstream cassette mode.
2. Normal Pinyin/Furious Typing behaves exactly like upstream when cassette is disabled.
3. Existing cassette quick phrase, wildcard, auto-longest-key, and symbol behaviors remain unchanged.

### Hybrid candidate tests

4. A key sequence with a valid CIN exact match keeps the CIN candidate first.
5. The same key sequence may also show Pinyin candidates afterward.
6. Duplicate output values from CIN and Pinyin appear only once.
7. A Pinyin-only sequence can produce a selectable Pinyin candidate while Hybrid is active.
8. An abbreviation sequence can reach the existing abbreviation lexicon path.

### Required demonstration cases

Use deterministic test lexicon fixtures where possible rather than depending on a user's private dictionary:

- full Pinyin phrase → Chinese phrase;
- abbreviation such as `ysxb` → existing upstream test phrase;
- a synthetic CIN key that conflicts with a Pinyin path → CIN remains first.

After the plumbing works, manually verify the desired real-world scenarios with the user's Boshiamy CIN:

- `wbzd` can surface 「我不知道」 when the lexicon provides it.
- `cyw` can surface relevant Pinyin-abbreviation candidates.
- a valid Boshiamy key remains first when it collides with a Pinyin interpretation.

## Rollout sequence

### Phase A — plumbing

- add Hybrid preference and typing mode;
- add the dedicated typewriter;
- prove both candidate sources can be queried in one state;
- no learning changes.

### Phase B — selection semantics

- route CIN selection through cassette semantics;
- route Pinyin selection through Homa insertion/override;
- add regression tests.

### Phase C — UX hardening

- candidate deduplication;
- stable source ordering;
- settings/localization;
- manual macOS IMK verification.

## V0.2 direction

After V0.1 is stable:

- persistent personal phrase/abbreviation database;
- learn full Pinyin selections and derive initials automatically;
- e.g. `cai yao wen → 蔡耀文` then `cyw → 蔡耀文`;
- usage frequency and recency ranking;
- explicit remove/reset controls.

## V0.3 direction

- integrate mixed Chinese/English intent;
- preserve uppercase technical tokens such as API, EMS, BESS;
- combine English-token learning with Hybrid CIN/Pinyin;
- target the end state where ordinary mixed text can be typed without manually switching language modes.
