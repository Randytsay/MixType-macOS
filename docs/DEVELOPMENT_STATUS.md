# MixType Development Status

This file is the canonical handoff/status record for active MixType development.

## Current milestone

**V0.4 — Portable Backup / Restore**

Specifications:

- `docs/MIXTYPE_V0.1_HYBRID_PLAN.md` — V0.1 accepted baseline
- `docs/MIXTYPE_V0.2_PERSONAL_LEXICON_PLAN.md` — accepted V0.2 baseline

## Current phase

**V0.4 Phase A — portable personal backup / restore implemented and validated**

V0.3.0 remains the released baseline (`mixtype-v0.3.0`). V0.4 adds a portable, versioned
`.mixtypebackup` format so a new Mac can restore the user's MixType environment without copying old
absolute paths. The backup includes portable preferences, the active CIN/cassette file bytes and filename,
CHT/CHS Personal Lexicon, Auto Promotion pending observations, composition-learning pending observations,
single-character preferences, existing user phrases, filters, replacements, associated phrases, user
symbols, and `symbols.dat`. Transient POM/perception memory is intentionally excluded from schema v1.

Restore is replacement-oriented and fail-closed: the document and versioned learning stores are validated
before mutation; known portable roles absent from the backup remove stale destination files; preferences
and existing destination files are snapshotted for rollback; and CIN is restored into the new Mac's
internal cassette cache rather than reusing the old machine's absolute path. `CassettePath` and
`UserDataFolderSpecified` are never exported through the preferences payload. Regression coverage
confirms the serialized backup does not contain the old cassette or user-data absolute paths.

Both SwiftUI and Cocoa Settings panes expose “Export Complete Backup” and “Restore Complete Backup”.
Restore presents an explicit replacement confirmation first. Four UI localizations (English,
Traditional Chinese, Simplified Chinese, Japanese) are present and lint clean.

The clean Mac baseline and V0.1 installed-IME runtime acceptance have passed, including real
Cassette/CIN input, full Pinyin, abbreviated Pinyin, numeric candidate selection, and ordinary digits.
V0.2 now has a local Personal Lexicon model, full-Pinyin/initials Hybrid integration, deterministic
local reading/key generation, atomic macOS persistence, and zero-candidate ASCII fallback.
Batch A productizes that foundation: the modern Settings UI can manage Personal Lexicon entries,
import/export native JSON, and switch the MixType base input provider among Zhuyin, Pinyin, and CIN.
Native Zhuyin/Pinyin Homa paths can now consume Personal Lexicon entries without changing upstream
LM/POM ordering; CIN continues to use the validated Hybrid path.
Batch B adds persistent explicit-selection observations, threshold-based automatic promotion into the
Personal Lexicon, user-visible learning controls, and a conservative English-intent filter that suppresses
only factory-abbreviation-only collisions for English-shaped raw tokens while preserving CIN, Personal,
and full-Pinyin matches.
Composition phrase learning now adds a second, independent learning signal: exact committed Chinese
compositions of 2...6 characters accumulate in their own pending store and promote into the same Personal
Lexicon after the configured threshold. This makes frequently composed phrases available through full,
initials, and mixed-Pinyin lookup without conflating ordinary composition with explicit candidate selection.
Final hardening adds a threshold-time factory-reading validation gate: existing factory phrases may only
auto-promote with an exact reading chain that the factory itself supports, while genuinely new phrases
remain learnable from their actual composition readings. The check is lazy-cached and invalidated whenever
the factory dictionary reloads, so it does not enter the per-key hot path.

V0.3 Phase A keeps the accepted Hybrid typewriter as the single authoritative event route. Batch 1 added
an initially default-off `MixTypeMixedTokenSegmentationEnabled` preference and deterministic protected-ASCII handling
inside that route only. Case-sensitive model names / acronyms, English+digit tokens, e-mail addresses, URLs,
and common URL/unit punctuation can remain in the Hybrid raw buffer without being split by Shift-ASCII or
accidental Chinese-candidate routing. The flag-off path still preserves V0.2 behavior, but after Phase A
acceptance the preference was graduated to default-on for the `mixtype-v0.3.0` release. Batch 2 adds
conservative adjacent English→Pinyin boundary splitting: the ASCII prefix must have strong English evidence,
the suffix must have a real full/composed Pinyin source, and the Chinese suffix remains in the candidate UI
for explicit confirmation rather than being auto-selected. Batch 3 adds a bounded runtime context for digits
that have already been passed through to the client, allowing deterministic digit-leading time/unit tokens
such as `3pm`, `20kW`, and `300RT` to finish as literal ASCII without re-committing the digits. The
numeric context is cleared on normal commit/reset and explicit Chinese selection, while unrecognized
digit-leading suffixes remain eligible for Chinese Pinyin candidates (for example `3nihao → 3你好`).
Batch 4 adds deterministic continuous mixed candidate generation for raw streams that contain Pinyin,
English, then Pinyin without a physical delimiter. The accepted real-client flow now includes
`jintianmeeting → 今天meeting` and `jintianmeetinggai → 今天meeting改`, while weak-English
false positives such as `jintianming` / `jintianminggai` remain guarded. Batch 5 closes the remaining
CIN collision: punctuation that is part of a valid cassette code keeps CIN priority before mixed-token
syntax protection. A dedicated public test cassette locks `s. → ？` without committing any private CIN
data. Digit-leading time/unit tokens and e-mail/URL tokens retain their accepted ASCII precedence.

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
- Shift-produced printable ASCII is handled before candidate selection (`Shift+2 → @`, `Shift+/ → ?`, uppercase letters): ✅ code/tests + installed-Mac validation
- Explicit English override in Hybrid: `Enter` commits the raw token, `Shift+Space` commits raw token + half-width space even when Chinese candidates exist: ✅
- Personal Lexicon activation safety-net reload for empty runtime stores with persisted JSON: ✅
- Multiple Personal Lexicon entries may share the same full/initials key; actual selection increments `selectionCount`, updates `lastUsedAt`, reorders peers, and persists immediately: ✅
- Personal Lexicon Settings UI: search/list/add/edit reading/pin/enable-disable/delete/import/export: ✅ code/tests
- MixType Base Input Provider abstraction (`zhuyin` / `pinyin` / `cin`) derived from existing preferences: ✅
- Settings UI base-provider switch with CIN validity guard: ✅
- Native Zhuyin/Pinyin Homa can consume Personal Lexicon while preserving upstream gram/POM ordering: ✅
- MixType Settings localization: English / Traditional Chinese / Simplified Chinese / Japanese: ✅
- Auto Promotion pending-observation model + versioned JSON persistence: ✅
- explicit candidate selection hook for Hybrid/native phonetic paths; previews/cancel do not count: ✅
- default auto-promotion threshold 3, configurable 2...20, with Settings UI controls: ✅
- promotion uses the candidate's actual selected reading and promotes exactly once: ✅
- conservative English-intent preference: suppress factory-abbreviation-only collisions for English-shaped tokens: ✅
- English intent keeps stronger Chinese sources (CIN / Personal / full Pinyin) intact: ✅
- Personal Lexicon manual reading editor accepts canonical Zhuyin or toned Hanyu Pinyin (`hui4 ling2`, `huì líng`) and normalizes to internal Zhuyin: ✅
- single-character Personal Lexicon reading derivation now prefers the production reverse-lookup index; production regression locks `卉羚 → huiling / hl`: ✅
- Personal Lexicon mixed-Pinyin prefix matching: query-time per-syllable prefix match without alias expansion (`jhaole → 就好了`, `jhao → 就好`): ✅
- mixed-prefix Personal candidates remain visible even when conservative English-intent detection considers the raw token English-shaped: ✅
- existing factory mixed-abbreviation selections still feed Auto Promotion; after threshold promotion, the generated initials key is immediately available (`nliu → 能留` ×3 ⇒ `nl → 能留`): ✅
- composition phrase learning pending store + separate `composition-phrase-pending-cht/chs.json` persistence: ✅
- exact committed Chinese compositions of 2...6 characters learn by `phrase + actual readings`, using the existing Auto Promotion threshold (default 3): ✅
- composition learning rejects single characters, punctuation/ASCII mixtures, >6-character phrases, unmatched commit text, pending raw buffers, and reading-count mismatches: ✅
- composition-learning promotion feeds the same Personal Lexicon, so learned `就好了` immediately supports `jiuhaole / jhaole / jhl`: ✅
- full-Pinyin composed-candidate provider: if no whole-phrase gram exists, 2...6 valid Pinyin syllables are segmented against existing factory/user grams and surfaced through a bounded N-best DP instead of failing closed: ✅
- production regression confirms the real factory contains `過來` and `一下`; Hybrid UI regression locks `guolaiyixia → 過來一下` even when a higher-scoring tone ambiguity (`過來以下`) exists: ✅
- toneless Pinyin single-character preference store (`single-character-preferences-cht/chs.json`): ✅
- explicit single-character Pinyin selections learn by tone-insensitive Zhuyin bucket (for example `ㄧㄠˋ → ㄧㄠ`) and persist across restarts: ✅
- single-character candidate order starts changing only after 3 explicit selections; the first 1–2 selections are recorded but do not reorder, reducing accidental-learning risk: ✅
- Hybrid and native Pinyin candidate lists re-rank only single-character peers; longer words keep their original relative positions: ✅
- regression locks `要 / 藥 / 耀` so repeated explicit selection of `耀` moves it ahead without deleting alternatives: ✅
- auto-promotion threshold factory-reading gate rejects unsupported readings for known factory phrases while preserving legitimate multi-reading variants: ✅
- exact-reading lookup is lazy-cached and cache invalidates on factory reload: ✅
- final sequential-selection acceptance: `wei → 韋`, then `hong → 宏`, commit `韋宏` three times ⇒ Personal `weihong / wh`: ✅
- V0.3 Phase A mixed-token feature flag: ✅ introduced default-off for rollout safety, graduated default-on for release
- protected ASCII token routing in the existing Hybrid typewriter (no second typewriter / no LLM / no network): ✅
- case-sensitive / alphanumeric token preservation (`MacBookM6`, `ABC123`, `server2026`, `SOC80%`): ✅ focused regression
- V0.4 versioned portable `.mixtypebackup` schema v1: ✅
- portable preferences + active CIN/cassette + CHT/CHS Personal / promotion / composition / single-character learning data: ✅
- existing user phrases / filters / replacements / associates / user-symbol data included as opaque bytes: ✅
- old `CassettePath` / `UserDataFolderSpecified` absolute paths excluded from the backup: ✅ regression
- restore relocates CIN into the new Mac's internal cassette cache and portable user data into the local default data folder: ✅ regression
- exact restore semantics remove stale known-role files that are absent from the backup: ✅ regression
- malformed backup fail-closed without changing current preferences/data: ✅ regression
- restore rollback snapshots preferences and destination files: ✅
- SwiftUI + Cocoa complete-backup export/restore UI with destructive-restore confirmation: ✅
- backup/restore localization EN / zh-Hant / zh-Hans / JA: ✅ lint
- V0.4 validation: MainAssembly 43 tests PASS; SettingsUI 17/17 PASS; full LibVanguard PASS; `make debug` PASS; `git diff --check` PASS
- e-mail / URL token preservation (`email@example.com`, `https://example.com/path?q=1`): ✅ focused regression
- adjacent English→Pinyin split without auto-selection (`今天meetinggai` → commit `今天meeting`, keep `gai` candidates): ✅ focused regression
- valid-Pinyin anti-split guards (`nengliu`, `taidagai`) and protected-token atomicity: ✅ focused regression
- digit-leading literal time/unit flow (`3pm`, `20kW`, `300RT`) without duplicated passthrough digits: ✅ focused regression
- chained mixed-token flow (`今天meeting改3pm`) preserves Chinese / English / Chinese / numeric-unit boundaries: ✅ focused regression
- digit-leading non-unit Pinyin remains selectable as Chinese (`3nihao → 3你好`): ✅ focused regression
- continuous Pinyin→English candidate generation (`jintianmeeting → 今天meeting`): ✅ focused + installed-Mac validation
- continuous Pinyin→English→Pinyin candidate generation (`jintianmeetinggai → 今天meeting改`): ✅ focused + installed-Mac validation
- weak-English anti-split guards (`jintianming`, `jintianminggai`): ✅ focused regression
- valid CIN punctuation-code precedence before mixed-token syntax (`s. → ？`): ✅ public fixture regression + installed-Mac validation

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

1. V0.2 final hardening build installation: ✅ complete with strict codesign verification and private runtime data preserved.
2. Final Mac sanity: ✅ complete. Existing real-Mac evidence already covers Shift-ASCII / explicit English override; the final provider-state pass verified Zhuyin → Pinyin → CIN transitions against the installed input source and restored the original CIN/Hybrid preferences afterward.
3. Learned runtime data sanity: ✅ `韋宏 = weihong / wh`, `過來一下 = guolaiyixia / glyx`, and the learned `耀` single-character preference remain persisted after the final hardening install.
4. V0.2 is acceptance complete. V0.3 Phase A Batches 1–5 are committed/pushed; protected ASCII, adjacent and continuous English/Pinyin segmentation, digit-leading unit/time handling, and CIN punctuation-code precedence have all passed the full relevant validation gate.
5. The latest V0.3 Debug IME is installed after backing up the previous bundle; strict codesign passes, OpenVanilla remains present, and private CIN / Personal / learning file hashes are unchanged. After acceptance, the mixed-token preference is default-on for the first public MixType V0.3 release; users may still explicitly disable it.
6. V0.3 Phase A real-client acceptance: ✅ `server2026`, `今天meeting改`, and private-CIN punctuation code `s. → ？` were verified on the installed IME.

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
- [x] installed-Mac E2E for `台達能源` full-Pinyin / initials lookup
- [x] Shift-ASCII routing regression (`@`, `?`, uppercase) and candidate-collision protection
- [x] explicit English override regression (`Enter`, `Shift+Space`)
- [x] Personal Lexicon activation reload regression
- [x] same-key multi-entry Personal Lexicon selection learning + persistence regression
- [x] Settings UI add/edit/remove/search/pin/disable
- [x] native JSON import/export UI + management API
- [x] pronunciation correction through editable Zhuyin reading sequence
- [x] Base Input Provider abstraction and selector
- [x] native Zhuyin/Pinyin Personal Lexicon Homa integration
- [x] installed-Mac E2E for `Shift+2 → @` / Shift-ASCII behavior
- [x] explicit English override real-Mac validation; Personal activation reload regression plus previously installed `tdny` Personal E2E remain green
- [x] auto-promotion after explicit selections
- [x] auto-promotion pending JSON survives restart
- [x] auto-learning enable/threshold Settings UI
- [x] conservative English-intent filtering for abbreviation-only collisions
- [x] Personal Lexicon mixed-Pinyin prefix matching without persisted alias expansion
- [x] mixed-prefix → Auto Promotion → full initials acceptance regression
- [x] composition phrase learning from exact committed 2...6-character Chinese compositions
- [x] independent composition pending persistence and threshold promotion into Personal Lexicon
- [x] commit-gate regressions for punctuation/raw-buffer pollution rejection
- [x] toneless-Pinyin single-character selection preference + JSON persistence
- [x] Hybrid/native Pinyin single-character candidate re-ranking
- [x] threshold-time factory-reading validation before auto promotion
- [x] legitimate factory multi-reading variants remain promotable
- [x] exact-reading validation cache + factory-reload invalidation
- [x] sequential single-character composition regression (`wei → 韋`, `hong → 宏` ×3 ⇒ `weihong / wh`)
- [x] V0.3 mixed-token routing flag, graduated from default-off rollout to default-on release behavior
- [x] V0.3 protected ASCII model/acronym/alphanumeric tokens
- [x] V0.3 protected e-mail / URL tokens
- [x] V0.3 adjacent Chinese → ASCII flow through existing assembler + Hybrid raw buffer
- [x] V0.3 adjacent ASCII → Pinyin boundary split with explicit Chinese candidate confirmation
- [x] V0.3 digit-leading unit/time tokens (`3pm`, `20kW`, `300RT`) as one deterministic mixed-token flow
- [x] V0.3 continuous Pinyin → English and Pinyin → English → Pinyin candidate generation
- [x] V0.3 real-client `jintianmeetinggai → 今天meeting改`
- [x] V0.3 CIN punctuation-code priority over mixed-token syntax (`s. → ？`)

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

V0.2 runtime validation now shows the locally seeded Personal Lexicon phrase `台達能源` can be produced
through both requested Personal Lexicon paths in the installed IME. A follow-up real-Mac issue exposed
that `Shift+2` was still routed through `charactersIgnoringModifiers` and could therefore be interpreted
as raw key / candidate label `2` instead of visible `@`. Regressions `IH107` and `IH108` now require
Shift-produced printable ASCII to be resolved through the active Latin keyboard layout before candidate
handling, and require a pending raw token to remain literal ASCII rather than accidentally selecting a
Chinese candidate. Full LibVanguard package tests pass after the fix and `make debug` passes.

The English/Chinese collision UX is now deterministic: normal Space keeps Chinese candidate semantics,
numeric keys select Chinese candidates directly, Enter forces the current raw token to literal ASCII,
and Shift+Space forces literal ASCII plus a half-width space. This remains effective even when the raw
token happens to have a valid Chinese abbreviation candidate (for example an English word colliding with
Pinyin initials). Regression `IH109` covers both explicit-English paths. LXMgr additionally reloads a
persisted Personal Lexicon on input-source activation only when the current mode's in-memory store is
empty, closing a lifecycle gap observed after IME replacement/restart. LXMgr startup/activation reload
regressions both pass.

Personal Lexicon ranking now learns only from confirmed selections. Multiple entries may share the same
full-Pinyin or initials key and remain simultaneously visible; selecting one increments its persisted
`selectionCount` and refreshes `lastUsedAt`, so repeatedly chosen Personal entries move ahead of their
Personal peers without deleting alternatives. Factory/CIN candidates remain separate sources and continue
to coexist in the merged Hybrid candidate list. Selection-learning and persistence regressions pass, as do
the full LibVanguard package suite, LXMgrTests, and `make debug`.

Batch A adds a real product-management surface and removes the remaining Cassette-only architecture
assumption. `Shared.MixTypeBaseInputProvider` models Zhuyin, Pinyin, and CIN without introducing a second
stored preference; the provider is derived from existing vChewing preferences, preventing state drift.
The Settings dictionary pane now exposes a base-provider selector and a Personal Lexicon manager with
search, add, edit/readings correction, pin, enable/disable, delete, import, and export. The macOS host
routes all mutations through LXMgr atomic persistence/rollback APIs rather than letting UI code edit JSON.
For native Zhuyin/Pinyin, Personal grams are appended only when the existing LM does not already provide
that display value; the existing gram sequence and contextual duplicates remain untouched, preserving
MixedAlphanumerical and Furious/POM semantics. Full LibVanguard tests pass after this stable-merge rule.
SettingsUI tests are 17/17 PASS, LXMgrTests are 22/22 PASS, all four localization files lint successfully,
and `make debug` passes on Xcode 27 / Swift 6.4.

Batch B implements the promotion lifecycle specified for V0.2. `PersonalLexiconPromotionStore` keeps
pending observations separate from the long-term Personal Lexicon, keyed by phrase + actual selected
reading. Only explicit candidate confirmations call the learning hook; merely showing a candidate does
not increment the count. At the configured threshold (default 3, range 2...20) the phrase is promoted
exactly once with `.autoPromoted` provenance and generated full-Pinyin/initials keys, then the pending
observation is removed. Pending data and promoted Personal data are persisted independently and loaded
at startup / input-source activation. The Dictionary settings pane exposes both the learning switch and
threshold control.

Batch B also adds a conservative English-intent preference (default on). Hybrid suppresses candidates
only when the raw token has an English-like Latin shape and every remaining candidate is a factory Pinyin
abbreviation. CIN exact/quick, Personal full/initials, and full-Pinyin matches are never hidden by this
heuristic. This addresses accidental collisions such as ordinary English words surfacing abbreviation
candidates while preserving intended shorthand such as `tdny`, `ysxb`, `jngsfa`, and existing explicit
Enter / Shift+Space English overrides. Full LibVanguard tests pass, SettingsUI tests are 17/17 PASS,
LXMgrTests are 23/23 PASS, all four localization files lint, and `make debug` passes.

Follow-up Personal Lexicon hardening fixes a real name-entry failure reported from the Settings UI:
`卉羚` had been auto-derived as `benling / bl`. Single-scalar reading resolution now uses the existing
factory reverse-lookup index before the multi-value exact-scan path, while multi-character segmentation
remains unchanged. The editor no longer exposes Zhuyin as a user requirement: users may enter canonical
Zhuyin, numbered Hanyu Pinyin (`hui4 ling2`), or tone-marked Hanyu Pinyin (`huì líng`); the data model
still stores normalized Zhuyin internally for Homa/LXAssembly compatibility. A production-resource test
asserts `卉羚 → ㄏㄨㄟˋ ㄌㄧㄥˊ → huiling → hl`. Full LibVanguard tests, SettingsUI tests, LXMgrTests
(24/24), four localization lints, and `make debug` all pass after this fix.

Toneless Pinyin single-character learning is now separated from Personal Lexicon. Explicitly selecting
a one-character Pinyin candidate records a preference keyed by tone-insensitive Zhuyin (for example
`ㄧㄠˋ` normalizes to `ㄧㄠ`) plus the selected character. Hybrid and native Pinyin candidate generation
use this persistent preference only to reorder single-character peers occupying the same candidate slots;
multi-character phrases retain their original order. Regressions `IH525` / `IH526` verify that repeated
selection of `耀` leaves the original order unchanged for the first two selections, moves it ahead of
`要 / 藥` starting with the third explicit selection, and that the learning hook requests persistence. The
dedicated JSON store round-trips successfully, LXMgr save/reload passes, full LibVanguard tests pass,
SettingsUI remains 17/17 PASS, LXMgrTests are 25/25 PASS, and `make debug` passes.

Personal Lexicon now also supports mixed Pinyin prefixes without changing its persisted schema or
materializing combinatorial aliases. Hybrid splits the raw Pinyin stream with the existing `PinyinTrie`
and compares each chunk against the corresponding `pinyinTokens` entry using prefix semantics. Thus a
single `就好了 = [jiu, hao, le]` entry is reachable through full Pinyin (`jiuhaole`), initials (`jhl`),
and mixed forms such as `jhaole` / `jiuhle`; `就好 = [jiu, hao]` is reachable through `jhao`. Direct
full/initial matches keep their existing source identity and ordering, while only genuinely mixed forms
use the new Personal mixed-prefix source. The query is computed at lookup time, so JSON schema v1 remains
unchanged and no alias explosion occurs. Regression `IH527` locks `jiuhaole / jhaole / jhl → 就好了`
and `jhao → 就好`, including the case where English-intent detection is enabled. Regression `IH528`
locks the learning bridge: repeated explicit selection of a factory mixed-abbreviation candidate promotes
it at the normal threshold, after which its all-initials key resolves through Personal Lexicon. Full
LibVanguard tests pass, SettingsUI remains 17/17 PASS, LXMgrTests are 25/25 PASS, and `make debug` passes.

Composition phrase learning adds a separate pending lifecycle for phrases formed through ordinary Homa
composition rather than explicit candidate selection. The Session commit path observes the assembler
immediately before it is cleared, so learning uses the exact committed Chinese text together with the
actual Zhuyin readings that produced it; it never reverse-guesses pronunciation from text. Only pure CJK
compositions of 2...6 characters are eligible, the committed string must exactly equal the assembled
Chinese phrase, every character must have one aligned reading, and the raw Pinyin/CIN/mixed-ASCII buffers
must already be empty. Observations are stored independently in
`composition-phrase-pending-cht/chs.json`, keyed by phrase + readings, and use the existing Auto Promotion
threshold (default 3). Candidate-selection observations and composition observations therefore never
cross-count. At threshold the phrase is promoted into the same Personal Lexicon with generated full-Pinyin
and initials keys; mixed-prefix lookup is then available automatically. Regressions `IH529` / `IH530`
exercise the real Session commit hook: three exact commits of `就好了` promote it to `jiuhaole / jhl`,
after which `jhl` and `jhaole` resolve it; commits containing extra punctuation or a pending raw buffer do
not count. The dedicated store JSON round-trip and LXMgr save/reload pass. Full LibVanguard tests pass,
SettingsUI remains 17/17 PASS, LXMgrTests are 26/26 PASS, and `make debug` passes.

Hybrid full-Pinyin lookup now has a composition fallback for phrases that are not stored as one factory
gram. When a raw token can be fully chopped into 2...6 Hanyu-Pinyin syllables, the provider queries bounded
contiguous spans against the existing phonetic lexicon and runs a small N-best dynamic program over those
grams. This avoids materializing tone combinations or aliases while still surfacing plausible segmented
sentences. Each candidate carries the exact chosen Zhuyin readings and is replayed through a clean Homa
scratch before being exposed, so only candidates that the real assembler can reproduce survive. The live
selection path then inserts those exact readings into the actual Homa composition rather than inventing a
nonexistent whole-phrase gram. Regression `IH531` deliberately makes the top-1 all-tone Homa result
`過來以下` but still requires the candidate UI for `guolaiyixia` to contain and successfully select
`過來一下`. Production `LXMgr` regression `035` confirms the shipped factory data contains both source
segments `過來` and `一下`. Full LibVanguard tests pass, SettingsUI remains 17/17 PASS, LXMgrTests are
27/27 PASS, and `make debug` passes.

Final V0.2 learning-quality hardening validates readings only when an observation actually reaches the
promotion threshold. If the factory has an exact whole-phrase entry, the observed reading chain must be
one of the factory-supported chains; otherwise the pending observation is discarded and never promoted.
If the factory has no whole-phrase entry, the user-composed reading remains authoritative, preserving new
name / phrase learning. Exact-reading chains are cached only on this low-frequency path and the cache is
cleared on every factory dictionary reload. Production regression `LXMgr 036` confirms that the shipped
factory legitimately supports all four `什麼` variants, including `ㄕㄜˊ ㄇㄛ˙`, while an invented
unsupported reading is rejected at the third observation and the pending record is removed. A dedicated
cache reload regression confirms no stale reading decision survives a factory replacement. Regression
`IH532` executes the real user flow `wei → 韋`, `hong → 宏`, Enter, repeated three times; the phrase is
promoted as `韋宏` with `weihong / wh`, and both lookup paths resolve immediately. The V0.2 focused final
acceptance gate passes, full LibVanguard tests pass, SettingsUI remains 17/17 PASS, LXMgrTests are 28/28
PASS, and `make debug` passes.

## Handoff template

Update this section whenever a work batch is handed to another agent/environment:

```text
Current branch: feat/backup-restore-v04
Released baseline: `mixtype-v0.3.0` from `ee2fff27` (universal arm64 + x86_64, ad-hoc signed, explicitly unnotarized)
Latest V0.4 core commit: `064d02ef` (portable backup / restore core)
Completed in current V0.4 working batch: schema-v1 backup package; portable preferences; CIN relocation; CHT/CHS Personal / promotion / composition / single-character learning payloads; legacy user-data payloads; exact restore semantics; rollback/fail-closed validation; SwiftUI + Cocoa export/restore UI; four localizations
Tests: full LibVanguard package tests PASS; SettingsUI 17/17 PASS; MainAssembly 43/43 PASS including backup round-trip + malformed-package fail-closed regressions; four localization files lint PASS; `make debug` PASS; `git diff --check` PASS.
Privacy: no private CIN, Personal Lexicon, pending-learning, or preference-data file is committed. Backup files are created locally only when the user explicitly exports them.
Portability: backup regression proves old cassette and user-data absolute paths are absent; restore writes to the new Mac's default portable locations and internal cassette cache.
Known limitation: schema v1 intentionally excludes transient POM/perception memory and does not register a Finder document type for `.mixtypebackup`; Settings open/save panels recognize the extension directly.
Mac runtime install: V0.4 Debug IME installed after backing up the previous bundle. Strict codesign PASS; OpenVanilla remained present; 15 known portable/private data files (including the active CIN and MixType learning/user-data roles) were hash-compared before/after and are unchanged.
Latest V0.4 UI/hardening commit: `db53f354` — complete Backup / Restore UI, exact restore semantics, localization, and portability regressions.
Next unfinished item: perform a non-destructive real-Mac “Export Complete Backup” sanity from Settings. Do not perform a real-data restore merely for acceptance; restore semantics are already covered by the isolated round-trip/fail-closed regression.
```
