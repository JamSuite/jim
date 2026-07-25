---
spec: "blueprint/011"
type: "feature"
base_sha: "e0cf9bad038e83f903762d412210eaa55e41d4e8"
head_sha: "9f76ef1942daaf6b6349ba8f0a2a1b59123da3a0"
commits: "8"
commits_test: "0"
commits_feat: "4"
commits_fix: "0"
commits_refactor: "0"
files_changed: "9"
insertions: "658"
deletions: "23"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "1760"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "415"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1259"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "1613"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "1629"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "543"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "0"
security_regressions: "1"
invariant_violations: "0"
contract_violations: ""
alignment: "minor-drift"
date: "2026-07-07"
---

# Review: Graph-health metrics in the reconcile pass

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 4 · **Plan deviations:** 0 · **Security regressions:** 1

Reviewed spec 039 over `e0cf9ba..9f76ef1` (8 commits, 9 files, +658/−23). The
feature is functionally complete and correct — all ten ACs work, 434/434 tests
pass, and four deep investigators plus one blueprint judge found no correctness
or security defect in the shipped runtime path. The drift is on AC #4's
"documented contract updated in the same change" clause: the code consumer and
the primary contract doc were updated, but three secondary contract-describing
docs still say "seven counters." One low-severity hardening inconsistency in
the new coverage awk was also surfaced.

## Alignment

### vs. Spec acceptance criteria
- AC #1, #3, #5, #6, #7, #8, #9, #10 — met. Health verb computes all four
  measurements deterministically; report is measurement-only; events are
  content-free (numbers/`na`, names in report); coverage names dirs + carries
  the count; `na`+reason keeps not-computable distinct; short-circuit rides `na`
  not zeros; reconcile otherwise unchanged, health never vetoes.
- AC #2 — met. `last-reconcile` gives the delta source; baseline (rc 1) and
  malformed-prior-degrades-named (rc 2) are wired in SKILL.md step 2a.
- AC #4 — **drift.** The event carries all eleven counters and the primary
  documented contract (`reconcile-methodology.md` § Outcome counters) plus the
  one code consumer (`cmd_last_reconcile`, validates the eleven-key set) were
  updated in the same change. But "the documented counter contract … updated in
  the same change so every consumer validates the extended set" was left
  incomplete for three secondary contract-describing docs — see Findings 1–3.

### vs. Plan tasks
- Tasks 1–6 — done, and only the tasks. All 9 changed files map to the plan's
  File Manifest (the two scripts, two test files, SKILL.md, methodology) plus
  expected housekeeping (ARCHITECTURE.md refresh, ledger, plan marks). No scope
  creep. `commits_test=0` is not a coverage gap — TDD tests rode inside the four
  `feat:` commits per this repo's established convention.

### vs. ARCHITECTURE.md
- Bash-vs-Prompt split, content-free ledger, no-standing-verdict, POSIX-only
  conventions — respected. ARCHITECTURE.md was refreshed via `/jim:arch` (not
  hand-edited). One component bullet left stale — Finding 3.

## Investigation

### High-stakes regions investigated

#### Health graph metrics (`jimverify.sh cmd_health` graph awk)
- locations examined: `skills/verify/scripts/jimverify.sh:864-921` (dedup / Kahn
  peel / union-find / fan-in / isort), `:635-658` (upstream slug gate)
- callers/consumers traced: consumes `cmd_edges` stdout only; slug validation is
  the sole upstream trust boundary
- tests checked: `tests/jimverify.sh:926-1087` (acyclic, mutual pair, two
  disjoint, shared-node tangle, fan-in ties, empty graph, no-section rc2,
  crafted-cell, determinism)
- verdict: satisfied — cycle clustering correct for every required case (and
  untested-but-correct length-3 cycles and source/sink tails); determinism is
  genuinely hash-order-independent (cluster ids minted at each cluster's minimum
  node); fan-in dedup + ties complete/sorted; no sentinel collision (HYGIENE
  uppercase vs lowercase slugs)

#### Territory coverage (`jimverify.sh cmd_health` coverage block)
- locations examined: `skills/verify/scripts/jimverify.sh:929-976`, twins at
  `:452-478` (check_conformance), `:277-283` (path_under)
- tests checked: `tests/jimverify.sh:1090-1192` (coverage_zero, stray+dir
  aggregation, no-territories, no-git)
- verdict: satisfied — slash-anchored prefix match (no false covered/uncovered:
  `accounts` does not cover `accountsfoo/`), na precedence correct
  (territory-less before git), `na` never emitted as `0`, control-chars stripped
  + length-capped + dir-aggregated (Finding 1 met), git rc captured to detect a
  non-repo. One low-severity hardening caveat — see Security regressions.

#### Prior-event parser (`jimledger.sh cmd_last_reconcile`)
- locations examined: `skills/review/scripts/jimledger.sh:466-516`, `:534`
  (dispatch)
- tests checked: `tests/jimledger.sh:813-895` (rc1 none, latest wins, pre-039
  seven-counter, junk→rc2, unknown-key dropped, na health-only)
- verdict: satisfied — `op=reconcile` anchored with both `;` delimiters
  (`xop=reconcile` / `op=reconcileX` cannot match); two-barrier whitelist closes
  Finding 4 at source; int-or-na correct (`edges=na`→rc2, `uncovered=na`→ok);
  rc semantics correct (missing ledger→1, malformed→2 with no stdout)

#### Omission class + wiring (SKILL.md, methodology, contract consumers)
- locations examined: `skills/blueprint/SKILL.md:411-446, :476-477`,
  `reconcile-methodology.md:244-342`, repo-wide grep for reconcile-counter
  consumers
- verdict: partial — core fully satisfied; independently confirmed there is no
  code consumer of the reconcile counters besides `last-reconcile` (research's
  claim holds), but three docs describing the counter contract remain at "seven"
  (Findings 1–3)

### Coverage

- Depth: thorough; review_model: inherit (session model).
- Full high-stakes set investigated — 4 investigators, no fan-out cap reached
  (cap 10). No region left un-investigated.

## Living intent

**Sensed:** 31 invariants · **holds:** 11 · **violations:** 0 (in-change 0 · pre-existing 0 · unlocalized 0) · **skipped:** 19 · **failed/unconfigured:** 1

### Violations

- None — every checked invariant holds. Notably, `reconcile-durable-record`
  (high) was judged `holds`: the code upholds every requirement (all seven
  finding counters still emitted zeros-included, `tier=project op=reconcile`
  event at the specs root, `commit-map` close, a shape-validating consumer). Its
  invariant *text* under-describes the now-eleven-counter reality — a
  blueprint-text fold (seven → eleven + the int-or-na carve-out), **not** a code
  breach. See Finding 2; routed to the Step-10 blueprint update.

### Coverage

- appetite in force: low (judge everything change-selected; no per-group
  override).
- Whole-group floor ran (`no-third-party-deps` holds). Territory conformance
  reported 279 files outside the `jim` group's declared territory — a
  **pre-existing** partition characteristic; none of this build's 9 changed
  files are new strays, so there are no in-change conformance violations. Not
  filed (filing 279 pre-existing paths would be alarm fatigue).
- judges: change-selected, all within cap — 10 selected; 1 dispatched to
  `Agent(judge)` (`reconcile-durable-record`, the one routing-relevant call),
  the other 9 assessed `holds` from the concurrent deep-investigator evidence +
  direct inspection (allowed-tools, sigil).
- skipped by scope: 19 (the change did not touch them) · skipped by appetite: 0.
- registry: `skill-budget` → `unconfigured` (no `verify_command_skill-line-budget`;
  SKILL.md is 477 ≤ 500 regardless). Contract-edge phase did not run —
  single-group project, no cross-group edges.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 8 (0/4/0/0) |
| Files changed · insertions · deletions | 9 · +658 · −23 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 1760s·415s·1259s·1613s·1629s·543s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- **Low — coverage awk tab-field-split** (`skills/verify/scripts/jimverify.sh:958`).
  The coverage set-difference awk is `-F'\t'` and takes the territory prefix from
  `$2`. `valid-relpath` (upstream) rejects absolute / `..` paths but not a
  literal TAB *inside* a path, and `cmd_territory`'s trim strips only
  leading/trailing whitespace — so a crafted map territory `` `foo<TAB>bar/` ``
  would field-split to `$2="foo"`, broadening the prefix and marking files under
  `foo/` as false-covered. Reachability is exotic (a tab byte inside a backticked
  territory cell), but map content is untrusted data, and the bash twin
  `check_conformance` is immune (glob-based, not `-F'\t'`). Suggestion: strip or
  reject tabs in the territory prefix before the `-F'\t'` awk, aligning the two
  set-difference implementations.

## Findings

### 1. WORKFLOW.md Reconcile section omits graph-health

- **Priority:** medium
- **Description:** `WORKFLOW.md:428-433` (the canonical Reconcile process
  section) has no graph-health mention and still states findings are "durably
  counted … `op=reconcile`, all seven counters." Not wrong about *findings*
  (there are still seven finding counters), but the whole graph-health capability
  and the eleven-counter event are absent from the canonical process doc.
- **Suggestion:** Add a graph-health bullet to the Reconcile section and update
  the counter count to eleven (seven findings + four health).
- **Relates to:** AC #4

### 2. `reconcile-durable-record` invariant text stale (seven → eleven)

- **Priority:** medium
- **Description:** `docs/specs/jim/000-blueprint/spec.md:201` — jim's own
  `reconcile-durable-record` invariant (judge-checked) still says "the finished
  line carrying all seven counters … consumers shape-validate the fixed key set."
  The living-intent judge confirmed the code *holds* the invariant (the seven are
  a preserved subset of eleven), but the text under-describes reality and will
  drift against code on the next `/jim:verify jim`.
- **Suggestion:** Fold the invariant text to eleven counters, noting the four
  health counters and the int-or-na carve-out. Best done through the Step-10
  blueprint update (`/jim:blueprint --from-review`) so it rides the group's own
  surface.
- **Relates to:** AC #4; living-intent sensor

### 3. ARCHITECTURE.md jimledger component bullet stale

- **Priority:** low
- **Description:** `ARCHITECTURE.md:357` (the jimledger.sh component bullet)
  still carries the spec-034 "seven always-emitted counters … no script change"
  sentence and omits the new `last-reconcile` verb. Mitigated by the dedicated
  039 paragraph at `:249`, so it is a component-narrative completeness gap, not a
  contradiction.
- **Suggestion:** On the next `/jim:arch` refresh, update the jimledger bullet's
  verb list and drop the "no script change" clause.
- **Relates to:** AC #4; ARCHITECTURE.md

### 4. Coverage awk tab-field-split hardening

- **Priority:** low
- **Description:** See Security regressions — the new coverage awk's `-F'\t'`
  territory-prefix handling diverges from the immune glob-based bash twin.
- **Suggestion:** Strip/reject tabs in the territory prefix before the `-F'\t'`
  awk.
- **Relates to:** AC #6; security.md Findings 1/5 lineage

## Deviations & feedback

- **Plan deviations: none** — the build executed all six plan tasks as written,
  green on each, with no scope creep.
- **AC #4 was under-decomposed in the plan.** Tasks 4/5 scoped the
  counter-contract update to SKILL.md + reconcile-methodology.md, but AC #4's
  "every consumer / the documented contract updated in the same change" clause
  also implicates WORKFLOW.md and the checkable `reconcile-durable-record`
  invariant — neither was in the File Manifest. A future counter-contract change
  should enumerate every contract-describing home (methodology, SKILL.md,
  WORKFLOW.md, the 000-blueprint invariant, ARCHITECTURE.md) in the plan.
- **Test-strengthening opportunities** (quality, not correctness): the
  determinism test asserts same-input-twice — it would still pass if the sort
  were dropped; a fixed expected byte-string or a direct ordering assertion is
  stronger. No coverage case pins the adjacent-prefix boundary
  (`accountsfoo/` under territory `accounts/`) or the control-char strip on an
  uncovered filename, and self-loop / duplicate-row graph semantics are
  unspecified by test.
