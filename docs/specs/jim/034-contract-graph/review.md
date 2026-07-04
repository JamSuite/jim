---
spec: "jim/034"
type: "feature"
base_sha: "8f1c5fcc2fddf6907c361a5edf2d5ad9633af9f2"
head_sha: "947b879c49fb5036181c032a6731d4e0861e2007"
commits: "8"
commits_test: "0"
commits_feat: "5"
commits_fix: "0"
commits_refactor: "0"
files_changed: "7"
insertions: "336"
deletions: "11"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "9365"
research_runs: "1"
research_interruptions: "1"
research_duration_seconds: ""
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1338"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4578"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1235"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "454"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
alignment: "aligned"
date: "2026-07-04"
---

# Review: Cross-group contract graph and blast radius

## Summary

**Alignment:** aligned · **Depth:** thorough · **Findings:** 2 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the 034 build over `8f1c5fc..947b879` (8 commits, 7 files, +336/−11):
the reconcile pass added to `/jim:blueprint` — methodology reference, map-template
section, `--reconcile` dispatch + `§ Reconcile` skeleton, five trigger hooks,
Step-4a blast-radius consult, WORKFLOW.md documentation, and the dogfood run
that wrote the short-circuit graph section into `BLUEPRINT.md`. All 13 spec ACs
verified satisfied by 8 read-only investigators; the two findings are low-priority
documentation-consistency items, not behavioral gaps. One instrumentation note:
the research stage's ledger pair never closed (`started` only), so its duration
metric is unavailable.

## Alignment

### vs. Spec acceptance criteria

- AC #1–#3 (graph derived from faces, single writer, no persisted verdicts) — met.
- AC #4 (six finding classes with remedies, non-dotted routing, territory
  re-validation, relation-class conditions) — met, element by element.
- AC #5–#6 (declared-data principle, existential/universal rule, coverage +
  unverifiable reporting) — met; counter-exclusion of notes/unverifiable is explicit.
- AC #7 (triggers on every write + on-demand + <2-groups no-op) — met; omission
  check found no unhooked write path.
- AC #8 (blast radius at face-change time, never a veto) — met; see Finding 1 for
  a load-order asymmetry at the U3 fork presentation.
- AC #9–#10 (detection-time report, confirmed issue offers, declaration-level
  wording; durable counters) — met; dogfood ledger line carries all seven counters.
- AC #11–#12 (trust boundary, delimited evidence, secret redaction) — met across
  all three quoting surfaces and all three persistence targets.
- AC #13 (derived-graph Step-4a exemption, bounded and recorded) — met; the three
  documents agree.

### vs. Plan tasks

- Tasks 1–7 — all done; every File-Manifest file touched, nothing outside the
  manifest changed (the two ledger files are build instrumentation). No scope creep.
- The plan's pre-identified line-budget fallback (push detail into the methodology
  reference) was exercised deliberately in task 3 — commit choreography lives in
  `reconcile-methodology.md` § Commit choreography.

### vs. ARCHITECTURE.md

- SKILL.md ≤ 500 lines — respected: 497/500 (3 lines of headroom; tracked as issue
  `20260704-restructure-blueprint-skill-md-to-reclaim-line-budget-headroom`).
- `allowed-tools` mirrors call sites — respected: § Reconcile and the methodology
  invoke only already-granted scripts; no frontmatter change needed.
- Single-writer artifacts / three path-scoped commit arms — respected: the graph
  rides `commit-map` only; `jimledger.sh` untouched, its `cmd_event` and
  `cmd_commit_map` interfaces fit the documented calls exactly.
- Bash-vs-Prompt rule — respected and documented (plan DD 2 declines the
  extraction script with rationale).
- Untrusted-content boundary and secret redaction — respected (AC #11/#12 evidence).

## Investigation

### High-stakes regions investigated

#### Graph block (AC #1–#3): methodology, template, § Reconcile, dogfood output
- locations examined: `skills/blueprint/references/reconcile-methodology.md:8–51,117–136,198–233`, `skills/blueprint/assets/map-template.md:9–14,39–50`, `skills/blueprint/SKILL.md:38,446–467,495–497`, `BLUEPRINT.md:39–45`, `skills/blueprint/assets/blueprint-template.md:35`
- callers/consumers traced: repo-wide grep for `Contract Graph` / `BLUEPRINT.md` writers — only the reconcile pass writes the section; other references are read-only or delegating
- tests checked: none found — prose-only feature; plan's grep Verifies pass
- verdict: satisfied — "the graph is the join, not a copy" is explicit; no shipped shape carries a status column; dogfood output matches the template verbatim

#### Detector classes (AC #4)
- locations examined: `reconcile-methodology.md:41–51,53–66,68–104,238–247`, `SKILL.md:446–467,496–497`
- callers/consumers traced: all five write-path triggers route to § Reconcile, which mandates reading the methodology
- tests checked: none found — LLM-executed skill prose, checklist-validated
- verdict: satisfied — all six classes with remedies, non-dotted routing (`:49–51`), `valid-relpath` re-validation at use (`:92–94`), both-blueprints condition (`:98–100`), never-rewrites-Relations (`:102–104`)

#### Declared-data principle + coverage (AC #5–#6)
- locations examined: `reconcile-methodology.md:53–66,107–115,122,140–152,237–243`, `SKILL.md:456–457,496`
- callers/consumers traced: trigger sites delegate coverage rules to the methodology; `ARCHITECTURE.md` restates consistently
- tests checked: none found
- verdict: satisfied — principle verbatim from the spec; notes/unverifiable excluded from counters (`:242–243`); report example internally consistent

#### Trigger wiring (AC #7) — omission check
- locations examined: `SKILL.md:16,38,147–148,213,250–256,366–367,433–434,446–467,496–497`, `BLUEPRINT.md:39–45`, `docs/specs/ledger.md:3–4`
- callers/consumers traced: every write path enumerated from the full SKILL.md — Step 5 (fresh + differential regen), U2 create fallthrough, U2a regen branch, U4, M3 (covers map-tier creates too); declined/abandoned writes correctly unhooked; § Reconcile does not re-fire itself
- tests checked: none found
- verdict: satisfied — no write path lacks a hook; fix-only skip stated with rationale; dogfood event pair brackets the map stamp

#### Blast radius + grading exemption (AC #8, #13)
- locations examined: `SKILL.md:93–131,264–300,342–350,415–419,446–467,496–497`, `reconcile-methodology.md:77–81,154–166,199–233,236–247`, `WORKFLOW.md:429–449`
- callers/consumers traced: all graded-autonomy prompt sites route through Step 4a (Step 5 auto branch, U2a, U4, M2), so every Provides-downgrade presentation inherits the consult
- tests checked: none found
- verdict: satisfied — with one asymmetry recorded as Finding 1 (U3a fork presentation carries no in-skill pointer; methodology names U3, Step-4a routing preserves the behavior)

#### Report, issue offers, durable record (AC #9–#10)
- locations examined: `reconcile-methodology.md:117–152,169–196,236–262`, `SKILL.md:446–467,496`, `skills/issue/SKILL.md:190–211`, `skills/issue/scripts/new.sh:24–75`, `docs/specs/ledger.md:3–4`
- callers/consumers traced: emitter flags verified against `new.sh`'s real interface; one `index.sh` refresh per batch matches § 7a
- tests checked: none found — dogfood ledger line is the executable evidence
- verdict: satisfied — "close and commit — always" makes decline-no-hidden-state structural; all seven counters present as zeros on the dogfood line; see Finding 2 for the § 7a enumeration nit

#### Trust & safety (AC #11–#12)
- locations examined: `reconcile-methodology.md:22–36,127–136,157–166,169–196`, `SKILL.md:62–66,82–84,104–121,477,496`
- callers/consumers traced: grep for `untrusted-face-content` — tag used only where intended, no conflicting usage
- tests checked: none found
- verdict: satisfied — boundary covers all input classes and all three judgment surfaces; delimiting covers all three quoting surfaces; redaction placeholder covers graph/report/issue persistence; report-shape short names are the spec's own mockup, not undelimited evidence

#### Plan-manifest / conventions sweep
- locations examined: `plan.md:163–302`, `SKILL.md:1–497` (497 lines), `reconcile-methodology.md:1–262`, `map-methodology.md:1–117`, `skills/review/scripts/jimledger.sh:1–442` (unmodified; `cmd_event:209–221`, `cmd_commit_map:184–206`), `WORKFLOW.md:438–449`
- callers/consumers traced: § Reconcile script call sites → granted paths in `SKILL.md:17`; `updates-since` reads only the group-dir ledger, so reconcile events at the specs root cannot skew regen-cadence counts
- tests checked: none expected — plan DD 2 ships no script
- verdict: satisfied — no divergences; the investigator lacked Bash so the task-7 commit assertion was not re-run by it (it was run and passed during the build)

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 8 investigators dispatched, under the
  fan-out cap of 10; the 13 ACs were bundled into cohesive targets so nothing
  was left uninvestigated.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (0/5/0/0) |
| Files changed · insertions · deletions | 7 · +336 · −11 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 9365s·—·1338s·4578s·1235s·454s |
| Interruptions (spec·research·plan·sec·build·review) | 0·1·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. No secrets in the diff; the change strengthens the untrusted-content
  discipline (new delimited `<untrusted-face-content>` convention, territory
  re-validation at use, redaction extended to the graph/report/issue surfaces);
  no new script, commit arm, or permission grant.

## Findings

### 1. U3 fork presentation lacks an in-skill blast-radius pointer

- **Priority:** low
- **Description:** Plan DD 7 and methodology § Blast radius both name the U3
  violation fork as a blast-radius consumption site, but `SKILL.md`'s U3a
  presentation format carries no pointer — the only in-skill hook is Step 4a
  (`SKILL.md:109–113`). Every Provides-downgrade presentation still routes
  through Step-4a grading, so the developer sees the line before deciding a
  write; the residual is load-order only (a fork item implicating a provided
  surface gets the enrichment at the subsequent grading, not in the fork itself).
- **Suggestion:** When the line-budget restructure lands
  (`20260704-restructure-blueprint-skill-md-to-reclaim-line-budget-headroom`),
  add a one-line pointer to methodology § Blast radius in U3a's per-violation
  format.
- **Relates to:** AC #8; plan DD 7

### 2. Candidate-batch contract enumeration is out of date

- **Priority:** low
- **Description:** `skills/issue/SKILL.md:192` (§ 7a) still enumerates "the
  seven surfacing skills" as the batch consumers; the reconcile pass (and,
  arguably, the 031 divergence offer before it) now also files through the
  contract, so the canonical list undercounts its consumers.
- **Suggestion:** Reword § 7a's enumeration to include the blueprint surfaces
  or drop the fixed count.
- **Relates to:** AC #9

## Deviations & feedback

- The research stage's ledger pair never closed (`started` 06:41Z, no
  `finished`), so it reads as an interruption and its duration is unmissing —
  the artifact itself shipped and was committed. Worth watching whether the
  research skill's finish event is being skipped when approval and commit
  happen in the same breath.
- `commits_test=0` is by design, not a gap: a markdown-prompt feature's Red
  phase is the plan's Verify command failing before authoring (plan DD 2
  declines a deterministic script, so there is no `tests/` surface).
- The line budget was managed proactively (fallback exercised at task 3 rather
  than after busting the ceiling) — a pattern worth repeating; the remaining
  3-line headroom is already tracked as an issue.
