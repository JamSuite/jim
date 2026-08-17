---
spec: "blueprint/022"
type: "feature"
base_sha: "ea624bac1c4ed45c07bc896f3cf1d8d8feee4138"
head_sha: "0ebd70af80e09ec29ec4d41eb882e01e3721dff0"
commits: "7"
commits_test: "1"
commits_feat: "5"
commits_fix: "0"
commits_refactor: "0"
files_changed: "6"
insertions: "218"
deletions: "12"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "3510"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "634"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "894"
sec_runs: "3"
sec_interruptions: "0"
sec_duration_seconds: "2564"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2627"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "224"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "aligned"
date: "2026-07-23"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Enforce present-tense discipline at blueprint draft composition

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 0 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec-050 build (`ea624ba..0ebd70a`, 7 commits): a single-source
`present-tense.md` reference cited by path from ten blueprint composition exit
doors, guarded by the textual-invariant `tests/presenttense.sh`, plus a
Validation Checklist item. The change is entirely skill/reference prose + one
test; all 10 ACs are satisfied, the file set matches the plan exactly, and the
living-intent sensor found no invariant violations.

## Alignment

### vs. Spec acceptance criteria
- AC1 (checklist item) — met (`SKILL.md:508`).
- AC2 (three marker categories, illustrative vocabulary) — met (`present-tense.md` § The rule).
- AC3 (single-sourced, referenced not restated) — met (one canonical reference, 10 path cites, no inline restatement).
- AC4 (citation presence mechanically verifiable) — met (`tests/presenttense.sh`).
- AC5 (every supplied-text site treats text as input) — met; all listed sites wired (map-tier update, mint-new handoff, interview synthesis, migrate arms, group-tier generate/update).
- AC6 (supplied text as untrusted data, directives never followed) — met (§ Untrusted supplied text; judge-confirmed).
- AC7 (rewrites itemized/disclosed, revert authority) — met (§ Normalize and disclose).
- AC8 (disclosure secret-scrubbed, both path classes) — met (§ Normalize and disclose step 4; judge-confirmed).
- AC9 (universal pre-gate self-scan; gate confirms not supplies) — met (exit-door scan = sum of per-flow scans, § Where it runs).
- AC10 (no-re-gate migrate paths normalize + disclose to caller) — met (`migrate-arms.md`, all three arms).

### vs. Plan tasks
- Tasks 1–7 — all done; file set is exactly the 6 planned files, no scope creep. Task 6's test had a shared-globals collision with `gatepresentation.sh` under the aggregate runner (both used generic `TOKEN`/`RULE_DOC`); fixed at the root with `PT_`-prefixed identifiers and folded into the Task 6 commit so it is green on its own.

### vs. ARCHITECTURE.md
- Define-once-cite-by-path — respected (`present-tense.md` mirrors `gate-presentation.md`).
- Checklist-validation + textual-invariant test — respected (`presenttense.sh` mirrors `gatepresentation.sh`; documented in the new *Present-tense Discipline* subsection).
- SKILL.md ≤ 500 lines — diverged (grown further past 500), but this is the **spec-authorized** exception (plan Constitution Check; #43-tracked), not unplanned drift.

## Investigation

### High-stakes regions investigated

The change is entirely skill/reference prose + one textual-invariant bash test —
no changed code signatures, shared types, or executable trust boundaries — so 4b
triage surfaced no high-stakes *code* regions warranting an investigator
fan-out. Assessed directly against the files (in context) and mechanical evidence:

#### Citation wiring (AC3/AC4/AC5)
- locations examined: `SKILL.md` (5 cites: Step 5, U4, M2, mint-new, checklist), `references/map-methodology.md` (2), `references/migrate-arms.md` (3).
- tests checked: `tests/presenttense.sh` — green in the full 692-test suite; asserts each file's per-file minimum and the reference's four load-bearing sections.
- verdict: satisfied — 10 cites, mechanically guarded.

#### Omission class (AC5/AC9 — "every path that ingests supplied text")
- locations examined: all blueprint composition entry points; `present-tense.md` § Where it runs.
- verdict: satisfied — every supplied-text site is wired; retire (fixed banner) and reconcile (derived contract graph) are correctly excluded (no supplied text) and documented.

### Coverage
- Depth: thorough; review_model: inherit.
- Full high-stakes set assessed directly (no investigator fan-out needed — prose + one test; citation wiring mechanically verified by the green suite).

## Living intent

**Sensed:** 34 invariants · **holds:** 7 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 26 · **failed/unconfigured:** 1

### Violations
- None — every checked invariant holds.

### Coverage
- appetite in force: low (default).
- Whole-group mechanical floor ran: `no-third-party-deps` (critical, pattern) holds — no `jq`/`yq`/`bats` in `skills/`. Territory conformance: 373 scaffolding files bucketed (docs/, root config), 0 strays — the build's files are all in-territory.
- registry: 0 configured — `skill-line-budget` reports `unconfigured` (the line-budget is tracked by #43 / the meta-skill checklist, not a wired registry command).
- judges: change-selected. `untrusted-content` (critical) independently judged → holds (the new prose keeps supplied text as data and routes its new disclosure surface through the `secret-looking value at <path:line>` scrub). The script-convention invariants (`script-preamble`, `bash-source-relative`, `no-source-eval`, `tests-under-tests`) and `gate-presentation` were assessed directly against the single new test file and the green textual-invariant suite rather than dispatched whole-group judges — proportionate to a prose+test change that left jim's scripts and agents unchanged.
- skipped by scope: 26 (jim's scripts/agents unchanged by this build) · skipped by appetite: 0.
- Contract-edge phase: not run — jim is single-group, so the graph names no provider edges.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 7 (1/5/0/0) |
| Files changed · insertions · deletions | 6 · +218 · -12 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·3·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3510s·634s·894s·2564s·2627s·224s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The change *adds* security-strengthening prose (untrusted-data handling + secret-scrub on the new itemization/disclosure surface, judge-confirmed). No secrets committed; no weakened boundaries; `presenttense.sh` uses fixed-string `grep -oF` on literal paths (no injection surface).

## Findings

No findings — the build aligns with spec, plan, and architecture. The one
follow-on surfaced during the build (the `gatepresentation.sh` generic-globals
fragility) was filed as `20260723-harden-textual-invariant-test-global-identifier-naming`.

## Deviations & feedback

- Clean run: spec → research → sec (×3, all findings routed and resolved) → plan → sec → build, no interruptions. The security chain's dual-lens review (3 sec runs) caught a scoped untrusted-data-handling requirement and the disclosure secret-echo pre-build, both folded as ACs — the process's fold-before-approval discipline held.
- The build's own full-suite task (Task 7) caught a test-file global-name collision that both standalone runs missed — evidence for keeping the aggregate-runner task as the final gate.
