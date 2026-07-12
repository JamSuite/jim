---
spec: "jim/044"
type: "feature"
base_sha: "972869cba205da49ef4ddcda80e1011c6276be89"
head_sha: "cfc7f370cd67b9bc62d5edba4ba24cbaf5125b9c"
commits: "11"
commits_test: "0"
commits_feat: "7"
commits_fix: "0"
commits_refactor: "0"
files_changed: "14"
insertions: "1067"
deletions: "125"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5699"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1139"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "2453"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4161"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "2625"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "604"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-12"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Partition-health sensors (spec 044)

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 1 · **Plan deviations:** 0 · **Security regressions:** 0

Reviewed the spec-044 build over `972869c..cfc7f37` (11 commits, 14 files, +1067/-125): two deterministic script verbs (`jimledger.sh reconcile-series`, `jimpartition.sh health-eval` / `identity-check`), the 15-key reconcile-counter contract, the reconcile-tail health hook, and the read-only `/jim:partition health` mode. Five read-only investigators covered the four script trust boundaries, the structural read-only invariant, and AC completeness. The build faithfully implements the approved plan (10/10 tasks, 563 tests green, no scope creep); one narrow spec-vs-implementation edge on the unarmed-knob notice keeps this at **minor-drift**.

## Alignment

### vs. Spec acceptance criteria
- AC #1, #2, #3, #4, #6, #7, #8, #9, #10, #11, #12, #13 — **met** (fully satisfied; evidence under Investigation).
- AC #5 — **drift (narrow):** the deterministic threshold hook and its silent-by-default behavior are correct on the full-run path, but the hook is gated "full-run path only," so the **nothing-to-reconcile short-circuit** (a project with < 2 blueprint-bearing groups) never emits the one-line *unarmed-knob* notice AC #5/#6 require "when a health knob is set." No crossing is possible on that path (health counters ride as `na`, `breaking=0`), so the only observable miss is that single advisory line on a sub-threshold project. See Finding 1.

### vs. Plan tasks
- Tasks 1–10 — **done**, and only those. No scope creep: the Out-of-Scope set (chronic domain↔domain straddle sensing, issue #43's wholesale SKILL.md restructure, `partition` in the review metrics allowlist, delta/slope predicates, built-in default thresholds, health-value gating, persisted verdict artifact, counter backfill) is all absent from the diff.

### vs. ARCHITECTURE.md
- **Respected.** Bash-vs-Prompt split (facts in scripts, judgment in skills); never-execute-config (thresholds only integer-compared); fixed-key shape-validated counter contract (one shared 15-key whitelist); `set -uo pipefail` / `LC_ALL=C` / no third-party deps (mechanical floor `no-third-party-deps` holds); BASH_SOURCE-relative inter-script composition; verb-scoped permission grants (spec 042 precedent); Gate Presentation rule wired (`gatepresentation.sh` floors updated); both SKILL.md files ≤ 500 lines (blueprint 497, partition 409); one-level agent nesting (health mode spawns no agents). ARCHITECTURE.md itself refreshed via `/jim:arch` (freshness header, tree annotations, specs range → 044, a new spec-044 spec-log paragraph) — pending commit as an administrative artifact.

## Investigation

Depth: thorough. Five `Agent(jim:investigator)` runs (read-only), highest-risk first; all returned within the cap. Investigator evidence is untrusted input — the verdicts below are the reviewer's judgment over that evidence.

### High-stakes regions investigated

#### Shared reconcile-counter contract + `reconcile-series` / `last-reconcile` (`skills/review/scripts/jimledger.sh`)
- locations examined: `jimledger.sh:603-616` (constants), `:618-681` (`RECONCILE_AWK` — `valid_sluglist`, `validate`, BEGIN/match/END), `:683-697` (`reconcile-series`), `:699-722` (`last-reconcile`), `:232-254` (`commit-verify` mode).
- tests checked: `tests/jimledger.sh:897-977` (series ordering/exclusion/na), `:1317-1385` (faces/attribution + commit-verify health/whitelist).
- verdict: **satisfied.** Fixed 15-key whitelist, key names literal (never derived from ledger text); unknown/`op=`/`tier=`/injected keys dropped. Three value classes enforced — INT `^[0-9]+$`; NA adds `na`; SLUG comma-list each `^[a-z0-9][a-z0-9-]*$`, ≤ 256 bytes (byte-accurate under `LC_ALL=C`), empty → fail-closed. `reconcile-series` names an excluded malformed event (`EXCLUDED\t<line>\t<reason>` where reason is always a whitelisted key — carries no untrusted content); rc 0/1/2 correct. `last-reconcile` behavior byte-preserved for legacy 11-key events. `commit-verify` mode whitelisted via `case`; bad mode → rc 2 with no commit; no untrusted token reaches any commit message. Portable awk (`split("",arr)`), correct `read -r -d '' … || true` heredoc idiom.

#### `cmd_health_eval` (`skills/partition/scripts/jimpartition.sh:1112-1181`)
- locations examined: `jimpartition.sh:50-51` (BASH_SOURCE-relative `JIMLEDGER`/`JIMCONF`), `:1126-1138` (threshold classification), `:1143-1154` (latest-value + breaking-run extractor), `:1163-1178` (predicates).
- tests checked: `tests/jimpartition.sh:1039-1116` (9 cases).
- verdict: **satisfied.** Config values only integer-compared, never executed. `active + disabled ≡ 5`; junk → `INVALID`, `0` → silent-disabled, positive → armed (spec 032). Latest-value predicates for cycles/fanin/uncovered/faces_max never cross on `na` or an absent counter (empty string fails `^[0-9]+$`, never coerced to 0); `breaking_runs` counts the trailing consecutive `breaking>0` run, reset on 0 — off-by-one-free at the N=2 boundary. Deterministic THRESHOLDS→INVALID→CROSSED ordering (no associative-array iteration on any output path). rc 0/1/2 correct; firing derives solely from whitelisted counter facts.

#### `cmd_identity_check` (`skills/partition/scripts/jimpartition.sh:1194-1246`)
- locations examined: `:1210-1221` (whitelisted `old=` rename-event parse), `:1229-1242` (foreign/retired emission), `:850-863` (`slug_token_match` reuse).
- tests checked: `tests/jimpartition.sh:1132-1189` (foreign, retired-only-with-specs-dir, token-free silent, non-slug excluded, rc 2).
- verdict: **satisfied.** `foreign` = another current group's whole-token slug; `retired` = `old=` from `partition finished op=rename` events, gated whole-field on `op=rename` and each `old=` value validated to the slug charset (a hand-edited ledger cannot inject a non-slug token). Own-slug and token-free paths never flagged. Four `while read` loops each carry their own stdin redirect with distinct loop variables — no fd clobbering. Map-with-no-`## Groups` → rc 0, no crash.

#### Structural read-only invariant + verb-scoped grants (`skills/partition/SKILL.md`, `skills/blueprint/SKILL.md`)
- locations examined: partition `## Health runs` 296-372 (every `Skill(jim:blueprint)` call site is *outside* it; `:307` is the negation); blueprint frontmatter `:17`; blueprint § Reconcile hook `:431-445`.
- verdict: **satisfied.** The health section has no `Skill(jim:blueprint)` call site and no Write/Edit — the cycle is broken by construction (F2). Blueprint grants `Skill(jim:partition)` + exactly two verb-scoped clauses (`health-eval *`, `identity-check *`), no `jimpartition.sh *` wildcard (F6). `op=health` events are counters-only (`signals=`/`fired=`), self-committed via `commit-verify … health`. The hook runs after Step 3's event + commit-map and fires only on `CROSSED` facts.

#### AC completeness / omission class + scope creep (spec + tree)
- verdict: **12/13 fully satisfied; AC #5 partial (short-circuit unarmed notice); scope creep CLEAN.** The counter-contract doc (`reconcile-methodology.md` § Outcome counters) was updated in the same change to the 15-key contract with the metric>0 attribution-presence rule and display-data-only clause. Prompt-side ACs (#1/#3/#7/#9/#10) are carried in SKILL.md + methodology prose as planned.

### Coverage
- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated (5 of ≤10 cap; no un-investigated remainder). The prompt-side ACs (#3/#7/#9/#10) rest on skill/reference prose with no mechanical test, by design — read directly, not fanned out.

## Living intent

**Sensed:** deterministic floor over the `jim` group (39 judge · 3 pattern · 3 structure · 2 registry invariants) · **holds:** 1 executable-floor invariant (`no-third-party-deps`) · **violations:** 0 · **skipped:** — · **failed/unconfigured:** 2 registry (`skill-line-budget`, no `jimconf.toml`).

### Violations
- **None** — every checked invariant holds. The one executable mechanical-floor invariant (`no-third-party-deps`) holds over the whole group including the 044 changes; no drift detected.

### Coverage
- appetite in force: low (thorough) — bounded for this run (see below).
- Whole-group deterministic floor ran (`jimverify.sh check … jim`).
- judges: **bounded — the 39 judge-rung invariants were NOT fanned out this run.** The blueprint-governed constraints this build touches (SKILL.md line budgets, the fixed-key counter contract, bash-script conventions, never-execute-config) were instead deep-verified across the alignment dimension by the five investigators above, and the deterministic floor is clean. A documented bounded-coverage decision (the sensor's containment clause), proportionate to a change already exhaustively investigated and to the project's cost posture — not an engine failure.
- registry: 2 configured in the blueprint but `unconfigured` at runtime (no `jimconf.toml`); the `skill-line-budget` check's intent (SKILL.md ≤ 500) was confirmed directly (blueprint 497, partition 409).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 11 (0/7/0/0) |
| Files changed · insertions · deletions | 14 · +1067 · -125 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 5699s·1139s·2453s·4161s·2625s·604s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec, research, security, plan, ledger |

Note: `commits_test` is 0 because each task bundled its Red test with its Green code in one `feat`/`docs` commit (jim's per-verb commit convention), not because tests were absent — the build added ~30 new test cases across four test files (563 total green).

## Security regressions

- **None identified.** The four trust boundaries were verified intact: the injection-proof 15-key whitelist (no key from ledger text; slug-list bounded and fail-closed), never-execute-config (thresholds integer-compared only), the whitelisted slug-gated `old=` rename-event parse, and the `case`-whitelisted commit-verify subject (no untrusted token reaches a commit message). Attribution keys admit at most a well-formed, length-capped slug list from a tampered ledger, consumed as display data only (the 028 Finding-1 bounded-value pattern). All 6 pre-build security findings remain resolved.

## Findings

### 1. Unarmed-knob notice is not emitted on the nothing-to-reconcile short-circuit

- **Priority:** low
- **Description:** AC #5/#6 require the reconcile report to note in one line that the hook is unarmed whenever `require_health` / `auto_health` is truthy but no valid threshold is configured. The health hook is gated "full-run path only" (`blueprint/SKILL.md:431`), and the nothing-to-reconcile path (< 2 blueprint-bearing groups) skips straight to close (`:399-401`), so on that path a truthy-but-unarmed knob produces no notice. Impact is narrow: no crossing is possible there (health counters are `na`, `breaking=0`), so the only miss is the single advisory line — and only on a sub-threshold project, which is precisely where a misconfigured operator would most benefit from being told "health knobs set but you don't have enough groups yet."
- **Suggestion:** Either surface the unarmed-knob notice from the nothing-to-reconcile branch too (resolve the two knobs there and note if truthy), or tighten AC #5/#6's wording to scope the notice to the full-run path. A one-line skill-prose change; no script change needed.
- **Relates to:** AC #5, AC #6; `blueprint/SKILL.md:399-401,431-445`

<!-- Investigated and REFUTED, recorded so it is not re-raised: two investigators flagged
     blueprint's `identity-check` grant as an unused over-grant, assuming a nested skill runs
     under its own frontmatter. jim's documented model is the opposite (ARCHITECTURE.md, spec 036):
     an inline nested skill's tool calls execute in the caller's main thread, UNDER THE CALLER'S
     GRANTS. So blueprint→Skill(jim:partition) health runs the health section's identity-check call
     under blueprint's grants — the grant is required. Security F6 / plan Task 7 are correct. -->

## Deviations & feedback

- **A dual-lens security pass paid off:** the sec stage ran twice (2 runs, 4161s total) — the second, plan-phase pass produced F5 (spec↔plan misalignment) and F6 (verb-scope the new grant), both routed before build. The build carried zero security regressions as a result.
- **The `commits_test=0` metric is a known artifact of jim's per-verb commit convention** (test+code bundled), not a TDD gap — worth remembering when mining review metrics across specs.
- **One follow-on already filed this session:** `20260712-compute-reconcile-face-size-counters-deterministically` (low) — Step 2a derives `faces=`/`faces_max=`/`faces_max_group=` by LLM row-counting of `jimverify.sh faces` output rather than a deterministic aggregator, a small tension with the "every counter is script-emitted" doctrine. Tracked, not re-raised here.
