---
spec: "jim/051"
type: "bug"
base_sha: "b0135f0581ee6e11a794625d9a3d4f5d3590c032"
head_sha: "175bc92d5fba77332002d694bb8fa1a5fd243f09"
commits: "7"
commits_test: "3"
commits_feat: "0"
commits_fix: "1"
commits_refactor: "0"
files_changed: "7"
insertions: "154"
deletions: "24"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "1438"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "708"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1028"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1185"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1763"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "533"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-23"
---

# Review: Partition ref sweep mis-rewrites typed refs on renumbering moves

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 0 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the build over `b0135f0..175bc92` (7 commits, 7 files, +154/−24): an opt-in `--skip-typed-refs` flag on `rewrite-identity` plus additive regression tests and the split/merge prose alignment. Every acceptance criterion is fully satisfied — verified by execution (both defect manifestations reproduced pre-fix and confirmed fixed post-fix), an adversarial code read, and the full 697-test suite green with the test file provably additions-only. No drift, no scope creep, no security regression.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (typed refs land on post-materialize id — group + number per remap) — **met**: composed split case asserts `checkout/001`, merge case asserts `target/008`; empirical repro M1 `target/002 → target/008`.
- AC 2 (extraction arm: remainder refs untouched) — **met**: composed split case asserts `cart/005` survives; empirical repro M2 `child/005 → old/005`.
- AC 3 (rename unchanged; existing tests pass unmodified) — **met**: unflagged characterization case pins today's behavior; full suite green; `tests/jimpartition.sh` diff vs baseline has 0 removed/modified lines (additions-only).
- AC 4 (documented order agrees with the engine's guarantee) — **met**: split/merge canonical invocation lines carry the flag; division-of-labor prose added to both sweep-assembly sections; prose-pin test guards it; rename invocations correctly left unflagged.
- AC 5 (regression covers both arms and both manifestations) — **met**: composed split case (M1 stale-number + M2 remainder-mispoint) and merge case (M1).

### vs. Plan tasks
- Tasks 1–7 — **all done, only these**: Reproduce, Red, Green, composed regression, doc alignment, prose-pin, full-suite + additions-only. No functionality, error handling, or optimization beyond the plan. The `ARCHITECTURE.md` refresh was gate-owned (plan Out of Scope) and landed post-`head_sha`, outside this range; the filed `deps_command` follow-on is a candidate-batch discovery, not scope creep.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt (deterministic work in scripts) — **respected**: the fix is a script flag; no LLM judgment added.
- No spec/AC/issue IDs in `skills/*/scripts/` comments — **respected**: the new script comments state behavior only; spec-051/AC references live in `tests/jimpartition.sh` (outside the rule's scope, per the test-file convention).
- Guard-before-any-edit containment, rc contract, location-only output, slug-gated awk inputs — **respected**: all unchanged; the flag only narrows the identity rewrite.

## Investigation

### High-stakes regions investigated

#### `cmd_rewrite_identity` `--skip-typed-refs` (jim's first in-place mutating verb)
- locations examined: `skills/partition/scripts/jimpartition.sh:1654-1780` (flag parse `:1661-1664`, awk binding `:1716`, typed branch `:1762`, usage `:68`, header `:1645-1656`); callers `skills/partition/SKILL.md:312/369/425`, `references/partition-methodology.md:307/498/687`.
- callers/consumers traced: no bash caller — dispatch `:2088` passes args verbatim; runtime callers are skill-prose invocations. Rename (`SKILL.md:312`, `methodology:307`) pass no flag (unchanged); split/merge (`:369/:425/:498/:687`) pass it — the complete omission-class set, all correct.
- tests checked: `tests/jimpartition.sh:1624-1649` (flag on/off unit), `:1932-1968` (composed split + merge), `:1977-1983` (prose-pin).
- verdict: **satisfied** — one adversarial investigator confirmed fail-closed parsing (only the exact literal is a flag; any other leading token hits the slug gate → rc 2), narrows-only (guard/rc/output untouched), awk boolean correctness (strnum `!skiptyped`, scan-index advance safe), and no new injection surface (flag literal never interpolated).

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set investigated (one region; one investigator). The five ACs were verified by execution + spine rather than per-AC fan-out — runtime evidence (empirical repro, full suite, additions-only proof) is stronger than a code-read for those.

## Living intent

**Sensed:** 35 invariants · **holds:** 4 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 30 · **failed/unconfigured:** 1

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: low (no per-group override).
- Whole-group floor ran (territory declared: `skills/`, `agents/`, `tests/`); `no-third-party-deps` holds; territory conformance: 0 strays, 399 scaffolding files bucketed (informational, single-group by design).
- judges: change-selected, all within cap (3 of 3 judged, cap 10) — `partition-registry-boundary`, `no-source-eval`, `untrusted-content` (all critical, all hold).
- skipped by scope: 30 (the change did not touch them) · skipped by appetite: 0 (appetite low judges everything selected).
- registry: 0 configured — `skill-budget` (`registry:skill-line-budget`) reported unconfigured, executed nothing.
- contract-edge phase: not run — the map's graph has no edges (single-group project; `jim` is named as provider by nothing).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 7 (3/0/1/0) |
| Files changed · insertions · deletions | 7 · +154 · −24 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 1438s·708s·1028s·1185s·1763s·533s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change adds a fixed-literal flag that only narrows the identity rewrite; the guard pass, rc contract, location-only output, and slug-gating of awk inputs are byte-unchanged, and `skiptyped` (0/1) is never interpolated into an awk pattern. The `untrusted-content` and `partition-registry-boundary` invariants both hold over the changed code.

## Findings

No findings — the build aligns with spec, plan, and architecture.

## Deviations & feedback

- Clean run: 0 interruptions across every stage; the single `sec` re-run (2 runs) was the planned dual-lens (spec then spec+plan), not a correction. The security review's two Advisory findings were both addressed in the plan before build, so the build inherited an unambiguous design.
- The prose-drift channel that caused the original defect is now guarded by a deterministic prose-pin test; its residual (a new invocation site added without the flag stays unwatched) is tracked as `20260723-skills-prose-invocation-lint`.
- One tangential discovery surfaced during the build and was filed: `ARCHITECTURE.md` claims a build-gate grep enforces the `deps_command` family name's absence from `jimpartition.sh`, but no such gate exists — the invariant is upheld only by the `partition-registry-boundary` judge (which holds), not the claimed mechanical gate. Tracked as `20260723-add-deps-command-absence-build-gate-test`.
