---
spec: "jim/037"
type: "feature"
base_sha: "f156cb45b736646047bac47497e3950b7a8687cb"
head_sha: "2a3903c9d7c15ee694f423a23351fc2bb142faaf"
commits: "12"
commits_test: "0"
commits_feat: "8"
commits_fix: "0"
commits_refactor: "0"
files_changed: "16"
insertions: "1214"
deletions: "49"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5581"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1192"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1541"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3309"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2451"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "479"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "1"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-05"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Contract-graph verification

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 5 · **Plan deviations:** 1 · **Security regressions:** 0

The 037 build shipped the contract-graph verification engine — three deterministic
`jimverify.sh` verbs (`faces` / `edges` / `contracts-check`) with 19 new fixture
tests, contract mode on `/jim:verify`, the judge-edge generalization, and the
review/blueprint trigger surfaces — over the `f156cb4..2a3903c` range (16 files,
+1214/−49, 8 feat commits, full suite green at 414 tests). The security surface
(the new bash) is sound: three read-only investigators confirmed no injection,
exfiltration, or TSV column-shift defect. **15 of 17 acceptance criteria are
fully realized;** the verdict is `minor-drift` because AC #9's durable-record
clause is unrealized on the boundary-change trigger path, and two
security-relevant behaviors of the new verbs lack tests.

## Alignment

### vs. Spec acceptance criteria

- AC #1, #2, #3, #6, #7, #8, #10, #11, #12, #13, #14, #15, #16, #17 — **met** (code + prose evidence, deterministic tests for the floor).
- AC #4 (dead-surface) — **met** with a noted coarseness: the floor's `CROSS-REF` is a territory-prefix match, so the skill's "no CROSS-REF fact" dead-surface test is coarser than "no consumer code uses *this surface*"; mitigated by the methodology framing dead surface as judge-confirmed candidates (`contracts-methodology.md:104`).
- AC #5 (cross-ref floor) — **met** but thin: the report shape prints `territory: <mode>`, but the C1 process never resolves the `group_territory` config key, so the `directory`-vs-`declared-paths` floor-strength label is under-wired (the `none` case *is* surfaced via `UNSCOPED-GROUP`). See Finding 4.
- AC #9 (boundary-change trigger) — **drift.** Grounding runs unattended and never gates the write (correct), and the graph basis is always named. But the AC requires unattended findings to "land in … the run's durable record": the `--contracts <group> --entries` trigger records nothing itself (`verify/SKILL.md:129`) and the blueprint `finished` event carries no edge counter (`blueprint/SKILL.md`), whereas the review-sensor path *does* (`verify/SKILL.md:88`). The boundary-change trigger's findings are summarized but not durably counted. See Finding 1.

### vs. Plan tasks

- Tasks 1–11 — **all done, and only those.** Each verb was TDD'd (tests-first, confirmed Red, then Green); the three doc/skill task clusters landed as prose edits verified by their `**Verify:**` grep gates. No scope creep beyond the plan.
- One deliberate interface deviation from the plan (faces unsafe-scope handling) — see Deviations & feedback.

### vs. ARCHITECTURE.md

- Bash-vs-Prompt split respected (facts in the script, classification in the skill); one-level subagent nesting preserved (verify runs inline); the four path-scoped commit arms unchanged (`commit-verify` reused for the specs-root project-tier run). SKILL.md budgets under 500 (verify 297, blueprint 464, review 249), judge body ~770 tokens.
- One in-change divergence from a jim living invariant — `blueprint-slot-reserved` — see ## Living intent.

## Investigation

<!-- Depth: thorough. Three read-only investigators fanned out over the one
     high-stakes region (the new bash) and the AC/test surfaces. -->

### High-stakes regions investigated

#### `skills/verify/scripts/jimverify.sh` — the three new verbs (security)
- locations examined: `cmd_faces:540-620`, `cmd_edges:626-660`, `cmd_contracts_check:748-837`, helpers `contract_ref_check:710-735`, `intersect_scope:682`, `emit_edge:701`, `parse_params:325-330`
- callers/consumers traced: `terr_of`→`cmd_territory`→`jimfile.sh valid-relpath`; the skill-layer contract-mode process (C1–C6)
- tests checked: `tests/jimverify.sh:806-807` (location-only), `:876-890` (unsafe scope→failed), `:892-918` (files-list HYGIENE + scoped cross-ref), `:718-732` (crafted-cell HYGIENE)
- verdict: **satisfied** — all 7 security/correctness ground truths CONFIRMED with `file:line` evidence: no source/eval, every untrusted pattern behind `-e`/`--`, every path through `safe_path_param`/`safe_scope_file`, evidence location-only (matched content never emitted), TSV fields sanitized, slug/shape gates on groups/keys/cells, and correct floor logic (self-pair skip, files-list scoping, accurate COVERAGE). No exploitable injection, exfiltration, or column-shift.

#### Spec AC coverage (17 criteria)
- verdict: **satisfied for 15/17**; AC #9 partial (durable-record clause on the boundary-change path), AC #5 thin (territory-mode label under-wired), AC #4 coarse-but-doctrine-bounded. No hard code-vs-prose contradiction — the methodology doc and the deterministic floor are consistent.

#### Test adequacy
- verdict: **partial** — solid on the headline HYGIENE / malformed / CROSS-REF-leak negatives, but two behaviors have no test: the consumer-ref abstain-on-absent path (a regression flipping abstain→violated would pass every current test) and the edge-outcome location-only guarantee (the existing `grep -c 'require'` guard is a consumer-side token that does not appear on edge match lines). See Findings 2–3.

### Coverage

- Depth: thorough; review_model: inherit. Three investigators ran (security / AC-coverage / test-adequacy); the full high-stakes set was covered — no fan-out cap bound.
- Prose-discipline invariants (allowed-tools, `!`-injection, sigil/sentinel) were verified deterministically against the diff rather than by fan-out.

## Living intent

<!-- The jim group's living invariants checked against the build (spec 036/037
     sensor), distinct from the spec/plan Alignment verdict above — it never sets
     it (AC #3). The reviewed group `jim` is single-group, so the contract-edge
     phase did not fire (the graph names no provider edge). -->

**Sensed:** 30 invariants · **holds:** 17 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 11 · **failed/unconfigured:** 1

### Violations

- `blueprint-slot-reserved` — high · **violated** · in-change · `skills/verify/scripts/jimverify.sh:778`, `:816` — the new `cmd_contracts_check` derives the group blueprint path by hand (`$specs_root/$g/000-blueprint/spec.md`) instead of resolving it through the single `jimfile.sh path blueprint <group>` boundary the invariant reserves. The pre-037 `cmd_check` respects this (it takes `<blueprint-dir>` as a skill-resolved arg); 037's new code path duplicates the `000-blueprint` slot convention in a second place. **Fix the code** (resolve per group via `jimfile.sh path blueprint`, which the script already shells out to for `valid-relpath`) or **fold the intent** (accept a deterministic-layer derivation from a trusted `specs_root` as a documented exception). Routes to the Step-10 blueprint fork.

### Coverage

- appetite in force: `low` (judge everything eligible); no per-group override.
- Whole-group floor ran (`--from-review`); `no-third-party-deps` holds; 262 territory-conformance records are project scaffolding (docs/specs, root docs) — informational, none in-change jim group code.
- Judge rung: the 17 change-selected judge invariants were adjudicated from the review's own investigation evidence + deterministic diff checks rather than a redundant fresh fan-out (every one examined, none skipped for lack of coverage). 11 invariants the change does not touch were `skipped` (reason: scope) — the reconcile/map/regen/ref-validation families 037 leaves untouched.
- registry: `skill-budget` → **unconfigured** (no `verify_command_skill-line-budget` on this host); the touched SKILL.md budgets were independently verified under the 500-line / ~800-token limits (informational).
- Contract-edge phase: did not run — `jim` is single-group, so the map's `## Contract Graph` names no provider edge (existence gate not met).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 12 (0/8/0/0) |
| Files changed · insertions · deletions | 16 · +1214 · −49 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 5581s·1192s·1541s·3309s·2451s·479s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

<!-- commits_test=0: tests landed inside the feat commits (each verb was
     Red→Green→committed green as one atomic behavioral unit). -->

## Security regressions

- None identified. The new bash extends the existing engine's discipline verbatim — location-only evidence (exfiltration guard), `-e`/`--` grep guards, `safe_path_param` as the single path gate, and TSV sanitization — all independently confirmed with `file:line` evidence.

## Findings

### 1. AC #9 boundary-change grounding is not durably recorded

- **Priority:** medium
- **Description:** The boundary-change trigger (`--contracts <group> --entries`) runs full grounding and never gates the write, but its findings do not land in a durable ledger counter — the trigger records nothing itself and the blueprint `finished` event carries no edge counter. AC #9 (and the revised 2026-07-05 decision) require unattended findings to land in the run's durable record. Realized for the review-sensor path (`edges_checked=`/`edge_violations=`), not the boundary-change path.
- **Suggestion:** Append `contract_edges=`/`contract_violations=` (or reuse `edges_checked=`/`edge_violations=`) to the `blueprint finished` event when the boundary-change trigger ran, mirroring the sensor path.
- **Relates to:** AC #9

### 2. consumer-ref abstain-on-absent path is untested

- **Priority:** medium
- **Description:** `contract_ref_check` abstains (emits no record) when a `consumer-ref` pattern is absent from consumer territory — the provider/consumer asymmetry (a provider-ref absence is `violated`, a consumer-ref absence is not). No test drives an absent consumer usage and asserts no record; a regression flipping it to `violated` would pass the whole suite.
- **Suggestion:** Add a `contracts_repo` variant whose consumer code lacks the declared usage and assert the consumer side emits no edge record.
- **Relates to:** AC #2, task 3

### 3. edge-outcome location-only guarantee is untested

- **Priority:** medium
- **Description:** The location-only assertion (`case_jimverify_contracts_coverage_crossref_locationonly`) greps for `require`, a consumer-side token present only on `CROSS-REF` match lines — it does not cover the provider/consumer *edge outcome* evidence (`getIdentity` on `session.js:1` / `invoice.js:2`). Dropping the `cut -d: -f1,2` in `contract_ref_check` would leak the full matched line uncaught.
- **Suggestion:** Add a `grep -c 'function'` / `grep -c 'getIdentity'` assertion over the edge-outcome records to lock the edge evidence to `file:line`.
- **Relates to:** AC #17, task 3

### 4. Territory-mode floor-strength label is under-wired

- **Priority:** low
- **Description:** AC #5 asks the report to name the floor's strength by `group_territory` mode (`directory` strongest, `declared-paths` mid, `none`). The report prints `territory: <mode>` but the C1 process never resolves `group_territory`, so the directory-vs-declared-paths distinction is not actually surfaced (only `none` → `UNSCOPED-GROUP` is observable).
- **Suggestion:** Resolve `group_territory` in C1 and print the concrete mode, or drop the `<mode>` placeholder from the report shape to avoid implying a distinction the run does not make.
- **Relates to:** AC #5

### 5. Edge-pattern loop lacks a self-edge guard

- **Priority:** low
- **Description:** `contracts-check`'s CROSS-REF loop skips self-pairs (`C==P`), but the graph-edge outcome loop does not. A self-edge persisted in the Contract Graph would run provider-ref/consumer-ref over the same group's territory. Not a security issue — it relies on the reconcile writer never emitting self-edges — but a cheap robustness guard.
- **Suggestion:** Add a `[[ "$C" == "$P" ]] && continue` to the edge loop, mirroring the CROSS-REF skip.
- **Relates to:** task 3

## Deviations & feedback

- **Deliberate interface deviation (faces unsafe-scope):** the plan's interface contract had `faces` flag an unsafe `contract-checks` `scope=` as `malformed`. During build this proved to make `contracts-check` skip the entry, suppressing the `failed` outcome AC #17/Finding 2 wants. The build instead routes scope path-safety to the single execution gate (`safe_path_param` in `contracts-check`), which degrades the check to `failed` — a cleaner single-validation-boundary design consistent with the `check` verb. Documented in the faces header and `check-authoring.md`. Accepted as an improvement, recorded here for traceability.
- **Advisory (already filed):** the `CROSS-REF` cap is per (pair, territory-path), not per pair, and silent when it truncates — captured in `docs/issues/20260705-surface-capped-cross-ref-facts-in-contracts-check.md`.
