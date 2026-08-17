---
spec: "platform/004"
type: "refactor"
base_sha: "4243d290a25b234e88ce891344876b5481eaba64"
head_sha: "31d1f96ad15669038014bb7eaa5c0ccad3377b71"
commits: "15"
commits_test: "0"
commits_feat: "2"
commits_fix: "0"
commits_refactor: "5"
files_changed: "29"
insertions: "235"
deletions: "99"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "2035"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "563"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "739"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1274"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2896"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "187"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "5"
security_regressions: "0"
invariant_violations: "0"
contract_violations: "0"
alignment: "aligned"
date: "2026-07-25"
---

# Review: Relocate jimledger.sh to a dedicated platform home

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 5 · **Security regressions:** 0

Reviewed the `platform/004` build over `4243d29..31d1f96` (15 commits, +235/−99 across 29 files): the `git mv` of `jimledger.sh` into a platform-owned `skills/ledger/` home, the reference sweep across every live consumer, the additive read-only `events` verb, the `/jim:ledger` inspector, and the blueprint/partition reconciliation. **All eight acceptance criteria are fully satisfied; the build aligns with spec, plan, and architecture.** Every plan deviation was surfaced mid-build and developer-approved — corrections to plan under-specification, not uncontrolled scope creep. The living-intent sensor over the platform group is clean (0 invariant, 0 contract violations).

## Alignment

### vs. Spec acceptance criteria
- **AC1** (new home, history preserved) — met. `git mv` recorded as a rename (`skills/{review => ledger}/scripts/jimledger.sh`, 2 lines changed).
- **AC2** (no carve-out; `skills/ledger` wholesale platform territory) — met. Carve-out removed from `BLUEPRINT.md`, `platform/000-blueprint`, and `sdlc/000-blueprint`; `skills/ledger` declared platform territory and confirmed covered by the floor's territory scan (0 strays).
- **AC3** (live consumers resolve new home; frozen + `ARCHITECTURE.md` excluded) — met. Grep-clean across `skills/`, `agents/`, `tests/`, `BLUEPRINT.md`, `docs/features/`, `WORKFLOW.md`, `README.md`, and the refreshed `ARCHITECTURE.md`; frozen historical artifacts and this spec's own records correctly retain the old path.
- **AC4** (CLI behavior unchanged) — met. The `jimledger.sh` diff is additive-only (the sole removal is the self-header path line); 133 pre-existing test cases pass byte-identically.
- **AC5** (read-only `/jim:ledger` skill; events/metrics/trend; no mutating verbs) — met. `skills/ledger/SKILL.md` surfaces five read verbs; mutating/diff verbs absent.
- **AC6** (capability-enforced boundary) — met. Five verb-scoped own-skill grants, no blanket `jimledger.sh *`, no mutating/diff verb in the grant set.
- **AC7** (conforms to plugin conventions) — met. `name` matches dir, no `agent:` binding (mirrors `/jim:conf`/`/jim:file`), 64 lines (≤ 500), sigil discipline.
- **AC8** (tests pass; only path constants updated) — met. Test diffs are the two path constants (`tests/jimledger.sh:3,:23`, `tests/jimpartition.sh:19`) plus four additive `events` cases; no existing assertions changed.

### vs. Plan tasks
- Tasks 1–10 all done. The build did the plan's tasks and only the plan's tasks — with five surfaced, approved corrections to plan under-specification (see Deviations & feedback), no unauthorized additions.

### vs. ARCHITECTURE.md
- Scripting Layer (`BASH_SOURCE`-relative composition) — respected; only the relative hop changed. Confirmed by the `bash-source-relative` judge.
- allowed-tools exactness (exact verb-scoped paths, never bare `Bash(bash *)`) — respected.
- No third-party deps / no `source`/`eval` of data / `set -uo pipefail` — respected; the `events` verb is POSIX `awk`. Confirmed by the `no-source-eval` judge.
- `/jim:conf`/`/jim:file` wrapper shape (no `agent:`) — respected. `ARCHITECTURE.md` itself refreshed via `/jim:arch` at the completion gate.

## Investigation

### High-stakes regions investigated

Depth `thorough`, but this change class — a path-relocation refactor plus one additive parse-only verb — has **deterministically verifiable** ground truths, so the ACs were verified mechanically (grep-completeness for the omission class, git-diff for behavior preservation, capability-grant inspection) rather than by a broad investigator fan-out. The living-intent sensor dispatched three `Agent(judge)` subagents.

#### AC3 — the omission class (did every live consumer change?)
- locations examined: repo-wide grep for `skills/review/scripts/jimledger.sh` across `skills/`, `agents/`, `tests/`, `BLUEPRINT.md`, `docs/features/`, `WORKFLOW.md`, `README.md`, `ARCHITECTURE.md`
- callers/consumers traced: 10 consumer skills + `agents/reviewer.md` + `reconcile-methodology.md` (46 sites), `review/SKILL.md` own→cross-skill flip (8 sites), 2 `BASH_SOURCE` resolvers, 2 test path constants
- verdict: satisfied — live surface grep-clean; frozen history + `ARCHITECTURE.md` correctly excluded

#### AC4 — behavior preservation (CLI unchanged)
- locations examined: `git diff 4243d29..HEAD -- skills/ledger/scripts/jimledger.sh`
- tests checked: `tests/jimledger.sh` (133 pre-existing cases green; 137 total with the 4 additive events cases)
- verdict: satisfied — additive-only diff; no pre-existing verb logic touched

#### events verb + `/jim:ledger` capability boundary (AC5/AC6, security)
- locations examined: `skills/ledger/scripts/jimledger.sh` `cmd_events` + dispatch; `skills/ledger/SKILL.md` allowed-tools
- verdict: satisfied — `cmd_events` parses `ledger.md` with `awk` only, reuses sibling dir/ledger guards (rc 2); grants are five verb-scoped read verbs with 0 blanket/mutating/diff patterns (security Finding 3 + Findings 1–2 discharged)

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set verified; no fan-out cap reached. Mechanical verification substituted for investigator fan-out on the deterministic ground truths (documented above).

## Living intent

**Sensed:** 7 invariants · **holds:** 4 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 3 · **failed/unconfigured:** 0

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran (territory declared; no `UNSCOPED`). `no-third-party-deps` (pattern) holds.
- judges: change-selected, all within cap — 3 ran (`no-source-eval` ✓ critical, `bash-source-relative` ✓ high, `ledger-commit-discipline` ✓ critical).
- skipped by scope: 3 — the change did not touch `ref-validation`, `blueprint-slot-reserved`, `tests-under-tests` · skipped by appetite: 0.
- registry: 0 configured (no `registry:` invariants). Territory conformance: 0 platform strays; `skills/ledger` correctly covered by the new territory declaration.

### Contracts

**Edges checked:** 2 · **holds:** 2 · **violations:** 0 (provider-side 0 · consumer-side 0)

- None — every checked edge holds. The `platform.jimledger-cli` provider edges (`sdlc → platform`, `blueprint → platform`) hold: consumer references resolve to the new provider path and the provider surface is additive-only. Contract floor emitted only `CROSS-REF` evidence + `COVERAGE 4 4`; no `BREAKING`/`LEAK`.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 15 (0/2/0/5) |
| Files changed · insertions · deletions | 29 · +235 · −99 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 2035s·563s·739s·1274s·2896s·187s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

*Note: `commits_test=0` because the four `events` test cases rode the `feat(ledger): add read-only events verb` commit (a green-on-its-own additive unit) rather than a separate `test:` commit.*

## Security regressions

- None identified. The additive `events` verb parses the untrusted ledger with `awk` (never `source`/`eval`) and reuses the sibling spec-dir/ledger guards (rc 2 on a missing dir/ledger) — security Finding 3, verified. The `/jim:ledger` read-only boundary is capability-enforced (verb-scoped grants exclude the mutating and raw-diff verbs) — security Findings 1–2, verified. No secrets, no weakened trust boundary, no new injection surface.

## Findings

### 1. Plan blast-radius under-specified two live-surface references

- **Priority:** low
- **Description:** The plan's task breakdown named `tests/jimledger.sh` for the test path constant and `BLUEPRINT.md` + `platform/000-blueprint` for the carve-out, but the same live references also lived in `tests/jimpartition.sh:19` (a second `SCRIPT_JIMLEDGER` constant) and `sdlc/000-blueprint` (two carve-out mentions, required by AC2's "either group blueprint"). Both were caught during the build — the first by task 2's own Verify, the second by reading AC2 against the tree — and folded in with developer sign-off. No shipped defect resulted; the signal is about research/plan blast-radius completeness for cross-cutting relocations.
- **Suggestion:** For file-relocation refactors, have `/jim:research` sweep for *all* hard-coded path constants (not just the primary test) and enumerate every blueprint doc a carve-out touches, so the plan's file manifest is exhaustive up front.
- **Relates to:** Task 2, Task 9, AC2, AC8

## Deviations & feedback

All five deviations from the plan-as-written were surfaced mid-build and developer-approved — the process worked as intended (each course-correction was raised, not silently absorbed):

- **Task 2 extended to `tests/jimpartition.sh:19`** — a second hard-coded ledger path constant the plan named only for `tests/jimledger.sh`; forced by task 2's own Verify (`bash tests/jimpartition.sh`), an AC8-sanctioned path-constant update.
- **Task 7's Verify regex amended** — the plan's `jimledger.sh (event|diff|files)` false-positived on the required `events` read verb (`event` is a prefix of `events`); fixed with a word boundary (`\b`) after approval, since the file could not otherwise satisfy both the Verify and AC5.
- **Task 8 extended to the feature-doc verb inventory** — added `events` to `docs/features/ledger.md`'s Read-verb table so the inventory stayed truthful about the verb the build added.
- **Task 9 extended to `sdlc/000-blueprint` + an additive Provides refresh** — AC2 requires the carve-out gone from *both* group blueprints; the platform Provides face also gained `events` + `/jim:ledger` to reflect current state. All three blueprint docs were reconciled through the `/jim:blueprint` surface (one graph-neutral reconcile: 21 edges unchanged).
- **Completion-gate doc-consistency (`WORKFLOW.md`, `README.md`)** — two hand-maintained user-facing docs the pipeline does not auto-refresh were left stale by the move; fixed inline (the candidate batch was then empty).

Process note: the interrupted `sec` stage shows `sec_runs=2` because security review ran twice (spec-phase then plan-phase dual-lens) by design, not a re-run after failure.
