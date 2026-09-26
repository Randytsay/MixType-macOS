# MixType V0.1 Phase A Read-Only Implementation Audit

> **Historical audit.** Phase A and the later V0.1 milestone have been implemented and accepted. For current status, see `docs/DEVELOPMENT_STATUS.md`.

Date: 2026-09-25  
Audited baseline: `main@8c8b77f251b64ac811664dfd39a4ff90a47303f5`

This document records the implementation-ready findings for V0.1 Phase A while the Mac runtime baseline is blocked on full Xcode 27.

**No Hybrid production code was modified during this audit.**

## 1. Phase A objective

Phase A should establish the smallest safe Hybrid routing seam without implementing candidate fusion yet.

The required outcome is:

```text
cassetteEnabled = true
hybridCassettePinyinEnabled = false
    -> existing .cassette path, unchanged

cassetteEnabled = true
hybridCassettePinyinEnabled = true
Pinyin parser active
    -> .hybridCassettePinyin
    -> HybridCassettePinyinTypewriter
    -> Phase A compatibility behavior delegates to existing cassette semantics

cassetteEnabled = false
    -> existing Bopomofo / Pinyin / Furious paths, unchanged
```

Phase A must **not** invoke both `CassetteTypewriter` and `BPMFFullMatchTypewriter` for the same input event.

## 2. Confirmed current hard exclusion

### Typing mode

File:

`Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_TypingMode.swift`

Current mode resolution begins with:

```swift
if prefs.cassetteEnabled { return .cassette }
```

Therefore cassette mode prevents all Pinyin/Furious mode selection before any later condition is considered.

### Composition dispatch

File:

`Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_HandleComposition.swift`

The current `.vChewingFactory` dispatch is mutually exclusive:

- `.cassette` -> `CassetteTypewriter(self).handle(input)`
- `.bopomofoKeyblock` -> mixed-alphanumeric typewriter or BPMF full-match typewriter
- `.pinyinKeyblock` / `.pinyinFuriousTyping` -> `BPMFFullMatchTypewriter(self).handle(input)`

This confirms that Hybrid needs a **new single dispatch path**, not sequential execution of two existing typewriters.

## 3. Exact Phase A preference wiring

Add a new default-off preference, suggested name:

`HybridCassettePinyinEnabled`

### Required files

#### A. UserDef

`Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/UserDef/UserDef.swift`

Add near the existing cassette / mixed-alphanumeric / furious preferences:

- enum case, suggested Swift name: `kHybridCassettePinyinEnabled`
- persisted key: `"HybridCassettePinyinEnabled"`
- default: `.bool(false)`
- metadata title/description keys

The default **must remain false** so a repository update cannot silently change existing cassette users' typing behavior.

#### B. Preference protocol

`Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/Protocols/PrefMgrProtocol.swift`

Add:

```swift
var hybridCassettePinyinEnabled: Bool { get set }
```

Place it beside `cassetteEnabled` / `furiousTypingEnabled`.

#### C. PrefMgr storage

`Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/PrefMgr_Core.swift`

Add an `@AppProperty` backed property beside `cassetteEnabled`.

Phase A does not require this new preference itself to alter LexiconAssembly configuration. It selects an InputHandler routing mode. Avoid adding unrelated LM sync behavior unless implementation evidence shows it is required.

#### D. Settings UI

**Deferred to V0.1 Phase D.**

Phase A should create the persisted preference and test seam only. Do not enlarge the patch with SettingsUI/localization surface work beyond the minimum UserDef metadata required by the existing preference architecture.

## 4. Exact TypingMode change

File:

`Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_TypingMode.swift`

Add:

```swift
case hybridCassettePinyin
```

The safe activation rule should require all of:

1. cassette enabled;
2. new Hybrid preference enabled;
3. the phonetic side is actually configured as Pinyin.

The repository now has a dedicated preference `pinyinTypingEnabled`, and `keyboardParser` selects the Pinyin parser slot when that flag is true. Runtime parser truth is also exposed by `composer.isPinyinMode`.

Recommended fail-closed rule:

```text
cassetteEnabled
  + hybridCassettePinyinEnabled
  + pinyinTypingEnabled
  + composer.isPinyinMode
      => hybridCassettePinyin
```

If any Hybrid prerequisite is missing, fall back to the existing `.cassette` behavior.

This deliberately avoids activating Hybrid when the user has a Zhuyin parser selected.

## 5. Dedicated Phase A typewriter seam

Add:

`Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/Typewriter/Typewriter_HybridCassettePinyin.swift`

Suggested type:

```swift
public struct HybridCassettePinyinTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol
```

### Phase A behavior

For Phase A only, the Hybrid typewriter should preserve cassette behavior through one controlled path, for example by delegating to the existing cassette handler.

Its purpose in Phase A is to establish:

- a unique routing identity;
- exactly-one-handler event consumption;
- a stable insertion point for Phase B dual candidate probing;
- zero behavioral change when Hybrid is disabled.

Do **not** call `BPMFFullMatchTypewriter.handle(input)` after or before `CassetteTypewriter.handle(input)`.

Both existing typewriters mutate shared InputHandler state. Sequential invocation would make event consumption, buffer mutation, session state and commit behavior order-dependent.

## 6. HandleComposition dispatch change

File:

`Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/InputHandler_HandleComposition.swift`

Add exactly one new switch branch:

```text
.hybridCassettePinyin
    -> HybridCassettePinyinTypewriter(self).handle(input)
```

All existing branches should otherwise remain unchanged.

This is the main Phase A guarantee against one NSEvent being consumed by two independent typewriters.

## 7. Confirmed Phase B hazards that Phase A must not accidentally solve

The following current helpers branch directly on `prefs.cassetteEnabled`, not on `typingMode`. They are safe to leave alone during a cassette-compatible Phase A skeleton, but they become explicit Phase B audit items when the Pinyin side gains live state.

### Buffer emptiness

`InputHandler_CoreProtocol.swift`

`isComposerOrCalligrapherEmpty` currently returns the calligrapher state whenever cassette is enabled.

### Reading display

`readingForDisplay`, `inlineReadingPreview`, and the private inline composition helper branch on cassette enablement.

### Backspace

`letComposerAndCalligrapherDoBackSpace()` chooses calligrapher vs composer solely from `cassetteEnabled`.

### Shift-Backspace and state generation

Cassette-specific branches in `InputHandler_HandleStates.swift` also use the cassette preference directly.

### LM configuration

`LXFacade.syncPrefs()` maps `prefs.cassetteEnabled` into LexiconAssembly configuration and independently uses Furious + Pinyin preferences for other factory-data behavior.

**Phase A rule:** do not refactor these broad semantics yet.  
**Phase B rule:** explicitly design ownership of the raw Hybrid buffer and secondary Pinyin probe before any of these helpers are changed.

## 8. Existing Pinyin/abbreviation machinery confirmed reusable later

The current tree already provides:

- `Tekkon.PinyinTrie.shared(parser:)`
- `trie.chop(...)`
- `trie.deductChoppedPinyinToZhuyin(...)`
- `furiousAbbreviatedCells(romaji:)`
- `buildFuriousAbbreviatedCandidates(cells:)`
- `LXQuerier.abbreviatedWordCandidates(keysChopped:)`
- Homa front-candidate insertion/override logic

Important detail:

`furiousAbbreviatedCells(romaji:)` is already separated from the guarded `furiousAbbreviatedCells` property. This is useful for Phase B because the pure calculation can be reused without pretending the whole session is in Furious mode.

## 9. Regression test locations

Primary existing cassette regression coverage is already concentrated in:

`Packages/vChewing_OSNeutral_LibVanguard/Tests/LibVanguardTests/InputHandlerTests_Cases1.swift`

Existing cassette tests cover, among other behavior:

- CIN/cassette loading
- quick phrases
- longest-key auto composition
- overflow handling
- Backspace
- Shift-Backspace
- any-single-character key
- wildcard behavior
- candidate-state Backspace

Existing Furious/Pinyin coverage also exists in:

- `InputHandlerTests_Cases1.swift`
- `SessionTests_Cases5.swift`

## 10. Minimum Phase A tests

Add focused tests for the new mode and preserve existing cassette regression coverage.

### Mode matrix

1. cassette on + Hybrid off -> `.cassette`
2. cassette on + Hybrid on + Pinyin enabled/parser active -> `.hybridCassettePinyin`
3. cassette on + Hybrid on + non-Pinyin parser -> fail closed to `.cassette`
4. cassette off + Pinyin/Furious -> existing mode unchanged
5. all defaults -> existing behavior unchanged

### Dispatch/regression sentinel

At least one real cassette key sequence should be run with Hybrid enabled during Phase A and produce the same result as the cassette path, proving the new route is not a dead branch and does not double-consume the event.

Retain the existing cassette regression suite unchanged.

### Event-consumption invariant

A single input event must result in one routing decision and one typewriter `handle` invocation.

Do not introduce a test helper that masks double mutation by clearing state between the two paths.

## 11. Recommended Phase A patch boundary

Expected production files:

1. `Shared/UserDef/UserDef.swift`
2. `Shared/Protocols/PrefMgrProtocol.swift`
3. `Shared/PrefMgr_Core.swift`
4. `LibVanguard/InputHandler/InputHandler_TypingMode.swift`
5. `LibVanguard/InputHandler/InputHandler_HandleComposition.swift`
6. new `LibVanguard/Typewriter/Typewriter_HybridCassettePinyin.swift`
7. focused LibVanguard test file(s)

Do not include:

- candidate merger implementation
- Pinyin probing
- abbreviation lookup integration
- Personal Lexicon
- English auto detection
- SettingsUI pane redesign
- broad refactors of cassette display/backspace helpers

## 12. Gate before implementation

Phase A remains blocked until the Mac baseline described in `docs/DEVELOPMENT_STATUS.md` passes with full Xcode 27:

- LibVanguard tests execute successfully;
- recommended IME debug build succeeds;
- baseline IME can be installed without damaging OpenVanilla;
- baseline cassette/CIN input is verified.

After that gate:

1. create `feat/hybrid-input-v01`;
2. implement only the Phase A patch boundary above;
3. run regression tests;
4. commit/push;
5. update `docs/DEVELOPMENT_STATUS.md`;
6. audit before Phase B.
