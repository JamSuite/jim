---
spec: "platform/009"
type: "feature"
base_sha: "ea225c8569d2d499662eb17e68b9123b3f433c83"
head_sha: "61a789125d2c697825fe8b820a9fdae5b36611ff"
commits: "8"
commits_test: "0"
commits_feat: "5"
commits_fix: "1"
commits_refactor: "0"
files_changed: "4"
insertions: "741"
deletions: "55"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3902"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "726"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "4378"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4232"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2412"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "515"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-27"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Provisional allocation and reconcile (unreachable-origin mode)

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the `platform/009` build over `ea225c8..61a7891` (8 commits; code in `skills/file/scripts/jimalloc.sh` + `tests/jimalloc.sh`). All 13 spec ACs are fully satisfied, the 7 plan tasks were done and only those tasks (no scope creep, no consumer wired), and jim's script conventions hold. One low-severity robustness finding surfaced (a high-water computation that filters registry records more strictly than `alloc_next_num_issue`). The living-intent sensor is clean: every checked platform invariant holds.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (provisional mode adds behavior; fail/local unchanged) — met.
- AC 2 (grammar disjoint; never in registry/next-id/peek; marker→ordinal independence) — met.
- AC 3 (issuance local, origin-free, no CAS) — met.
- AC 4 (reconcile realizes via the same guarded CAS path; no weaker writer) — met.
- AC 5 (atomic, all-or-none single commit) — met.
- AC 6 (resumable, idempotent) — met.
- AC 7 (still-unreachable is a clean no-op) — met.
- AC 8 (deterministic under concurrency; ordinal from high-water only) — met.
- AC 9 (preview-then-apply) — met.
- AC 10 (abandoned provisional → permanent gap) — met (by construction; covered structurally, no dedicated fixture).
- AC 11 (consumer contract defined + frozen; no real consumer wired) — met (`skills/issue/scripts/*` untouched; fixture stands in).
- AC 12 (every provisional/pending/subject token revalidated before git/ref/fs use) — met.
- AC 13 (bash conventions; parse as data; no third-party deps) — met.

### vs. Plan tasks
- Task 1 (consolidate publish → `alloc_publish`, closes #122 erosion gap) — done.
- Task 2 (accept `provisional` in preflight) — done.
- Task 3 (provisional grammar + provisional-mode allocate) — done.
- Task 4 (reconcile realize, pure) — done.
- Task 5 (reconcile publish + tiers) — done.
- Task 6 (reconcile preview-then-apply) — done.
- Task 7 (full-suite green) — done (788 aggregate tests pass).
- Scope creep: none. Only the two manifest files changed among source; the issue emitter was correctly not touched.

### vs. ARCHITECTURE.md
- Scripting Layer (`set -uo pipefail`, `export LC_ALL=C`, `GIT_TERMINAL_PROMPT=0`, Bash+POSIX, no third-party deps) — respected.
- Single `is_valid_id` boundary (no fourth copy) — respected; every new token routes through `alloc_valid_token`.
- Operational-git discipline (`--end-of-options`, fixed refs/paths, plumbing-only publish) — respected.
- The allocator entry was refreshed for the provisional mode, the `reconcile` verb, and the shared `alloc_publish` (pipeline-owned arch refresh).

## Investigation

### High-stakes regions investigated

#### Security / injection boundary (AC 12, AC 2, AC 3)
- locations examined: `jimalloc.sh:944-966` (provisional issuance), `:344-387` (reconcile realize), `:1319-1340` (publish builder → `alloc_encode_allocate_issue`), `:902-925` (reachability probe), `:1126-1152` (`alloc_seed_commit` git sinks).
- callers/consumers traced: provisional/reconcile helpers are private to the allocator; no external skill consumes them (only the `allocate`/`reconcile` subcommands).
- tests checked: `tests/jimalloc.sh:642` (crafted group rejected), `:1151` (crafted pending rejected), `:574`/`:594` (grammar-distinct offline issuance).
- verdict: satisfied — every untrusted token (subject-derived id, pending identity, replayed registry field, config branch) is revalidated at `alloc_valid_token` → `jimfile.sh valid-id` before any git/ref/path use; validated tokens reach only stdout, assoc-array keys, and `git hash-object` blob content, never an argv/ref/path. No bypass.

#### `alloc_publish` seed-refactor regression (Task 1, Finding 1)
- locations examined: `jimalloc.sh:1197-1269` (`alloc_publish`), `:1277-1294` (seed builder), `:1299-1306` (`alloc_seed_land`), `:1220-1240` (erosion re-check).
- tests checked: `tests/jimalloc.sh:1062` (new seed-publish erosion detection), plus the full `case_jimalloc_seed_*` set (fresh/idempotent/partial-skip/single-commit/baseline-arm).
- verdict: satisfied — seed's observable behavior is faithfully preserved (empty-precondition, already-seeded abort, one commit, baseline arming, skip messages); the added in-loop byte-prefix erosion re-check is correct and now covers both logs; the builder→`alloc_publish` dynamic-scope contract is sound under `set -uo pipefail`; the no-op branch cannot swallow a seed error (seed returns 1 first).

#### Reconcile correctness (AC 4/5/6/7/8/10, Finding 4)
- locations examined: `jimalloc.sh:344-387`, `:1319-1340`, `:1353-1405`, `:1197-1269`.
- tests checked: `tests/jimalloc.sh:1173` (durable publish), `:1187` (single commit), `:1202` (concurrent distinct), `:1225` (resume no double-allocate), `:1243` (still-offline no-op), `:1143`/`:1293` (within-batch dup halt).
- verdict: partial — all named ACs satisfied (find-or-allocate is idempotent/resumable; ordinal derives solely from the high-water; concurrency serializes on the CAS; within-batch duplicates halt), with one low-severity divergence recorded as Finding 1.

#### AC coverage / omission & scope sweep
- locations examined: full `spec.md` (13 ACs), `plan.md` (tasks + coverage table), `jimalloc.sh`, `tests/jimalloc.sh`; `skills/issue/scripts/*` (confirmed untouched).
- verdict: satisfied — all 13 ACs met, no omission of implied changes to untouched code, no scope creep, `skills/issue/scripts/*` untouched (AC 11), Security Findings 1 and 4 both built with fixtures.

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated via 4 parallel investigators; no fan-out cap reached (4 of 10).

## Living intent

**Sensed:** 9 invariants · **holds:** 4 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 5 · **failed/unconfigured:** 0

### Violations
- None — every checked invariant holds. Territory-conformance note below.

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran (territory declared): `no-third-party-deps` (critical) holds.
- judges: change-selected, all within cap — `no-source-eval` (critical), `ref-validation` (critical), `tests-under-tests` (medium) all hold (3 of 10).
- skipped by scope: 5 (`script-preamble`, `bash-source-relative`, `relpath-validation`, `ledger-commit-discipline`, `blueprint-slot-reserved` — a `jimalloc.sh` change does not touch them) · skipped by appetite: 0.
- registry: 0 configured. Contract-edge phase did not run — `platform` provides `jimconf-cli`/`jimfile-cli`/`jimledger-cli`/`testlib`, none of which the build touched (`jimalloc.sh` is not a declared provider entry).
- Territory conformance: 1 stray — `tests/jimalloc.sh` falls outside the map's declared `platform` territory, which lists the sibling test files (`tests/jimconf.sh`, `tests/jimfile.sh`, `tests/jimledger.sh`, `tests/metatest.sh`) but omits `tests/jimalloc.sh`. Pre-existing map-completeness gap (the file predates this build); offered as an issue.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (0/5/1/0) |
| Files changed · insertions · deletions | 4 · +741 · -55 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3902s·726s·4378s·4232s·2412s·515s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. Provisional issuance is strictly local (no new network sink); reconcile reuses the shared-ref CAS. The security-boundary investigation confirmed every untrusted token is revalidated before any git/ref/path use, so no injection surface was introduced.

## Findings

### 1. Reconcile's high-water filter is stricter than `alloc_next_num_issue`

- **Priority:** low
- **Description:** `alloc_reconcile_realize` (`jimalloc.sh:349-355`) counts an `issue allocate` ordinal toward the high-water only when the record's full-id (`c4`) passes `alloc_valid_token`, whereas `alloc_next_num_issue` (`:287-292`) counts any numeric ordinal (`c3`) regardless of `c4`. The two therefore disagree on the next ordinal in the presence of a malformed record (numeric ordinal but boundary-invalid full-id). Concretely, with a hostile appended `issue allocate 2 -bad …` record present alongside a valid one, a normal `allocate issue` counts ordinal 2 while `reconcile` skips it — reconcile can realize a provisional onto display ordinal 2, duplicating the malformed record's ordinal. Bounded: reconcile still counts every *validly-held* ordinal so it never reissues a real id, ids carry no authority (platform/007 non-goal), and the trigger requires push access to the branch-writable log (the same surface the erosion guard defends, though the guard does not catch an appended malformed record). AC 8 is not violated — the ordinal still derives solely from the registry high-water, just via a stricter record filter.
- **Suggestion:** Count `c3` toward `max` whenever it is numeric, independent of the `c4` validity gate (keep `existing[$c4]` keyed only on a valid `c4`), so the two high-water computations agree. One-line change in `alloc_reconcile_realize`.
- **Relates to:** AC 8; `alloc_next_num_issue`

## Deviations & feedback

- Clean, low-friction build: 0 interruptions across every stage, all 7 tasks landed first-pass, 788 aggregate tests green. The security phase ran twice (spec + plan lenses) and its Findings 1 and 4 were both folded into the plan and built with fixtures — the design-time security loop paid off (no security regressions at review).
- The one finding and the territory stray are both pre-existing/latent rather than build-introduced, consistent with an aligned build. The territory stray (map omits `tests/jimalloc.sh`) is worth a small map correction so platform's territory lists all its tests uniformly.
