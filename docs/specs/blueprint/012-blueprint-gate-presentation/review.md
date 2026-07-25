---
spec: "blueprint/012"
type: "bug"
base_sha: ""
head_sha: ""
commits: ""
commits_test: ""
commits_feat: ""
commits_fix: ""
commits_refactor: ""
files_changed: ""
insertions: ""
deletions: ""
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "1771"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "485"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1138"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1495"
build_runs: ""
build_interruptions: ""
build_duration_seconds: ""
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "464"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-07"
---

# Review: Blueprint-surface approval-gate presentation

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 2 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec-040 implementation over the commit range `42c59cb..246235e`
(the three build commits). The build was executed directly, not through
`/jim:build`, so the ledger carries no build range — git-range metrics
(commits, diffstat, base/head SHA) are unavailable and assessed from the working
tree instead; per-stage process metrics are intact. The core fix is sound and
correctly shipped (the rule doc, six inline blueprint pointers, reference-doc and
partition wiring, meta checklists, and a passing regression test), but two
gate-coverage gaps against the spec's intent keep it from fully aligned.

## Alignment

### vs. Spec acceptance criteria
- AC 1 (single shared doc, referenced by path) — **met**: `skills/blueprint/references/gate-presentation.md` is the sole definition; sites carry pointers only.
- AC 2 (four required elements + threshold) — **met**: the doc's four sections encode general rule + long-content mechanics + decline + data-safety.
- AC 3 (coverage of every long-content gate) — **drift**: 8 of 9 enumerated gates carry a pointer; the **map *update* sub-gate is uncovered** (only map *create* is) — Finding 1.
- AC 4 (decline leaves nothing written) — **met**: rule's `## On decline` + scratchpad ephemerality.
- AC 5 (no data-loss path) + sec Findings 1/2 (scrub, delimiting) — **met**: encoded in the doc's long-content + data-safety sections.
- AC 6 (build-gate check on the reference) — **met with a gap**: the test catches a dropped blueprint pointer (6-for-6) but under-covers partition (2 sites, min 1) — Finding 2.
- AC 7 (meta-skill/meta-agent checklist item) — **met**: both carry it.
- AC 8 (regression test covers the scenario) — **met**: `tests/gatepresentation.sh`, suite green (474/474).

### vs. Plan tasks
- All 8 tasks done, and **only** those tasks — no scope creep. The `ARCHITECTURE.md` doctrine entry is in a separate post-build commit (`38fbc2c`) via `/jim:arch`, exactly as the plan deferred it — confirmed outside the reviewed range. The map-update gap traces to the plan itself scoping the map pointer to "creation step 4" (File Manifest), so the build faithfully implemented the plan; the gap is spec-coverage, not a build deviation.

### vs. ARCHITECTURE.md
- **Respected.** No new `!`-injection / `allowed-tools` call-site (no permission creep); SKILL.md ≤ 500 (blueprint 498); references-by-path mirrors the § 7a pattern; the deterministic reference-presence check lives in bash while the rule is prose (Bash-vs-Prompt). The new `### Gate Presentation` convention was recorded via `/jim:arch`, not hand-edited (`arch-via-skill`).

## Investigation

### High-stakes regions investigated

#### Regression test correctness — `tests/gatepresentation.sh` (investigator A)
- locations examined: `tests/gatepresentation.sh:1-82`, `skills/blueprint/references/gate-presentation.md`, `skills/meta-test/scripts/testlib.sh`, `tests/jimpartition.sh`
- verdict: **partial** — catches a dropped blueprint pointer (fixed-string occurrence count, `≥ 6`, six genuine one-per-line pointers); checked-file set complete; doc-structure assertions match; conventions exact. Gap: `partition ≥ 1` under-covers partition's two sites (Finding 2); latent note — counts token occurrences, not pointer sites, so a token in a comment could in principle mask a drop (no live false pass today).

#### Edit fidelity & coverage across the modified gate sites (investigator B)
- locations examined: the six blueprint pointers (`SKILL.md:138,140,274,314,380,456`), `fork-grounding.md:122`, `reconcile-methodology.md:121`, `map-methodology.md:66`, `partition/SKILL.md:114,134`, both meta checklists
- verdict: **partial** — all 13 insertions preserve the original gate instruction's meaning (no garbled/broken text); 8/9 gates covered; line cap satisfied; no scope creep in range. Gap: **map *update* sub-gate uncovered** (Finding 1). Cosmetic notes: `map-methodology.md:64-66` reads slightly redundant ("Present … Present the draft per …"); `fork-grounding.md:122` uses a variant clause shape (whole clause parenthesized) — token still matches, sentence parses.

### Coverage
- Depth: thorough; review_model: inherit. Full high-stakes set investigated (2 investigators, cap 10). Instrumentation gap: no `/jim:build` range, so git-range metrics unavailable — alignment assessed over the working tree + commit range.

## Living intent

**Sensed:** 21 invariants · **holds:** all relevant · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** judge-rung (see Coverage) · **failed/unconfigured:** registry (skill-line-budget)

The change-scoped judge sensor was **degraded** (no `/jim:build` diff channel to scope to), so this is a best-effort read: the deterministic floor ran whole-group and the judge-rung invariants this change touches were reasoned by inspection.

### Violations
- None — every checked invariant holds. The one mechanical invariant in territory, `no-third-party-deps` (scope `skills/`), **holds** (the new test is bash+POSIX). This change's new files (`skills/blueprint/references/gate-presentation.md`, `tests/gatepresentation.sh`) sit **within** the jim territory, so it introduced **no** new conformance strays. Judge-rung invariants the change touches all hold: `skill-budget` (blueprint 498 ≤ 500), `arch-via-skill` (used `/jim:arch`), `tests-under-tests` (test under `tests/`), `allowed-tools-exact` (unchanged — no new call-site).

### Coverage
- appetite in force: low.
- Whole-group floor ran (deterministic pattern/structure only).
- judges: not fanned out — the `--from-review` change channel was empty (no build range), so change-selection had nothing to scope; the touched judge-rung invariants were assessed by inspection instead.
- Note (pre-existing, not this build): the floor's TERRITORY-CONFORMANCE set lists all root docs (`ARCHITECTURE.md`, `README.md`, `docs/**`, …) as strays because the jim group's declared territory is only `skills/`/`agents/`/`tests/`. Pre-existing partition characteristic — not drift from spec 040; noted, not filed.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | *unavailable — build not run via `/jim:build`* |
| Files changed · insertions · deletions | *unavailable* (working-tree range: 9 files · +171 · −11) |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·—·1 |
| Stage durations (spec·research·plan·sec·build·review) | 1771s·485s·1138s·1495s·—·464s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·—·0 |
| Artifacts present | spec, research, security, plan, ledger |

## Security regressions

- None identified. The change adds no secrets, no new injection surface, and no new tool/permission grant (pointers are prose citations; the test is read-only bash). The reviewable-file persistence path the fix *introduces* is design-time text, governed by the scrub/delimiting requirements already folded into the spec (sec Findings 1/2).

## Findings

### 1. Map *update* sub-gate carries no gate-presentation pointer

- **Priority:** medium
- **Description:** AC 3 enumerates "map create/update (M2)" as one gate, but the pointer landed only on the **create** side (`skills/blueprint/SKILL.md:380`, `map-methodology.md:66`). The map **update** branch — `SKILL.md:381-385` and `map-methodology.md` § Update flow (`:68-94`), whose per-item downgrade prompt "always prompts per-item, even under `auto_blueprint`" — has no pointer, and its "Step-4a shared rule" grading does not inherit one. A map-update diff can exceed ~20 lines, so this sub-gate has the exposure the rule addresses. Traces to the plan scoping the map pointer to creation only (so the build matched the plan — spec-coverage gap, not a build deviation).
- **Suggestion:** Add the pointer to the M2 update bullet / § Update flow, and bump the test's `map-methodology.md` minimum to 2 (or keep file-level and accept the single-bucket reading). One-line edit; closes AC 3 cleanly.
- **Relates to:** AC 3

### 2. Regression test under-covers partition's two gate sites

- **Priority:** low
- **Description:** `tests/gatepresentation.sh` sets `partition ≥ 1`, but `partition/SKILL.md` has two gate sites (proposal `:114`, hard gate `:134`); dropping one still passes the suite. Documented plan trade-off (`plan.md:104`), but looser than AC 6's literal "any affected gate site." blueprint/SKILL.md is the only file whose per-gate granularity is enforced.
- **Suggestion:** Set `partition ≥ 2`, or refactor the check to assert per-site presence rather than a per-file occurrence count (also closes the latent "token in a comment" note).
- **Relates to:** AC 6

## Deviations & feedback

- **Process gap — direct build, no `/jim:build` instrumentation.** Because the plan was executed by hand (a cross-skill edit that didn't fit a single `/jim:meta-skill` run), no build range was recorded, so this review lost its git-range metrics and the living-intent sensor lost its change-scoping. The alignment review was unaffected, but future cross-cutting builds would review better with a lightweight `build started`/`finished` bracket around the edits.
- **Both gaps are coverage-precision, not correctness.** The shipped fix works and the suite is green; the two findings tighten the *edges* (map-update, partition granularity) against the strictest reading of the ACs. Both are one-to-few-line follow-ups.
- **The session dogfooded the rule it built** — every gate in this very workflow was presented as path + compact summary + a final plain-text question, which is corroborating evidence that the rule is livable.
