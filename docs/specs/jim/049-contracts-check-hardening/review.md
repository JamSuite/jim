---
spec: "jim/049"
type: "refactor"
base_sha: "74a012b749acecd75442e66be6e2b0eb5d761c15"
head_sha: "a563c154399ab98205fd09252ba16fa2f455302f"
commits: "9"
commits_test: "5"
commits_feat: "0"
commits_fix: "1"
commits_refactor: "2"
files_changed: "7"
insertions: "164"
deletions: "40"
spec_runs: "2"
spec_interruptions: "0"
spec_duration_seconds: "3861"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "764"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1928"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "2120"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1622"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "493"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "0"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-23"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: Harden contracts-check — blueprint-slot resolver, self-edge guard, edge-outcome tests

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 2 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the spec-049 refactor of `skills/verify/scripts/jimverify.sh` over build range
`74a012b..a563c15` (9 commits, +164/-40). Every substantive acceptance criterion is
satisfied — three independent investigators confirmed the resolver switch is byte-identical,
the single self-edge guard propagates to all consumers, and no live caller was missed; 91/91
tests pass. The one blemish is documentation: two AC-#3-scoped docs describe the change-set
`files-list` as "the 3rd arg," a residual ordinal introduced by the fix that is confusing under
the new 2-positional signature — hence minor-drift.

## Alignment

### vs. Spec acceptance criteria
- AC #1 (all blueprint paths via the resolver; no hand-composed string) — **met**. Zero
  `000-blueprint` construction remains in `jimverify.sh`; all three sites route through
  `jimfile.sh path blueprint`.
- AC #2 (output unchanged by the resolver switch) — **met**. Resolver output is byte-identical
  to the old `$specs_root/…` string in both the test path (PWD=fixture, no `jimconf.toml` →
  default `docs/specs`) and production; 91/91 tests green.
- AC #3 (`<specs-root>` removed; all callers on the new signatures, no dead parameter) — **drift**.
  Functionally met — the positional is gone from both verbs and every *live* caller (verify
  SKILL, both methodology docs, all test invocations, `blueprint/SKILL.md:414`, and
  `ARCHITECTURE.md`) is on the new signature. Residual: `skills/verify/SKILL.md:87` and
  `skills/verify/references/contracts-methodology.md:147` still call `files-list` "the 3rd arg,"
  a trace of the removed middle positional (Finding 1).
- AC #4 / #5 / #6 (self-edge → no outcome / HYGIENE row / excluded from health) — **met**. One
  guard `&& c1 != c3` at `cmd_edges:786`; all three consumers inherit the exclusion via existing
  HYGIENE skips (`:955`, `:1008`, and faces-aggregate transitively via `:1195`).
- AC #7 (consumer-ref abstain) / AC #8 (location-only edge evidence) — **met**. Pinned by new
  characterization tests; the abstain and `cut -d: -f1,2` behaviors were pre-existing.
- AC #9 (behavior preserved except signature call-sites + missing-args arity) — **met**.

### vs. Plan tasks
- Tasks 1–8 — **all done**, each committed with its Verify green (see Metrics).
- One authorized scope expansion beyond the plan's File Manifest: `skills/blueprint/SKILL.md`
  was updated (Task 2 fold-in). It is a genuine live caller AC #3 requires updating, so this is
  the build satisfying the spec more completely than the plan's manifest enumerated — approved
  mid-build, not unplanned creep. The plan's File Manifest was not amended to list it (see
  Deviations & feedback).

### vs. ARCHITECTURE.md
- Conventions respected. The living-intent sensor confirmed `blueprint-slot-reserved`,
  `untrusted-content`, and `no-third-party-deps` hold over the change. The stale
  `contracts-check`/`faces-aggregate` signatures in `ARCHITECTURE.md:270/:385` were refreshed
  via `/jim:arch` (pipeline-owned, outside the build range).

## Investigation

<!-- Auditable depth record; locations only. -->

### High-stakes regions investigated

#### AC #3 — caller completeness (omission class)
- locations examined: `skills/verify/scripts/jimverify.sh:73,143,145,880-899,1152-1157`;
  `skills/verify/SKILL.md:87`; `skills/verify/references/contracts-methodology.md:146-147`;
  `skills/verify/references/retirement-methodology.md:179`; `skills/blueprint/SKILL.md:414`;
  `ARCHITECTURE.md:270,385`; `tests/jimverify.sh` (all invocations)
- callers/consumers traced: every repo-wide invocation of both verbs, classified live vs
  historical (`docs/specs/**` frozen plans correctly left untouched)
- tests checked: `tests/jimverify.sh` contracts-check (`:852-1112`) + faces-aggregate sections
- verdict: **satisfied with a note** — no live caller on the old signature; residual "3rd arg"
  ordinal in two live docs (Finding 1). Confirmed a stale `contracts-check` caller would *break*
  (a `<specs-root>` in `$2` is misread as the files-list → empty scope, silent no-results), so
  scrubbing callers was functionally necessary, not cosmetic.

#### AC #4 / #5 / #6 — self-edge guard propagation
- locations examined: `jimverify.sh:786-787` (guard/HYGIENE), `:954-955` (edge-outcome skip),
  `:1006-1034` (health awk), `:1195` (faces-aggregate via cmd_health), `:929` (CROSS-REF self-skip)
- callers/consumers traced: all consumers of `cmd_edges` output (grep exhaustive: `:954`, `:1006`)
- tests checked: `case_jimverify_edges_self_pair_*`, `_health_self_loop_excluded`,
  `_contracts_self_edge_no_outcome`
- verdict: **satisfied** — one guard covers all three ACs; without it, a `c→c` row would survive
  the health Kahn peel as a spurious 1-node cycle. CROSS-REF self-exclusion is the independent
  pre-existing `:929` skip; AC #5 visibility is `cmd_edges`' own `:787` emission.

#### AC #1 / #2 — resolver routing correctness & safety
- locations examined: `jimverify.sh:906,912,957-958,1166-1167,132`; `jimfile.sh:662-676,168`;
  `jimconf.sh:50,266,309-319`
- callers/consumers traced: all three resolver call sites → their slug guards → the resolver's
  own `is_valid_slug`
- tests checked: `tests/jimverify.sh:303-309` (run_jimverify_in), contracts/faces fixtures
- verdict: **satisfied** — no hand-composed path; every site slug-gates before the shell-out
  (regex identical to `is_valid_slug`); byte-identical output; resolver rc≠0 impossible in the
  guarded path and caught safely by the downstream `[[ -f ]]` guards regardless.

### Coverage
- Depth: thorough; review_model: inherit (investigators ran the session model).
- Full high-stakes set investigated — 3 investigators, no fan-out cap reached (cap 10).

## Living intent

<!-- The blueprint sensor's dimension; distinct from the alignment verdict above (never sets it). -->

**Sensed:** 34 invariants · **holds:** 3 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 30 · **failed/unconfigured:** 1

### Violations
- None — every checked invariant holds. Notably `blueprint-slot-reserved` (high) — the very
  invariant a spec-037 living-intent sensor flagged to spawn this spec — now **holds**: the sole
  slot-construction point is the resolver (`jimfile.sh:675`); `jimverify.sh` carries no
  `000-blueprint` literal. `untrusted-content` (critical) **holds** — the self-pair HYGIENE
  branch reuses the same `san()`, subprocess group args are slug-gated, evidence stays
  location-only; the judge characterized the change as a *tightening*.

**Sensor observation (not a violation):** `skills/partition/scripts/jimpartition.sh:962,1057,1218`
build the `000-blueprint` **directory** path by hand for `-d` existence probes. These are out of
scope for `blueprint-slot-reserved` (which governs the spec.md *slot* path, resolved via
`path blueprint`), so the invariant holds — but they are the only remaining direct
`000-blueprint` directory-name references in production, and the resolver has no directory-yielding
verb to absorb them. Tracked as a follow-on (Finding 2).

### Coverage
- appetite in force: low (all judge invariants in-appetite; none appetite-skipped).
- Whole-group floor ran (territory declared; single-group repo — the 365-file territory set is
  scaffolding-dominated by design, no changed file is a stray).
- judges: change-selected (2 judged: `blueprint-slot-reserved`, `untrusted-content`), all within cap.
- skipped by scope: 30 — the change did not touch them · skipped by appetite: 0.
- registry: 0 configured — `skill-budget` reports `unconfigured` (`verify_command_skill-line-budget`
  unset; the change added no SKILL.md lines).

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 9 (5/0/1/2) |
| Files changed · insertions · deletions | 7 · +164 · -40 |
| Stage runs (spec·research·plan·sec·build·review) | 2·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 3861s·764s·1928s·2120s·1622s·493s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. The refactor *reduces* external input surface (dropped a positional) and
  *tightens* map-row handling (self-pair → sanitized HYGIENE). The `untrusted-content` judge
  confirmed sanitization, data-not-instructions (slug-gated subprocess args), and location-only
  evidence all preserved, with no new persist/injection path.

## Findings

### 1. Residual "3rd arg" ordinal under the new signature

- **Priority:** low
- **Description:** `skills/verify/SKILL.md:87` and `skills/verify/references/contracts-methodology.md:147`
  describe the change-set `files-list` as "the 3rd arg." That ordinal is consistent with the docs'
  original subcommand-counting convention (the pre-refactor text said "4th arg"), but under the new
  `contracts-check <map> [files-list]` signature `files-list` is the 2nd positional (`$2` in
  `cmd_contracts_check`), so "3rd arg" reads as a residual trace of the removed `<specs-root>`.
- **Suggestion:** Drop the confusing ordinal — e.g. "the change set as the `files-list` argument
  scopes…" / "add the change-set files-list only in scoped/triggered runs." (A 2-line doc tweak.)
- **Relates to:** AC #3

### 2. `000-blueprint` directory name still hand-built in jimpartition.sh

- **Priority:** low
- **Description:** `jimpartition.sh:962,1057,1218` construct `"$specs_dir/$old/000-blueprint"`
  (the directory) for rename/split/merge `blueprint-exists` probes. Not a `blueprint-slot-reserved`
  violation (that invariant governs the spec.md slot path, which resolves via `path blueprint`),
  but it is the last direct literal-coupling to the reserved directory name in production code.
- **Suggestion:** If full single-sourcing is desired, add a directory-yielding form to the resolver
  (e.g. `jimfile.sh path blueprint-dir <group>`) and route these three probes through it. Out of
  scope for 049 (`jimpartition.sh` was untouched); track as a hardening follow-on.
- **Relates to:** blueprint-slot-reserved (living-intent sensor)

## Deviations & feedback

- **Caller enumeration under-scoped upstream.** The spec, research, and plan all enumerated the
  AC-#3 callers as "the verify skill, its methodology docs, and the tests" and missed a live
  caller (`blueprint/SKILL.md:414`). It surfaced only at build time via a repo-wide grep and was
  folded in with sign-off. Signal for future refactor research: enumerate callers by a mechanical
  repo-wide sweep of the changed symbol, not by reasoning about "where it's probably used." The
  plan's File Manifest was not amended to list the added file — the commit records the reality.
- **Clean process trajectory.** Zero interruptions across all six instrumented stages; the one
  security re-run was the intended dual-lens plan-phase pass, not a re-plan.
