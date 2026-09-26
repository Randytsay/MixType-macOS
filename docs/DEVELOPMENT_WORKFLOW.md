# MixType Development Workflow

This document defines the authoritative development workflow for MixType-macOS. It applies to human contributors and coding agents such as ChatGPT, CoS Mac, WebCodex, Codex, and other automation.

## 1. Source of truth

**GitHub is the single source of truth for code, specifications, development status, and handoff state.**

Do not treat a local workspace, an agent conversation, or a VPS checkout as authoritative when it differs from GitHub.

Before starting work, every developer/agent must reconcile the current repository state with GitHub.

## 2. Primary environments and responsibilities

### CoS Mac — primary macOS implementation and real-device validation

Use the local Mac workspace for work that depends on macOS or InputMethodKit:

- Xcode / Swift toolchain verification
- native build and packaging
- input-method installation
- macOS Settings UI
- InputMethodKit behavior
- candidate-window behavior
- loading and testing a real CIN/Boshiamy table
- real typing verification in macOS applications
- crash/performance/debug work that requires the actual IME runtime

The local Mac workspace is the primary runtime-validation environment, but it is **not** the source of truth. Completed work must be committed and pushed.

Recommended local path:

```text
~/Coding/MixType-macOS
```

### WebCodex VPS — long-running implementation and batch engineering

Use WebCodex for work that does not require live macOS IME interaction:

- repository-wide code analysis
- Swift refactors
- new OS-neutral modules
- unit/integration tests
- documentation
- migrations
- CI fixes
- PR preparation and reviewable engineering batches

WebCodex must not claim macOS InputMethodKit runtime validation unless it was actually performed on a Mac environment.

### ChatGPT — specification, architecture, review, and audit

Use ChatGPT primarily for:

- product requirements
- architecture decisions
- milestone decomposition
- acceptance criteria
- code-review reasoning
- reconciliation/audit
- cross-agent handoff design

Important decisions should be written back into GitHub documentation rather than existing only in chat history.

## 3. Mandatory reconciliation before work

Before any implementation task, inspect at least:

```text
git status
git branch --show-current
git log --oneline --decorate -n 20
git fetch --all --prune
git rev-parse HEAD
git rev-parse origin/main
```

Also inspect:

- the applicable specification under `docs/`
- `docs/DEVELOPMENT_STATUS.md`
- open PRs/issues when relevant
- current CI status when relevant

The agent must determine:

1. what GitHub says is complete;
2. what the code actually contains;
3. whether the working tree is clean;
4. whether local HEAD and remote state differ;
5. the first unfinished task in the current phase.

Do not rely only on a previous agent's narrative handoff.

## 4. Baseline before feature development

Before modifying the hybrid input engine, establish a clean Mac baseline.

The baseline must prove that the fork can:

1. build on the user's Mac;
2. install as a macOS input method;
3. coexist safely with the user's existing OpenVanilla installation;
4. load the user's CIN/Boshiamy table;
5. perform normal cassette/CIN input without MixType-specific hybrid changes;
6. run the relevant package tests.

If baseline validation fails, fix or document the baseline issue before attributing failures to MixType feature work.

## 5. Branch strategy

`main` is the stable integration branch and should not be used as a scratch branch.

Recommended milestone branches:

```text
feat/hybrid-input-v01
feat/personal-lexicon-v02
feat/mixed-token-v03
feat/backup-restore-v04
```

For larger milestones, smaller task branches may branch from the milestone branch when useful.

Before starting:

```text
git fetch --all --prune
git switch <target-branch>
git pull --ff-only
```

Avoid unrelated changes in the same branch.

Released milestone branches are merged into `main` only after applicable unit/build/runtime gates pass.
MixType release tags use the fork-specific form `mixtype-vX.Y.Z` so they do not collide with upstream
vChewing's `4.x.y` version/tag line. A release tag must point at the exact tested `main` commit, and
release notes must state signing/notarization status accurately. Never attach private CIN, Personal
Lexicon, learning data, preferences exports, or `.mixtypebackup` files to a public release.

## 6. Work in reviewable phases

Do not implement an entire milestone as one opaque change.

Each milestone is divided into phases with explicit acceptance criteria.

For example, V0.1 Hybrid Input is expected to proceed approximately as:

```text
Phase A — Hybrid mode plumbing
Phase B — CIN + Pinyin candidate providers and merge
Phase C — candidate-selection semantics / Homa integration
Phase D — Settings UI
Phase E — regression, CI, and real macOS IME validation
```

An agent should normally complete one coherent phase or one reviewable batch at a time.

## 7. Commit and push discipline

For every completed batch:

1. run the relevant tests;
2. review `git diff`;
3. ensure no unrelated files are included;
4. commit with a descriptive message;
5. push the branch;
6. update `docs/DEVELOPMENT_STATUS.md`.

Do not leave important completed work only in an uncommitted local workspace.

Suggested commit style:

```text
feat: add hybrid cassette-pinyin typing mode
test: cover hybrid candidate ordering
fix: preserve cassette exact-candidate priority
docs: update V0.1 development status
```

## 8. Validation gates

A change is not considered fully complete only because the code compiles.

Use the strongest applicable gate:

### Gate A — static / unit validation

- package builds
- unit tests
- deterministic fixtures

### Gate B — CI validation

- GitHub CI passes for the branch/PR
- no unexplained skipped required checks

### Gate C — macOS runtime validation

Required for behavior touching:

- InputMethodKit
- input state transitions
- candidate windows
- keyboard event handling
- settings UI
- installation
- CIN file loading
- real typing behavior

Gate C must be performed on a Mac.

## 9. Definition of done for a development batch

A batch is done only when all applicable items are true:

- implementation matches the current specification;
- tests were added or updated where appropriate;
- relevant tests pass;
- no known regression is hidden;
- changes are committed;
- changes are pushed;
- development status is updated;
- limitations or unverified runtime behavior are explicitly recorded.

For milestone completion, also require the milestone acceptance criteria and real Mac validation where applicable.

## 10. Agent handoff protocol

A handoff must be recoverable from GitHub without access to the previous conversation.

The receiving agent should be able to determine the next action from:

- repository history;
- applicable spec;
- `docs/DEVELOPMENT_STATUS.md`;
- CI/PR state.

A good handoff records:

```text
Current milestone
Current phase
Completed items
Current branch
Latest commit
Tests run
Known issues / blockers
Mac runtime validation status
Next unfinished item
```

Do not store secrets, tokens, credentials, or private CIN content in GitHub documentation.

## 11. CoS Mac ↔ WebCodex collaboration rule

When work moves between CoS Mac and WebCodex:

1. the first environment finishes a coherent batch;
2. tests are run;
3. changes are committed and pushed;
4. status is updated;
5. the second environment fetches and reconciles before editing.

Never assume two environments can safely edit the same unpushed branch state simultaneously.

## 12. Upstream discipline

MixType is forked from vChewing.

When useful, upstream changes may be studied or integrated, but:

- do not overwrite MixType-specific behavior blindly;
- keep MixType product identity separate from vChewing;
- preserve all required copyright and license notices;
- review conflicts involving InputHandler, Homa, Tekkon, LexiconAssembly, SettingsUI, and cassette code carefully.

## 13. Privacy and local-first design

MixType's personal lexicon, learned vocabulary, names, and typing statistics may contain sensitive user information.

Default design principles:

- local processing first;
- no cloud dependency for core typing;
- no automatic upload of personal lexicon data;
- explicit user action for export/sync;
- do not commit personal dictionaries or user-specific CIN files to the public repository.

## 14. Canonical documents

At minimum, use these documents:

- `README.md` — product overview and public project description
- `AGENTS.md` — repository-wide technical instructions for coding agents
- `docs/DEVELOPMENT_WORKFLOW.md` — this collaboration/workflow policy
- `docs/DEVELOPMENT_STATUS.md` — current implementation and handoff state
- `docs/MIXTYPE_V0.1_HYBRID_PLAN.md` — V0.1 technical specification

Future milestone specs should follow the same pattern.
