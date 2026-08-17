---
spec: "blueprint/019"
type: "feature"
base_sha: "8a8445cd04eaa5ca59b3b6ba3d34c541dda5708e"
head_sha: "0f45526d07983e57e16269213c43676e66f3e546"
commits: "16"
commits_test: "0"
commits_feat: "11"
commits_fix: "1"
commits_refactor: "0"
files_changed: "17"
insertions: "1694"
deletions: "50"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "34898"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "634"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1744"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "33354"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3938"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "1227"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "2"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-21"
---

# Review: Partition split

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 5 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the 16-commit build (`8a8445c..0f45526`) of spec 047's `split` verb — five new deterministic script verbs, the blueprint `--split` arm, the gatherer split role, and the split protocol surfaces. All 19 ACs are covered with no omission and no scope creep, and every security boundary held under adversarial investigation. The `minor-drift` verdict is driven by five minor, actionable polish findings (a stale comment, an incomplete extension set that leaves the #77 over-match partially open, a gate-presentation parity gap, a now-stale blueprint invariant, and a named-but-thin test slice) — none affecting the shipped behavior's correctness.

## Alignment

### vs. Spec acceptance criteria
- AC 1–19 — **met.** An independent omission-sweep confirmed each AC is satisfied by shipped deterministic code + tests and/or the protocol surface. Strongest deterministic coverage: AC 11 (vacated-id floor + renumber wip-rides), AC 4 (revealed-edge `aggregate` floor + `edges-diff` identity), AC 8 (rewrite-refs whitelist + boundary), AC 17 (identity-check op=split arm). AC 3/5/6/9/10/13/14/15 are protocol-borne (the § Split protocol), consistent with the Bash-vs-Prompt split.
- AC 7/8 — **met with a narrow caveat:** the `rewrite-identity` narrowing (#77) closes the common extension set but leaves C-family/compiled-lang filename mentions over-matching (Finding 2).

### vs. Plan tasks
- Tasks 1–13 — **done, and only those.** No scope creep: no merge verb/arm (only the sanctioned forward-compat note), no code moves (commit-split has no code arm), no new config keys, no new health sensor (identity-check only *extended*). ARCHITECTURE.md was refreshed via the pipeline-owned `/jim:arch`, not hand-authored — not a deviation.

### vs. ARCHITECTURE.md
- Script-owned git primitives / no skill git grant — **respected** (move-spec-dir & commit-split live in jimledger.sh; zero allowed-tools change).
- Bash-vs-Prompt, never-execute-config, capability-backed read-only gatherer — **respected.**
- SKILL.md ≤ 500 lines — **respected** (partition & blueprint both at 500/500, gate-verified).
- "Comments describe current behavior only" — **violated** at `jimledger.sh` header (Finding 1).

## Investigation

### High-stakes regions investigated

#### jimledger.sh split primitives (move-spec-dir / vacated-max / commit-split)
- locations examined: `skills/review/scripts/jimledger.sh:386-548`; precedents `:190-233` (commit-map), `:259-369` (rename-tracked/commit-rename)
- callers/consumers traced: `jimfile.sh:337-347` (next-id → vacated-max); `partition-methodology.md` § Materialize (move-spec-dir/commit-split arg order)
- tests checked: `tests/jimledger.sh:1407-1586` (move / vacated / commit-split clusters)
- verdict: **satisfied** — move-spec-dir's containment is strictly tighter than rename-tracked (adds the specs-subtree constraint on top of worktree-top; symlink/`..`/absolute/prefix-confusion all closed); vacated-max is fail-closed and monotonic; commit-split is explicit-stage-only with dirt excluded.

#### jimpartition.sh split verbs (rewrite-refs / rewrite-identity / split-preflight / renumber-map / identity-check)
- locations examined: `skills/partition/scripts/jimpartition.sh:1015-1218, 1349-1464, 1485-1581, 1704-1726`
- callers/consumers traced: renumber-map MAP → rewrite-refs remap (methodology); the moved= wip-strip contract seam
- tests checked: `tests/jimpartition.sh:1499-1822`
- verdict: **satisfied** with one divergence — rewrite-refs (whitelist + boundary + guard-before-edit + location-only + idempotent) confirmed sound; the `rewrite-identity` extension exclusion is incomplete (Finding 2).

#### next-id vacated floor (machine-consumed ledger value — spec Insight 2)
- locations examined: `skills/file/scripts/jimfile.sh:77-81, 289-354`; `jimledger.sh:519-548`
- tests checked: `tests/jimfile.sh:184-255`
- verdict: **satisfied** — the first machine-consumed ledger value is re-gated (`^[0-9]{3}$`) before arithmetic, degrades cleanly (absent script / rc≠0 / empty → directory-only), and the >999 refusal admits no 4-digit id. AC 11's guarantee is best-effort (conditional on jimledger.sh present), as Insight 2 intends.

### Coverage

- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated via 4 read-only investigators (jimledger primitives, jimpartition verbs, next-id floor, AC-coverage/omission sweep) — all within the fanout cap of 10.

## Living intent

**Sensed:** 34 invariants · **holds:** 9 · **violations:** 2 (in-change 2 · pre-existing 0 · unlocalized 0) · **skipped:** 22 · **failed/unconfigured:** 1

Ran `/jim:verify --from-review` against the `jim` group's `000-blueprint` inline. The whole-group mechanical floor holds (`no-third-party-deps`); the judge rung was change-selected to the invariants this build touches and grounded in the review's own investigation evidence (bounded coverage, noted below). Two `in-change` violations surfaced — both blueprint/skill drift the build introduced, both routing to the Step-10 fork.

### Violations

- `ledger-commit-discipline` — critical · violated · in-change · `skills/review/scripts/jimledger.sh:30` — the invariant enumerates *five* path-scoped commit sites; the build added `commit-split` (a sixth) and `move-spec-dir` (a second non-committing git-mv primitive). The commit *discipline* is upheld (literal paths, `--` guard, never `git add -A`); the invariant's enumeration is stale → fold the intent.
- `gate-presentation` — high · violated · in-change · `skills/partition/SKILL.md:361` — the new § Split runs hard gate ("the single gate, spec 040") does not inline-reference the canonical gate-presentation rule the way § Rename runs does. `tests/gatepresentation.sh` uses a *minimum*-count assertion (≥4), so it did not catch the omission → fix the code (add the reference).

### Coverage

- appetite in force: low (judge everything within the change-selected set).
- Whole-group floor ran (`no-third-party-deps` holds; territory conformance is 348 files, all pre-existing scaffolding — no new stray from this build).
- judges: change-selected to the ~11 build-touched invariants; grounded in the 4 investigators' evidence rather than a redundant separate fan-out (bounded-coverage decision for a sensor nested in an already-deep review).
- skipped by scope: 22 (the change did not touch them) · skipped by appetite: 0.
- registry: `skill-line-budget` **unconfigured** (no operator command) — the ≤500 budget was independently gate-verified in build tasks 12/13.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 16 (0/11/1/0) |
| Files changed · insertions · deletions | 17 · +1694 · −50 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 34898s·634s·1744s·33354s·3938s·1227s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- **None identified.** Adversarial investigation confirmed every new trust boundary holds: move-spec-dir containment (specs-subtree + worktree-top), vacated-max / next-id fail-closed machine-consumption, rewrite-refs remap-as-whitelist + boundary rule + guard-before-edit, commit-split explicit-stage-only, and location-only output throughout. The security.md findings F1–F11 are all reflected in the shipped code.

## Findings

### 1. Stale `jimledger.sh` header comment

- **Priority:** medium
- **Description:** The file-header comment (`skills/review/scripts/jimledger.sh:~30-37`) still reads "commits in exactly **five** path-scoped places" and enumerates only five, omitting the new `commit-split` (sixth site) and `move-spec-dir` (second staging-only git-mv). Conflicts with the "comments describe current behavior only" convention.
- **Suggestion:** Refresh the header to "six" naming commit-split, and note move-spec-dir alongside rename-tracked.
- **Relates to:** ARCHITECTURE.md convention; Task 1/3.

### 2. `rewrite-identity` extension-exclusion set is incomplete (#77 partially open)

- **Priority:** medium
- **Description:** The #77 dotted-key narrowing excludes common web/config/doc/scripting extensions but omits the C-family/compiled-lang extensions the file's own `classify_ext` recognizes (`c`, `h`, `java`, `cpp`, `cxx`, `hpp`, `cs`, `php`, `kt`, `swift`, `scala`, `clj`, `hs`, `pl`, `lua`, `dart`, `r`). Concrete failure: under `rewrite`, a moved spec body containing `cart.java` is rewritten to `checkout.java` — the exact over-match #77 exists to close. Low severity (gate-diffed at the split gate, spec-body-only), untested.
- **Suggestion:** Align the `EXT` set (`jimpartition.sh:~1401`) with `classify_ext`'s source-extension list; add a `cart.java`/`cart.c` no-rewrite test case.
- **Relates to:** AC 7; issue #77.

### 3. § Split runs gate omits the inline gate-presentation reference

- **Priority:** medium
- **Description:** The § Split runs "single gate (spec 040)" step in `skills/partition/SKILL.md` does not inline-reference `skills/blueprint/references/gate-presentation.md`, unlike § Rename runs. `tests/gatepresentation.sh` asserts a *minimum* count (≥4, already met by the pre-existing references), so it did not flag the new gate.
- **Suggestion:** Add the rule reference to § Split runs step 4 (budget-permitting; SKILL.md is at 500/500).
- **Relates to:** ARCHITECTURE.md gate-presentation invariant; Task 12.

### 4. `jim` blueprint `ledger-commit-discipline` invariant is now stale

- **Priority:** medium
- **Description:** The living-intent sensor's in-change violation: the `jim` `000-blueprint` invariant enumerates five commit sites; the code now has six (`commit-split`). The discipline holds; the enumeration is stale.
- **Suggestion:** Fold the intent — update the invariant to say six and name commit-split (and note move-spec-dir as a second non-committing git-mv primitive), via the Step-10 blueprint update.
- **Relates to:** Living-intent sensor; AC 12/13.

### 5. AC-19 "remap ledger event round-trip" test is thin

- **Priority:** low
- **Description:** AC 19 names a remap-ledger-event round-trip; both halves are individually tested (write via the generic `event` verb; read via `vacated-max`/`next-id`), but no single test emits the op=split event and reads it back end-to-end, leaving the wip-number→`moved=` projection (the `-wip` strip) untested end-to-end. The `edges-diff` old==new identity specialization also has no dedicated test.
- **Suggestion:** Add a focused end-to-end round-trip test (emit `op=split` with `moved=` via `jimledger event`, then assert `next-id` floors past it).
- **Relates to:** AC 19.

## Deviations & feedback

- The build was clean and interruption-free across all stages; the sec stage ran twice by design (spec-lens then dual-lens), matching the SDLC chain. Every finding here is a minor polish item surfaced *by the review* on freshly-shipped code — the value of the adversarial investigator fan-out + the living-intent sensor was catching the gate-presentation parity gap and the incomplete #77 exclusion that the mechanical floors (minimum-count gate test, extension subset) each missed.
