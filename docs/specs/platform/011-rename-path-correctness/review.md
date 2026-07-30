---
spec: "platform/011"
type: "bug"
base_sha: "cd4eeaa2e021b4e4be1efce4349366a72f9b3d26"
head_sha: "576527addf95e7b7ecd770d9ca354882f6137bbf"
commits: "10"
commits_test: "4"
commits_feat: "3"
commits_fix: "2"
commits_refactor: "0"
files_changed: "3"
insertions: "543"
deletions: "60"
spec_runs: "3"
spec_interruptions: "0"
spec_duration_seconds: "10014"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "621"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "5810"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "4167"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "3341"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "220"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "1"
security_regressions: "0"
invariant_violations: "0"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-07-30"
---

# Review: Rename-path correctness gates

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 6 · **Plan deviations:** 1 · **Security regressions:** 0

Reviewed the 10-commit build `cd4eeaa..576527a`, which corrects four defects in
`platform/007`'s frozen resolution and next-id semantics across one script and
one test file. Every acceptance criterion is satisfied and each of D1–D4 has a
fixture that failed before its fix; the verdict is minor-drift on two gaps in
what the build *proved* rather than what it does — the acknowledgment path
through `allocate spec` shipped unfixtured, and the function whose call shape
changed still documents its old signature.

## Alignment

### vs. Spec acceptance criteria

- **AC 1** (rename-destination-established id resolves to its current referent,
  spec and issue) — met. Both sides fixtured; both reproduced the exact wrong
  values the Defect Profile recorded before the fix.
- **AC 2** (resolution reflects the most recent establishing event) — met.
- **AC 3** (vacated ordinal never reissued for **every** log shape, including an
  unallocated rename source) — met.
- **AC 4** (miscounting errs only toward skipping; an over-wide ordinal is
  skipped as malformed) — met, both kinds. Every fold path only ever raises.
- **AC 5** (every ordinal the allocator can mint is one the bootstrap accepts,
  from one shared value) — met. One `ALLOC_MAX_ORD_DIGITS`, read by the fold and
  by both bootstrap guards; a round-trip fixture mints `core/1000` and seeds it.
- **AC 6** (next id accounts for current and former group names, multi-hop) —
  met, including a crafted cycle.
- **AC 7** (a renamed-away group is refused, naming the redirect, until
  acknowledged; the answer carries the current group) — met in behavior,
  verified by hand end-to-end at the CAS path. **Drift:** only the `peek spec`
  half is fixtured (Finding 2).
- **AC 8** (allocation and reconcile agree for every log shape, malformed
  records included) — met. The parity fixture asserts the two values are equal
  rather than asserting a constant, so it cannot pass by coincidence.
- **AC 9** (record grammar unchanged; this fix writes no record) — met. No git
  call added or changed; both live logs still hold **0** rename records.
- **AC 10** (every shipped `platform/007` behavior still holds, fixtures
  unmodified) — met, and stronger than the plan expected: all four shipped case
  bodies are **byte-identical** to their plan-approval state (md5-compared), not
  merely still passing.
- **AC 11** (regression test per defect) — met, D1 (×2), D2, D3, D4.
- **AC 12** (registry-read values revalidated at the id/slug boundary) — met.
- **AC 13** (bash + POSIX, parse as data, no third-party deps) — met in the
  script. The test suite acquired a `timeout` dependency (Finding 4).

### vs. Plan tasks

- **Tasks 1–9, 11–12** — done, in order, with Red confirmed by Bash output
  before every Green.
- **Task 10** (rewrite the `alloc_next_id_spec` docstring) — **done, but as part
  of task 7 rather than as its own step.** Its Verify was already satisfied when
  reached, because leaving a knowingly-false docstring across an intermediate
  commit would have violated the comment convention. Recorded as the plan
  deviation; a swept re-check found no other claim this work staled.
- **No scope creep.** All 14 source hunks fall inside the File Manifest's two
  files and map to a named task.

### vs. ARCHITECTURE.md

- Bash + POSIX only, no third-party deps — respected in `skills/`; see
  Finding 4 for `tests/`.
- `set -uo pipefail`, `export LC_ALL=C` — respected (no new script file).
- `BASH_SOURCE`-relative composition — respected; the `$JIMFILE` chain untouched.
- Single `is_valid_id` boundary, no fourth validator copy — respected. Every new
  token read routes through `alloc_valid_token` / `alloc_valid_specid`.
- Registry parsed as data, never sourced/eval'd — respected; all new reads are
  `read -r` field splits.
- Operational git: plumbing only, fixed refs — respected; the new fold and alias
  map are pure and touch no git.
- Reserved `000-blueprint` slot ignored by `next-id` — respected; ordinal `000`
  folds to 0 and cannot raise a high-water.

## Investigation

Investigated inline rather than via an `Agent(investigator)` fan-out — the
operator's standing instruction is no agent dispatch unless asked, the same
course taken at the research phase. Depth is thorough in coverage; the
difference is who did the reading.

### High-stakes regions investigated

#### `alloc_next_id_spec` — changed call shape and return semantics (omission class)
- locations examined: `skills/file/scripts/jimalloc.sh:397-455`
- callers/consumers traced: **repo-wide.** `alloc_build_spec:1062` and
  `cmd_peek:1246` are the only call sites; a repo-wide grep for `peek spec` /
  `allocate spec` / `next_id_spec` outside `jimalloc.sh`, `tests/`, and docs
  returns **no production consumer**. The spec-side verbs are still unwired —
  issues #112/#113 own that wiring — so the new refusal reaches no caller today.
- tests checked: `tests/jimalloc.sh:239-290`, `:304-388`, `:434`
- verdict: satisfied — with the fixture gap at Finding 2.

#### `alloc_group_alias_map` — new helper over untrusted input
- locations examined: `skills/file/scripts/jimalloc.sh:262-311`
- pre-existing equivalents checked: the resolvers' inline group-redirect replay
  (`:195-196`) is the only prior chain-walk; the new helper reports the *same*
  walk (file order, each record at most once) rather than a second semantics, so
  the map and resolution cannot disagree — which is what AC 6 requires.
- verdict: satisfied. Termination is structural (each record defers only to a
  strictly later one), not guarded. Measured linear: 200/400/800 records →
  10s/20s/45s.

#### `alloc_fold_max_spec` / `alloc_fold_max_issue` — shared by three callers
- locations examined: `:314-393`
- callers traced: `:445` (next-id), `:459` (next-num), `:534`
  (reconcile) — all three of research's sites now read one fold each.
- tests checked: `tests/jimalloc.sh:398-460`
- verdict: satisfied. Each rename endpoint is validated independently, so a
  malformed source does not suppress a valid destination.

#### Ordinal legality across the read path and the bootstrap (AC 5)
- locations examined: `:261` (constant), `:353`, `:389`, `:448` (read path),
  `:638`, `:685` (bootstrap)
- verdict: satisfied. Checked the asymmetry directly: the fold reads a record
  ordinal and the seed reads a directory ordinal, but both apply the same
  digit-length rule to the same string form, and `printf '%03d'` can never emit
  a 16-character ordinal — so no ordinal exists that one accepts and the other
  refuses. See Finding 5 on the predicate's duplication.

#### Both resolvers' anchor change (D1)
- locations examined: `:183`, `:237`
- verdict: satisfied. Traced against all four shipped resolution fixtures plus
  both reproductions; moving the anchor later only shrinks the replay window, so
  cycle termination is preserved. A rename *source* still does not anchor.

#### `alloc_reconcile_realize` — two-pass split (D4)
- locations examined: `:528-556`
- verdict: satisfied. The numeric gate and the durable-id gate are now separate:
  any numeric ordinal counts toward the high-water, only a boundary-valid
  durable id becomes a matchable identity.

#### `alloc_build_spec` — changed positional arity (omission class)
- locations examined: `:1047-1071`; call site `:1191`
- callers traced: `alloc_cas_append:995` invokes it as
  `"$builder" "$current_log" "$@" "$who"`, so the new flag appends *before*
  `<who>` and the 5-positional signature matches. Only one caller exists.
- verdict: satisfied. Verified by hand that the redirect check inside the builder
  runs against the log the attempt lands on, and that the emitted `group
  allocate` record names the **current** group.

#### Live-registry parity (regression risk)
- verdict: satisfied. `peek spec platform` = `platform/011` and `peek issue` =
  `135`, identical before and after the change; both logs hold 0 rename records,
  confirming all four fixes are pre-emission rather than migrations.

### Coverage

- Depth: thorough; `review_model: inherit`.
- Full high-stakes set investigated (8 regions) plus all 13 ACs. No fan-out cap
  applied — the investigation was inline, so `review_fanout_cap` did not bind.
- Instrumentation note: the build range excludes the four administrative commits
  that followed `build finished` (ledger close, arch refresh, filed issues), so
  the metrics measure code change only.

## Living intent

**Sensed:** 9 invariants · **holds:** 9 · **violations:** 0 (in-change 0 ·
pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 0

### Violations

- None — every checked invariant holds.

One in-change **observation** that is not a violation of any invariant as
written: `no-third-party-deps` scopes its pattern check to `skills/` and names
`jq|yq|bats`, so the new `timeout` call in `tests/` is outside both the scope and
the pattern and the invariant holds mechanically. Its prose ("bash + POSIX
only") would arguably want a non-POSIX test dependency named. Carried as
Finding 4 rather than recorded as a violation.

### Coverage

- appetite in force: `low`.
- Whole-group floor ran (territory declared; `platform` conformance set clean).
- judges: run inline per the operator's no-dispatch instruction, change-selected;
  no cap bound. All 9 invariants assessed against the diff, not sampled.
- skipped by scope: 0 · skipped by appetite: 0.
- registry: 1 mechanical check configured (`no-third-party-deps`, pattern).
  `relpath-validation` and `ledger-commit-discipline` are vacuously satisfied —
  the build added no path input and did not touch `jimledger.sh`.

### Contracts

**Edges checked:** 1 · **holds:** 1 · **violations:** 0 (provider-side 0 ·
consumer-side 0)

- None — every checked edge holds. The graph names `platform` as provider on 11
  edges; the build touched provides-side code for exactly one,
  `issue → jimalloc (jimalloc.sh ID coordination allocator)`. That consumer uses
  only the issue verbs (`allocate issue` via `skills/issue/scripts/new.sh`,
  `reconcile issue` via `reconcile.sh`, `peek issue` via the skill), none of
  which gained a failure mode; their stdout shapes are unchanged and their live
  values are unchanged (`peek issue` = 135 before and after). The face's
  guarantee clause — durability-before-return, CAS tiering, provisional
  disjointness — is untouched. `contracts-check` reports `COVERAGE 4 4` with no
  violation facts.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 10 (4/3/2/0) |
| Files changed · insertions · deletions | 3 · +543 · -60 |
| Stage runs (spec·research·plan·sec·build·review) | 3·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 10014s·621s·5810s·4167s·3341s·220s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- **None identified.** Three newly-consulted untrusted fields — a rename
  source's ordinal, group tokens from `group rename` records, and an ordinal
  whose sibling durable id is invalid — each pass the established boundary
  (`alloc_valid_specid` / `alloc_valid_token` → `jimfile.sh valid-id`) or a
  numeric-class plus width check before use, and the new code reaches no git
  command, ref, or path. Every fold path can only *raise* a high-water, so a
  crafted record wastes an ordinal rather than causing reuse.
- Two **accepted trades**, both pre-decided in `security.md` and the plan's DD3a
  / DD5, re-verified here rather than re-litigated: relaxing the bootstrap's
  spec-ordinal guard from a 999 value cap to the shared length check (the
  alternative made the gap guarantee and the ceiling unsatisfiable together),
  and converting a crafted `group rename` from a silent namespace redirect into
  a loud one-record refusal. `ALLOC_MAX_ORD_DIGITS` is a plain assignment that
  overwrites any inherited environment value, so it is not injectable.
- Erosion guard, compare-and-swap, write-containment, and `GIT_TERMINAL_PROMPT=0`
  are untouched.

## Findings

### 1. `alloc_next_id_spec`'s docstring signature omits the flag it now accepts

- **Priority:** low
- **Description:** The plan's Interface Contract specifies
  `alloc_next_id_spec <group> [--follow-redirect]`. The shipped signature line
  (`skills/file/scripts/jimalloc.sh:397`) still reads `<group>` alone. The option
  is described in the docstring body and in both usage strings, so it is
  discoverable — but the leading signature line is how every sibling docstring in
  this file states a call shape, and a reader who scans signatures will miss it.
- **Suggestion:** Add `[--follow-redirect]` to the `:397` signature line.
- **Relates to:** Task 7 / plan Interface Contract

### 2. The `allocate spec` acknowledgment path shipped unfixtured

- **Priority:** medium
- **Description:** Task 7 threaded `--follow-redirect` through both `cmd_peek
  spec` and the `allocate spec` path. Only the peek half has a fixture
  (`tests/jimalloc.sh:377`). The allocate half is the one that actually binds an
  allocation through the CAS, and it is the security-motivated consent gate, so
  it is the half more worth pinning. Verified by hand against a real repo with an
  appended `group rename`: the refusal names the redirect, and the acknowledged
  call mints `ui/003` with a fresh `group allocate ui` record — so this is a
  coverage gap, not a defect.
- **Suggestion:** Add a `run_jimalloc_in` fixture over `alloc_new_repo` asserting
  the refusal and then the acknowledged mint, including that the emitted
  `group allocate` record names the current group.
- **Relates to:** AC 7 / Task 7

### 3. The terminal exhaustion refusal has no fixture

- **Priority:** medium
- **Description:** `alloc_next_id_spec` now has two documented failure modes.
  The retryable one is fixtured three ways; the terminal exhaustion branch
  (`:448`) is untested. Reachable in one record — a 15-digit ordinal sits inside
  the fold's legality gate, and the increment then falls outside.
- **Suggestion:** Already filed during the build's candidate batch as
  `20260730-fixture-the-terminal-exhaustion-refusal-in-next-id`. Recorded here
  for completeness; not re-filed.
- **Relates to:** AC 5 / Task 7

### 4. The test suite acquired a non-POSIX `timeout` dependency

- **Priority:** low
- **Description:** `tests/jimalloc.sh:336` and `:474` call `timeout 10` to bound
  the two cycle-safety cases. No other file under `tests/` used `timeout` before
  this build. It is coreutils, not POSIX. The choice is well-motivated — a
  non-terminating alias-map walk hangs with no error message, and the plan's DD4
  made a passing test the only evidence the rule was implemented, so an unbounded
  case would hang the suite instead of failing it. But it is a new external tool
  in a project whose stated posture is bash + POSIX only.
- **Suggestion:** Either accept it explicitly (a line in the test file's header
  noting the dependency and why), or bound the walk in-process instead. Worth a
  deliberate decision rather than leaving it implicit.
- **Relates to:** AC 13 / ARCHITECTURE.md → Scripting Layer

### 5. The ordinal-width predicate is inlined at five sites

- **Priority:** low
- **Description:** `ALLOC_MAX_ORD_DIGITS` is read at `:353`, `:389`, `:448`,
  `:638`, and `:685`. The AC's requirement is met exactly — one shared *value*,
  "not two that happen to agree" — but the *predicate* around it is now written
  out five times. That is a smaller instance of the pattern this spec exists to
  remove, and it is where a future edit could diverge one site (e.g. `>=` versus
  `>`) without any test noticing.
- **Suggestion:** Collapse to an `alloc_valid_ord` one-liner alongside
  `alloc_valid_token` / `alloc_valid_specid`, and have all five call it.
- **Relates to:** AC 5 / Design Decision 3

### 6. The allocate-path refusal emits two stderr lines

- **Priority:** low
- **Description:** `allocate spec <retired-group> <subject>` writes the specific
  reason (`group renamed — 'dashboard' is now 'ui'; …`) followed by the CAS
  layer's generic `allocator failed to compute a record`. The specific line comes
  first, so a human reads the right thing, but a consumer classifying by the
  *last* stderr line gets the generic one — and the Interface Contract asks
  consumers to distinguish terminal from retryable *by message*.
- **Suggestion:** When the spec-ID consumer wiring lands (#112/#113), have it
  match anywhere in stderr rather than on the last line, or suppress the generic
  line when the builder already reported a specific reason.
- **Relates to:** Design Decision 7 / plan Interface Contract

## Deviations & feedback

- **The security gate did its job twice, and the second time caught its own
  suggested fix.** `sec_runs=2` with `spec_runs=3`: the plan-phase review forced
  two spec amendments, and routing its Critical showed that the finding's own
  proposed remedy (counting only corroborated ordinals) did not work — an
  attacker appends a well-formed `allocate` record as easily as a rename. The
  ceiling was replaced by a recoverability requirement instead. Design
  Decision 3a records the three rejected candidates, which is the right home for
  that reasoning; it is why the plan reads as it does.
- **Zero interruptions across all six stages**, and the Red step failed first on
  every one of the four defects with the exact values the Defect Profile
  predicted. The reproduce-then-fix discipline held without a single retry.
- **Verify commands needed auditing for vacuous passing.** A name filter matching
  no case exits 0 with "Ran 0 tests", so every task's Verify asserts
  `Ran [1-9][0-9]*`. One of the plan's own greps still passed before any work
  (its pattern spanned two comment lines) and was rewritten during planning —
  worth carrying forward as a standing check when a plan's gates are
  grep-shaped.
- **One task's boundary was wrong in the plan, not in the build.** Task 5's
  fixtures as first written asserted `next-id` output, which task 7 delivers,
  making task 6's Verify unsatisfiable. Relocating those assertions kept each
  task's gate honest. A plan that splits "add the fold" from "rewire the callers"
  needs its fixture tasks split the same way.
- **Line anchors in this file keep rotting.** Every inherited anchor checked
  during this work had drifted (`:169`→`:177`, `:349-355`→`:371-378`, and again
  during this build as the fold landed). The anchors in this review are dated to
  `576527a` for the same reason.
