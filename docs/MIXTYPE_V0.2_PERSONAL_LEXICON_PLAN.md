# MixType V0.2 Personal Lexicon + Auto Promotion Plan

Status: in progress — core/persistence/Hybrid lookup implemented; installed-Mac E2E and UI pending
Depends on: V0.1 Hybrid candidate path stable and runtime-accepted ✅

## 1. Goal

V0.2 adds a persistent, local-first Personal Lexicon that turns frequently used Chinese phrases into reliable full-Pinyin and initial-abbreviation candidates.

Primary examples:

```text
Manual:
台達能源
  -> tai da neng yuan
  -> taidanengyuan
  -> tdny

Learned:
user explicitly selects 蔡耀文 repeatedly
  -> capture the selected phrase + actual reading
  -> after the promotion threshold
  -> persistent Personal Lexicon entry
  -> caiyaowen / cyw
```

The user should normally be able to add only the Chinese phrase. Reading correction is an advanced path for ambiguity.

## 2. Non-goals

V0.2 does not require:

- cloud accounts or sync;
- LLM-based reading generation;
- uploading typing history;
- arbitrary fuzzy abbreviations;
- semantic prediction;
- full Chinese-English automatic segmentation;
- replacing the existing vChewing user-phrase system.

## 3. Relationship to existing vChewing features

The current codebase already has two useful but different mechanisms.

### Existing user phrases

LexiconAssembly already maintains persistent user phrase data and exposes user-phrase loading, replacement and summarization.

This is reading-keyed dictionary data and remains useful for normal phrase lookup.

### Existing POM / Perception Override Model

The existing POM learns selection behavior and supplies temporary context-sensitive suggestions.

It is intentionally decaying and is not a permanent abbreviation dictionary.

### MixType Personal Lexicon

V0.2 should add a distinct persistent layer for:

- phrase identity;
- canonical selected reading;
- full-Pinyin key;
- initials key;
- selection count / recency;
- manual vs auto-learned provenance;
- pin/disable/edit lifecycle.

Do not overload POM with permanent vocabulary responsibility.

## 4. Core user experience

### Manual add

Default UI:

```text
新增詞語
[ 台達能源 ]

[新增]
```

The system should derive the reading locally and generate:

```text
phrase: 台達能源
full pinyin: tai da neng yuan
full key: taidanengyuan
initials: tdny
source: manual
```

Advanced editing may expose:

- pronunciation/readings;
- generated full Pinyin;
- generated initials;
- pin/disable state.

Manual entries do not expire automatically.

### Automatic promotion

Default setting:

```text
☑ 自動學習常用詞
選擇 [3] 次後加入個人詞庫
```

Recommended initial default threshold: **3 explicit selections**.

The counter should be keyed by the phrase **and its actual selected reading**, not by phrase text alone, so polyphonic words do not collapse into the wrong pronunciation.

## 5. What counts as a learning observation

V0.2 should be conservative.

Count by default:

- explicit candidate selection by the user;
- selection from a Hybrid Pinyin/full-Pinyin/abbreviation candidate when the exact reading is known.

Do not count by default:

- mere appearance in a candidate list;
- canceled candidates;
- speculative previews;
- automatic sentence guesses that the user did not explicitly confirm;
- raw Enter commits where no explicit candidate choice proves intent.

This matches the existing conservative POM philosophy and avoids rapidly learning accidental output.

A later setting may broaden learning signals after real-world validation.

## 6. Reading resolution strategy

Reading correctness is more important than convenience because abbreviation generation depends on it.

Use this priority order.

### A. Auto-learned phrase: capture the actual selected reading

This is the strongest source.

When the user selects a candidate, preserve its real `keyArray` / reading chain and derive Pinyin from that.

This avoids guessing polyphonic words.

### B. Manual phrase: exact whole-phrase lexicon lookup

When the user enters Chinese only, first query existing local lexicon data for exact phrase readings.

If one strong whole-phrase reading exists, use it.

If multiple readings exist, the UI may choose the top existing lexicon reading while marking the entry as pronunciation-editable.

### C. Deterministic local fallback

Only when no reliable lexicon reading exists, a local deterministic transliteration fallback may propose a pronunciation.

Fallback output must remain editable because per-character transliteration is not sufficient for phrases such as:

- 重慶
- 銀行
- 長大

No cloud lookup or LLM is required.

## 7. Pinyin normalization

Given a canonical Zhuyin/phonetic reading chain, reuse Tekkon conversion rather than introducing a second Pinyin table.

Existing API:

`Tekkon.cnvPhonaToHanyuPinyin(targetJoined:)`

Normalize the result for lookup:

- lowercase;
- remove tone marks/numbers from lookup keys;
- preserve token boundaries internally;
- full key = concatenated syllables;
- initials key = first Latin letter of each syllable.

Example:

```text
ㄊㄞˊ ㄉㄚˊ ㄋㄥˊ ㄩㄢˊ
-> tai da neng yuan
-> taidanengyuan
-> tdny
```

## 8. V0.2 supported lookup forms

Initial scope should support only:

1. exact normalized full-Pinyin key;
2. exact full initials key.

Example:

```text
taidanengyuan -> 台達能源
tdny          -> 台達能源
```

Do not initially generate every partial shorthand variant such as `tdn`, `dny`, `tdnyy`, etc.

That would enlarge the candidate space and make ranking/debugging much harder.

## 9. Proposed data model

Conceptual model:

```text
PersonalLexiconEntry
- id
- phrase
- readings[]
- pinyinTokens[]
- fullPinyinKey
- initialsKey
- source: manual | autoPromoted
- selectionCount
- createdAt
- updatedAt
- lastUsedAt
- pinned
- disabled
- schemaVersion
```

Optional future fields:

- custom weight;
- user-edited pronunciation flag;
- import source;
- tombstone/deletion metadata for future sync.

### Identity

A safe initial identity is:

```text
phrase + canonical reading chain
```

The same Han characters with a genuinely different reading may therefore coexist.

## 10. Storage design

Keep Personal Lexicon separate from private CIN files and separate from POM.

Preferred V0.2 approach:

- a versioned local Personal Lexicon file under the existing user-data area;
- atomic writes;
- debounced persistence for selection counters;
- deterministic indexes rebuilt from the stored entries;
- export/import support.

A versioned JSON representation is acceptable for V0.2 if writes are atomic and debounced.

Do not introduce SQLite only for theoretical scale unless profiling or concurrency requirements justify it.

Storage access should be wrapped behind a small store interface so the persistence format can change later without changing candidate-merger semantics.

## 11. Suggested components

### `PersonalLexiconEntry`

Pure data model.

### `PersonalLexiconStore`

Responsibilities:

- load/save/migrate;
- add/edit/delete/disable;
- increment observations;
- promote pending observations;
- expose exact full-Pinyin and initials indexes.

### `PersonalLexiconReadingResolver`

Responsibilities:

- accept a known candidate reading directly;
- resolve manual Chinese phrases from local lexicon data;
- produce editable fallback only when necessary.

### `PersonalLexiconKeyGenerator`

Responsibilities:

- canonical Pinyin tokens;
- full key;
- initials key;
- normalization tests.

### `AutoPromotionPolicy`

Responsibilities:

- threshold;
- eligible observation types;
- minimum phrase length;
- duplicate/promotion behavior.

Keep ranking policy outside the persistence store.

## 12. Candidate integration

V0.1 candidate merger will eventually receive Personal Lexicon offers as another source.

Recommended default source behavior:

```text
1. exact CIN/Boshiamy
2. personal exact phrase candidate when applicable
3. other CIN quick candidates / normal Pinyin according to V0.1 policy
4. remaining Personal/Pinyin abbreviation candidates
```

The exact V0.2 merge order should be tuned with tests, but one product rule is fixed:

**A valid exact CIN/Boshiamy result must not silently lose first place by default.**

If there is no exact CIN collision, a strong Personal Lexicon exact match may become candidate #1.

Manual/pinned entries may receive a stronger Personal score than auto-promoted entries, but this still must respect the default exact-CIN protection rule.

## 13. Duplicate behavior

Deduplicate by displayed phrase value at candidate-merger time.

If the same phrase arrives from:

- CIN;
- factory Pinyin;
- user phrase;
- Personal Lexicon;

show one visible phrase candidate, while retaining enough internal provenance to apply the correct selection semantics and learning update.

Do not duplicate `台達能源` four times simply because four sources found it.

## 14. Promotion lifecycle

Suggested three-tier behavior:

```text
selection observation
    ↓
pending usage record
    ↓ threshold reached
auto-promoted Personal Lexicon entry
    ↓
persistent long-term entry
```

Manual entries bypass the pending stage.

### Default cleanup policy

Manual:

- never auto-expire.

Auto-promoted:

- retain persistently in V0.2;
- track `lastUsedAt` for future cleanup tooling;
- do not silently delete learned entries in the first release.

A future version may offer explicit stale-entry cleanup.

## 15. Settings / management UI

Recommended native macOS settings page:

```text
Personal Lexicon
────────────────────────────
☑ 自動學習常用詞
學習門檻 [ 3 ] 次

搜尋 [________________]

台達能源        tdny      manual
蔡耀文          cyw       learned · 18
節能改善方案    jngsfa     learned · 9

[＋新增] [編輯] [停用] [刪除]
[匯入] [匯出]
```

Entry editor:

```text
詞語
台達能源

完整拼音
tai da neng yuan

簡拼
tdny

來源
手動加入

☑ 永久保留
```

The normal add flow asks only for Chinese text.

## 16. Privacy

Personal Lexicon can contain:

- names;
- company names;
- project names;
- customer terms;
- work vocabulary.

Therefore:

- local-only by default;
- no telemetry upload of phrases/readings;
- no cloud generation dependency;
- exports only on explicit user action;
- never commit a real user's Personal Lexicon to the public repository;
- tests must use synthetic fixture data.

## 17. Import / export

V0.2 should support at least:

- export the native versioned format;
- import the same format;
- duplicate merge with deterministic rules.

CSV can be added either in V0.2 or V0.2.x if the Settings implementation cost is small.

Import must validate:

- phrase non-empty;
- normalized full-Pinyin/initial keys valid;
- schema version;
- duplicate identity;
- maximum field lengths.

## 18. Migration policy

Every stored file contains a schema version.

Rules:

- migrations are one-way and deterministic;
- preserve the original file until a successful atomic replacement;
- unknown future schema versions fail closed/read-only rather than destroying data;
- malformed individual entries should be reported/skipped without losing healthy entries where possible.

## 19. V0.2 acceptance tests

### Key generation

1. known reading for 台達能源 -> `taidanengyuan` + `tdny`
2. known reading for 蔡耀文 -> `caiyaowen` + `cyw`
3. uppercase/tone representation normalizes deterministically
4. empty or malformed readings fail cleanly

### Polyphonic correctness

5. auto-learning uses the actual candidate reading rather than per-character guessing
6. manual ambiguous phrase can be pronunciation-corrected
7. corrected pronunciation regenerates both full and initials keys

### Manual persistence

8. manually added entry survives restart
9. manual entry never expires automatically
10. edit/delete/disable works
11. export/import round trip preserves identity and source metadata

### Auto promotion

12. one explicit selection increments pending count
13. canceled/preview candidate does not increment
14. threshold-1 does not promote
15. threshold promotes exactly once
16. future selections update the promoted entry rather than duplicating it

### Candidate behavior

17. `tdny` can return 台達能源 after manual add
18. `cyw` can return 蔡耀文 after promotion
19. valid exact CIN remains first by default when a Personal Lexicon phrase collides
20. without exact CIN collision, strong Personal Lexicon match may rank first
21. visible values are deduplicated across sources

### Privacy/data safety

22. no network access is needed
23. tests do not read/write the user's actual CIN or Personal Lexicon
24. corrupted/unknown schema does not overwrite the source file

## 20. Suggested V0.2 phases

### Phase A — model + persistence

- entry model
- store
- versioning/migration
- key indexes
- unit tests

### Phase B — reading/key generation

- selected-reading capture
- manual local reading resolution
- Pinyin normalization
- initials generation
- polyphone correction tests

### Phase C — auto promotion

- observation counter
- threshold policy
- explicit-selection hooks
- promotion/dedup lifecycle

### Phase D — candidate merger integration

- full-Pinyin lookup
- initials lookup
- source scoring
- exact-CIN protection
- dedup/provenance

### Phase E — Settings UI + import/export

- list/search
- add/edit/disable/delete
- threshold setting
- import/export
- backup/reset

### Phase F — Mac E2E

Verify real workflows:

```text
新增 台達能源
-> tdny
-> 台達能源

選擇 蔡耀文 >= threshold
-> cyw
-> 蔡耀文
```

and verify the exact-CIN priority rule with a real private CIN table without committing that table.
