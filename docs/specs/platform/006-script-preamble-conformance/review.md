---
spec: "platform/006"
type: "refactor"
base_sha: "7acf1146e0a0225f49215afc1cbb4ee0dfc943ea"
head_sha: "529ee2b30ece4b2a0679983ea556f0d1878154ef"
commits: "6"
commits_test: "0"
commits_feat: "0"
commits_fix: "0"
commits_refactor: "1"
files_changed: "11"
insertions: "113"
deletions: "14"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "2328"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "290"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1746"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1174"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1679"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "93"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-26"
---

# Review: Script-preamble conformance and invariant restoration

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 0 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build over `7acf114..529ee2b`. The code change is small and self-contained — `set -uo pipefail` added directly to three previously source-inheriting scripts, plus a new fail-closed corpus sweep (`tests/scripthygiene.sh`); the rest of the range is docs (issue closes, the blueprint restore, plan marks, ledgers). All five acceptance criteria are fully satisfied; the living-intent sensor confirms `script-preamble` now holds in code.

## Alignment

### vs. Spec acceptance criteria
- AC1 (every first-party script sets the preamble directly) — **met**: the 3 holdouts fixed; the omission check confirms no tracked `.sh` falls outside the guard's 3 roots.
- AC2 (a deterministic test fails on omission) — **met**: `tests/scripthygiene.sh` was demonstrated Red (naming the 3 holdouts) before Green; the fail-closed per-root assertions are present and passed.
- AC3 (`script-preamble` row restored as `judge`, withhold note removed) — **met**: verified in `docs/specs/platform/000-blueprint/spec.md`.
- AC4 (issue #99 closed) — **met**.
- AC5 (existing tests pass unmodified) — **met**: 708/708 pass.

### vs. Plan tasks
- Tasks 1–4 — **all done, no scope creep**: exactly the 3 scripts + 1 new test + the blueprint restore + the #99 close; no unplanned files touched.

### vs. ARCHITECTURE.md
- `set -uo pipefail` (not `set -e`) — **respected**. Bash + POSIX only (`grep`/`awk`/glob) — **respected**. Tests under `tests/` — **respected**. Blueprint maintained via `/jim:blueprint` (not hand-edited) — **respected**.

## Investigation

### High-stakes regions investigated
No fan-out (0 investigators): the diff has no changed signatures, exported symbols, trust boundaries, untrusted-input parsing, command construction, or secret handling. Two checks the diff cannot show were run inline:

#### AC1 omission class — guard scope coverage
- locations examined: `git ls-files '*.sh'` vs the guard's roots (`skills/*/scripts`, `tests/`, `scripts/`)
- verdict: satisfied — zero tracked `.sh` outside the 3 roots, so the invariant's scope has no blind spot.

#### New helpers reuse
- locations examined: `skills/meta-test/scripts/testlib.sh:101-214`
- verdict: satisfied — `first_exec_line`/`matches`/`yn`/`check_files` do not duplicate any testlib helper (`assert_*`/`fixture`/`empty_dir`/`run_discovered_cases`).

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set assessed (empty by triage); no fan-out cap engaged.

## Living intent

**Sensed:** 9 invariants · **holds:** 2 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 7 · **failed/unconfigured:** 0

### Violations
- None — every checked invariant holds. `no-third-party-deps` (critical, floor) holds; `script-preamble` (high, judge) holds — all 18 first-party scripts set the preamble directly, and the conditional `LC_ALL=C` clause holds for the 3 locale-sensitive scripts.

### Coverage
- appetite in force: low (thorough).
- Whole-group floor ran (territory declared).
- judges: change-selected, within cap — 1 judge ran (`script-preamble`).
- skipped by scope: 7 (the change does not touch `no-source-eval`, `bash-source-relative`, `ref-validation`, `relpath-validation`, `ledger-commit-discipline`, `blueprint-slot-reserved`, `tests-under-tests`) · skipped by appetite: 0.
- registry: 0 configured. Contract-edge phase did not fire — the change touched no provides-side contract surface (CLIs and testlib interface unchanged; only a behavior-neutral preamble in the runner).
- Territory note: the sensor surfaced `tests/scripthygiene.sh` as a platform stray — already tracked as issue #110 (not re-filed).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 6 (0/0/0/1) |
| Files changed · insertions · deletions | 11 · +113 · -14 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 2328s·290s·1746s·1174s·1679s·93s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change adds fail-fast hardening (`set -uo pipefail`) and a drift-detection control; it introduces no new input-handling, trust boundary, or secret surface. The design-time security review's one Notable (guard could pass vacuously) was routed pre-build and is live in the shipped code (fail-closed per-root assertions).

## Findings

No findings — the build aligns with spec, plan, and architecture.

## Deviations & feedback

- The plan-phase security review earned its keep: the dual-lens pass caught a vacuous-pass design gap in the guard before any code was written, and the fix (fail-closed per-root assertions) shipped and was verified on the real run. Two `/jim:sec` runs (spec-only, then spec+plan) is the intended shape for a spec whose risk lives in the plan's test design.
- The one follow-on (#110) is a territory-declaration gap inherent to adding a new tracked file in a partitioned project — group-tier `/jim:blueprint` does not update project-tier territory; a project-tier map update is the human-owned step.
