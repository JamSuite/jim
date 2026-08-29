---
spec: "issue/012"
type: "feature"
base_sha: "8afc80ac3c380f03918e89dbfb21c3525ccd80dc"
head_sha: "9aec5ed79039cb20101db8e503a5b916c9ae8513"
commits: "18"
commits_test: "1"
commits_feat: "11"
commits_fix: "0"
commits_refactor: "1"
files_changed: "15"
insertions: "2144"
deletions: "128"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "79051"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1198"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "4668"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "30267"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "10564"
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "634"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "2"
security_regressions: "0"
invariant_violations: "1"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-08-23"
---

# Review: Schema and state model

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 13 · **Plan deviations:** 2 · **Security regressions:** 0

The build shipped all 18 tasks across `8afc80a → 9aec5ed` and the implementation
is faithful: every one of the spec's 31 acceptance criteria is satisfied at the
code level, conventions are 9/9 clean, and the new trust boundary holds under
adversarial reading. The drift is not in the code — it is in the surfaces that
expose and describe it. The skill's `allowed-tools` grant was never extended to
the script the build created, so the five transition verbs are documented but
not authorized; three further doc surfaces now contradict shipped behavior; and
one new writer replicated a pre-existing index-regeneration omission rather than
the correct pattern beside it.

## Alignment

### vs. Spec acceptance criteria

- **Schema (4 ACs)** — met. Fields exist, round-trip through all three readers,
  holder is independent of lifecycle state, unheld is representable.
- **Lifecycle (7 ACs)** — met. The `outcome non-empty iff EVER closed` invariant
  holds by construction; `reopened` is derived, never stored; the superseded
  outcome is enforced at write time.
- **Transitions (8 ACs)** — 7 met; **AC "a developer can claim, release, start,
  close, and reopen an issue through a single command each" is not reachable.**
  `transition.sh` is complete and correct, and `SKILL.md:33-44` documents the
  dispatch, but `SKILL.md:6`'s `allowed-tools` grant does not include the script
  and `SKILL.md:5`'s `argument-hint` does not advertise the verbs. The command
  exists; the surface that is supposed to offer it cannot run it.
- **Filer identity (4 ACs)** — met. One definition, three write paths, all
  routed through it. The positive charset fails closed against a Unicode line
  separator, which is the case that distinguishes it from a blocklist.
- **Existing collection (5 ACs)** — met as code capability; satisfied-once-run
  by design (applying the conversion is an operator action, per plan Out of
  Scope). Under a branch placement the conversion refuses rather than running —
  see finding 9.
- **Integrity (4 ACs)** — met. All three new warnings fire and route their
  interpolated values through `row_safe`.

### vs. Plan tasks

- Tasks 1–15 including 10a/10b/10c — all done, in dependency order.
- **Deviation:** Design Decision 1 was rewritten mid-build (the `previewlib.sh`
  extraction withdrawn in favour of `migrate.sh schema`), with task 8 split into
  a read-only half and task 11 as its write half. Recorded in `plan.md` and
  developer-approved; noted here as a process fact, not a defect.
- **Deviation:** the build added two byte-identical `frontmatter`/`fm_field`
  helper pairs that no task called for — see finding 5.
- No scope creep otherwise. Every Out of Scope item was honored, including not
  applying the conversion and not adding filtering on the new fields.

### vs. ARCHITECTURE.md

- Bash + POSIX only, `set -uo pipefail` never `set -e`, `#!/usr/bin/env bash`,
  trailing newlines, `BASH_SOURCE`-relative composition, no `source`/`eval` of
  user data, no spec IDs in the new scripts' comments, 755 modes — all
  respected across both new files and all five modified ones.
- **Drift:** `ARCHITECTURE.md:400` still opens "Seven deterministic scripts own
  the issue-tracking surface" and enumerates seven. There are now nine;
  `identity.sh` and `transition.sh` appear only in the file-tree lines and the
  security paragraph, not in the Scripting Layer narrative that describes every
  other script in the group.

## Investigation

### High-stakes regions investigated

#### `identity.sh` — the new trust boundary
- locations examined: `skills/issue/scripts/identity.sh:39-118`
- callers/consumers traced: `new.sh:204`, `transition.sh:228`, `migrate.sh:415`
- tests checked: `tests/issues.sh:5053-5155`, `:4430-4445`, `:5023-5050`
- verdict: satisfied — no bypass constructible. The trailing `-` in the bracket
  expression is positionally literal, not a range. Values that pass the class
  but are not address-shaped stay contained: the only sink is a double-quoted
  scalar, and quote/backslash/newline are all outside the accepted set.

#### `transition.sh` — the new mutation path
- locations examined: `skills/issue/scripts/transition.sh:1-359`
- callers/consumers traced: `place.sh:103-104` (`PLACE_VERBS`), no other caller
- tests checked: `tests/issues.sh:4077-4445`
- verdict: satisfied on atomicity, the id gate, fence-scoped ordinal
  resolution, ambiguous-prefix refusal, and pre-door outcome validation;
  divergence on flag applicability (finding 8) and handle cleanup (finding 12).

#### `migrate.sh schema` — derived writes behind a shared guard
- locations examined: `skills/issue/scripts/migrate.sh:190-199, 363-423, 452-522, 539-552, 684-709`
- callers/consumers traced: `route_placement`, `place.sh` materialization path
- tests checked: `tests/issues.sh:4447-4760` (13 cases)
- verdict: satisfied on `%aE` mapping-awareness, whole-run refusal ordering,
  atomic per-file writes, drift-guard freshness, and `prefix` non-regression
  (`gate_apply` is a verbatim extraction — same message, same rc 3); divergence
  on placement availability (finding 9) and index-regen status (finding 4).

#### `index.sh` — the omission class
- locations examined: `skills/issue/scripts/index.sh:66-70, 123-133, 152-170, 300-302, 380-500, 634-650`
- callers/consumers traced: **repo-wide grep for `parse_scalar_fields` returns
  exactly two hits** — the definition and the single call site, both converted
  to keyed reads. No stale positional reader exists anywhere.
- tests checked: `tests/issues.sh:4839-4988`
- verdict: satisfied. `part-of` is correctly absent from `RELATION_INVERSE`,
  which is what suppresses a spurious reciprocity warning.

#### `new.sh` / `place.sh` / `render.sh`
- locations examined: `new.sh:196-240, 289-343`; `place.sh:64-66, 103-104, 212-221, 2022-2037`; `render.sh:62-66, 141-143, 198-217, 384-541, 571-606, 670-712`
- tests checked: `tests/issues.sh:4786-4837, 4990-5035`; `tests/place.sh:195-217`
- verdict: satisfied — identity resolves before the allocator (so no ordinal is
  spent on a refused filing), and `STATUS_TOKENS` is genuinely the single source
  for filter, hide rule and group order. Divergence on two stale doc surfaces
  (findings 3, 7).

#### Test quality (+1112 lines)
- locations examined: `tests/issues.sh:2704-2744, 4074-4445, 4447-4760, 5053-5155`
- verdict: satisfied — non-vacuous. Every new case pairs an exit assertion with
  a content assertion; the claim refusal asserts the holder is named, `--force`
  is proven by content change, and the branch-placement case configures a real
  non-default destination and asserts the file landed there with the right
  commit verb. Coverage boundary: that placement case exercises `claim` only.

#### Spec AC clusters (6 investigations) and conventions/scope (1)
- verdict: recorded per-cluster in the Alignment section above.

### Coverage

- Depth: thorough; review_model: sonnet (configured `inherit`; overridden for
  cost given the fan-out width).
- Full high-stakes set investigated. Fan-out cap is 10; 13 investigators were
  dispatched under an explicit developer authorization to exceed it, so no
  region or AC cluster went uninvestigated.
- investigators: 13 dispatched, 13 returned.

## Living intent

**Sensed:** 9 invariants · **holds:** 8 · **violations:** 1 (in-change 1 · pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 0

### Violations

- `staleness-gated-reads` — medium · violated · in-change ·
  `skills/issue/scripts/migrate.sh:519`. The invariant requires that "a write
  refuses instead, so a stale index never reaches the destination". The new
  `apply_schema_plan` calls `index.sh` and discards its exit status, then prints
  its success line — so `migrate.sh schema --apply` reports `Converted N
  issue(s)` at rc 0 over an index that failed to regenerate. Its sibling new
  writer `transition.sh:280` checks the status and aborts the handle; pre-existing
  `reconcile.sh:246` checks it too, with a comment stating the reason. The same
  omission exists in pre-existing `apply_plan` at `migrate.sh:331`, which is what
  the new code was patterned on.

### Coverage

- appetite in force: low (judge everything); no per-group or per-run override.
- Whole-group floor ran; territory is declared (`skills/issue`,
  `agents/issue-analyst.md`, `tests/issues.sh`, `tests/place.sh`), so the floor
  was scoped rather than `UNSCOPED`.
- judges: change-selected — all 9 invariants selected (the build touched 7 of
  the group's scripts plus its SKILL.md, template and both test files), all
  within the cap of 10. No remainder.
- skipped by scope: 0 · skipped by appetite: 0.
- registry: 0 configured — the blueprint records no `registry:` invariants, so
  the rung had nothing to run. Territory conformance: 0 strays; 871
  outside-territory files bucketed as scaffolding (`docs/` 764 · `skills/` 66 ·
  `tests/` 14 · `agents/` 11 · root config and top-level docs 16).

### Contracts

**Edges checked:** 7 · **holds:** 7 · **violations:** 0 (provider-side 0 · consumer-side 0)

- None — every checked edge holds. The graph names `issue` as provider on 7
  edges and the build touched provides-side code (`new.sh`, `place.sh`,
  SKILL.md § 7a), so the phase fired. `platform → issue "validator-lockstep"`
  was confirmed mechanically: the three `is_valid_id` copies are byte-identical.
  The `placement-door` and `placement-read` edges see only an additive verb-enum
  widening, which is backward compatible. The two `emitter` edges keep their
  face — `new.sh` is still the single emitter — but note that its new
  precondition (refusing when no identity is configured) is inherited by every
  consumer's candidate batch. The spec anticipated that blast radius and
  accepted it deliberately; it is recorded here because it is a runtime
  behavior change consumers did not have to opt into.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 18 (1/11/0/1) |
| Files changed · insertions · deletions | 15 · +2144 · -128 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 79051s·1198s·4668s·30267s·10564s·634s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

- None identified. No secrets were committed. The build *added* a trust
  boundary rather than weakening one: identity values from both the environment
  and version-control history clear a single positive-charset validator before
  reaching a YAML scalar, and no untrusted value reaches a shell argument, an
  `awk -v` escape-expansion, or a commit message. All three new integrity
  warnings route their interpolated values through `row_safe`.

## Findings

### 1. The five transition verbs are documented but not authorized

- **Priority:** critical
- **Description:** `SKILL.md:33-44` instructs the agent to run
  `transition.sh <verb> <id>`, but `SKILL.md:6`'s `allowed-tools` grant lists
  ten Bash patterns and none of them match `transition.sh`. Every other script
  the skill invokes is enumerated explicitly and no wildcard covers
  `skills/issue/scripts/*`. Following the skill's own instructions therefore
  means invoking a tool outside its declared grant. `migrate.sh` — newly
  documented at `SKILL.md:83-84` — is absent for the same reason. Nothing caught
  this: `tests/docsurfaces.sh` skips the `issue` skill in its grant sweeps.
- **Suggestion:** Add `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/transition.sh *)`
  to the grant, decide whether `migrate.sh` is agent-invoked or hand-run, and
  extend the docsurfaces sweep so the `issue` skill is no longer exempt.
- **Relates to:** AC "A developer can claim, release, start, close, and reopen an
  issue through a single command each"; Task 13

### 2. `argument-hint` does not advertise the transition verbs

- **Priority:** medium
- **Description:** `SKILL.md:5` still reads
  `[add <subject> | list [filter] | stats | show <id> | insights | reconcile]`.
  The five verbs the build's headline feature adds are invisible to anyone
  reading the skill's own signature.
- **Suggestion:** Extend the hint with the lifecycle verbs.
- **Relates to:** Task 13

### 3. `render.sh help` tells developers to do exactly what the build replaced

- **Priority:** high
- **Description:** `render.sh:198-217` (`cmd_help`) still says "Close one by
  editing its `status:` field directly." That advice now produces precisely the
  defect this build added an integrity warning for: a hand-edit sets
  `status: closed` without an outcome, and the index reports it. The help also
  lists only `add / list / stats / show / insights`, omitting the five verbs.
- **Suggestion:** Replace the hand-edit sentence with the `close` verb and list
  the lifecycle verbs in the help output.
- **Relates to:** AC "Every transition updates the issue's last-modified stamp
  and refreshes the collection index"; Task 6

### 4. `migrate.sh schema --apply` reports success over a failed index regen

- **Priority:** high
- **Description:** `apply_schema_plan` (`migrate.sh:519`) invokes `index.sh` and
  discards its exit status, then prints `Converted N issue(s)`. A collection can
  therefore be converted, the index left describing the pre-conversion state,
  and the command exit 0. This is the `staleness-gated-reads` invariant
  violation recorded above. The same omission exists at `migrate.sh:331` in the
  pre-existing `apply_plan`; `transition.sh:280` and `reconcile.sh:246` both do
  it correctly.
- **Suggestion:** Adopt `reconcile.sh:244-249`'s pattern in both `migrate.sh`
  writers — surface the failure on stderr and carry a non-zero status.
- **Relates to:** `issue` blueprint § Invariants `staleness-gated-reads`

### 5. Two new byte-identical frontmatter parsers

- **Priority:** medium
- **Description:** `migrate.sh:366-374` and `transition.sh:79-87` each define a
  `frontmatter()`/`fm_field()` pair, and they are byte-identical to one another.
  The group already tracks "the two frontmatter parsers" as a follow-on; that
  issue now understates the duplication. `migrate.sh` additionally carries its
  own pre-existing, differently-scoped `field_value()` at `:57-61` (whole-file,
  not fence-scoped), so one file now holds two field readers with different
  matching semantics. Design Decision 1 reasoned carefully about not forking
  safety logic and then did not apply the same reasoning to field reading.
- **Suggestion:** Strengthen the existing parser-unification issue rather than
  filing a duplicate; note that the count is now higher and that `field_value`
  and `fm_field` coexist in `migrate.sh` with different scoping.
- **Relates to:** Plan Out of Scope, "Unifying the two frontmatter parsers"

### 6. `ARCHITECTURE.md`'s Scripting Layer does not describe the two new scripts

- **Priority:** medium
- **Description:** `ARCHITECTURE.md:400` still says "Seven deterministic scripts
  own the issue-tracking surface" and enumerates seven. There are nine.
  `identity.sh`'s resolve/validate contract and `transition.sh`'s five-verb
  lifecycle get none of the narrative detail every other script in that
  paragraph receives. The build's completion gate refreshed the file tree and
  the security section but not this narrative.
- **Suggestion:** Refresh through `/jim:arch` — the count, the enumeration, and
  a description of each new script at the same level of detail.
- **Relates to:** Plan Out of Scope, "`ARCHITECTURE.md` refresh"

### 7. `place.sh`'s header verb enum is stale

- **Priority:** low
- **Description:** `place.sh:64-66` documents the enum as
  `file | edit | close | rename | realize | reindex | backfill | migrate` —
  missing the four verbs the build added. The runtime `usage()` at `:2033-2034`
  and `PLACE_VERBS` at `:103-104` were both updated correctly, so this is
  documentation only.
- **Suggestion:** Add the four verbs to the header comment.
- **Relates to:** Task 7

### 8. `--as` and `--force` are accepted and ignored where they do not apply

- **Priority:** medium
- **Description:** `--as <outcome>` is consumed only by `close`; on `claim`,
  `release`, `start` and `reopen` a well-formed outcome is validated, accepted,
  ignored, and the command exits 0. `--force` is consumed only by
  `claim`/`release`/`start`; on `close` and `reopen` it is inert. Six
  verb+flag combinations report success for a request half-performed. Already
  filed as an issue during the build; the `--force` half is named there as an
  open decision.
- **Suggestion:** Refuse an inapplicable flag at the usage exit code, beside the
  existing outcome-enum validation, before anything is written.
- **Relates to:** AC "Closing accepts an outcome"

### 9. The conversion cannot reach a centralized collection's history

- **Priority:** high
- **Description:** Under a branch placement the collection is materialized into
  a directory with no `.git`, so `cmd_schema`'s work-tree gate
  (`migrate.sh:539-542`) refuses every routed invocation — the conversion is
  unavailable exactly where a shared collection makes recorded identity worth
  having. `SKILL.md:17`'s claim that routing leaves the calls "unchanged either
  way" does not hold for this subcommand. The sharper risk is on the other arm:
  when the destination branch *is* checked out, derivation succeeds against
  whatever history exists, and a collection centralized by a bulk import would
  attribute every issue to whoever performed that import — present, plausible
  and wrong. Nothing detects a flattened history; the refuse-loudly criterion
  catches a missing answer, never a confidently wrong one. Already filed.
- **Suggestion:** Decide what correct attribution means under a flattened
  history before changing the git invocation; extend refuse-loudly to cover a
  wrong answer. Correct `SKILL.md:17`'s parity claim in the meantime.
- **Relates to:** AC "The filer of an existing issue is recovered from the
  collection's own history"; spec Handoff Insight 3

### 10. The spec's Integrity mockup row has no index implementation

- **Priority:** low
- **Description:** The spec's UI mockup shows
  `#88 outcome \`duplicate\` names no superseding issue` under Integrity.
  `index.sh` implements no such check; the constraint is enforced only at write
  time in `transition.sh:339-345`. That is a deliberate plan decision (task 10b,
  chosen so the record cannot contradict the spec and be reported afterwards),
  but it means a hand-edited file carrying that contradiction passes the index
  silently — the index cannot backstop this one invariant.
- **Suggestion:** Either add the index check as a backstop or amend the mockup so
  the spec does not promise a report that does not exist.
- **Relates to:** AC "An issue whose outcome is superseded identifies the issue
  that supersedes it"

### 11. The conversion preview cannot predict a structural apply failure

- **Priority:** low
- **Description:** `apply_schema_plan`'s awk anchors the four new scalars on
  `^labels:` and `part-of` on `^  duplicates:`, exiting non-zero if either
  anchor is absent (`migrate.sh:509`). The failure is named and nothing is
  written for that file, so it is safe — but `build_schema_plan` checks only
  `type`/`status`/filer, so a file missing an anchor previews as an ordinary
  `convert` row and fails partway through the apply. Not a live risk against the
  current collection, where all 354 files carry both anchors.
- **Suggestion:** Have the preview classify a missing anchor the way it
  classifies an underivable filer, so the whole-run refusal covers it too.
- **Relates to:** AC "The conversion previews what it will change before
  changing anything"

### 12. A placement conflict orphans the transition's handle

- **Priority:** low
- **Description:** On rc 3 `place.sh` deliberately preserves the handle and its
  staged edits so the caller can reapply, but `transition.sh:287` discards the
  token (`|| return $?`) and does not call `abort`. The caller has no way to
  resume the preserved handle, and a retry opens a fresh one, leaving the old
  directory under the git dir with no reclamation path.
- **Suggestion:** Either report the token so a retry can resume it, or abort the
  handle on the conflict path since the field values are recomputed anyway.
- **Relates to:** AC "Every transition works identically whether the collection
  lives on the working branch or on a designated shared branch"

### 13. A failed timestamp helper silently drops the `updated` stamp

- **Priority:** low
- **Description:** `transition.sh:270` reads `now="$(bash "$JIMFILE" now)" || now=""`
  and line 271 appends the stamp only when `now` is non-empty. If the helper
  ever fails, the transition proceeds and publishes without refreshing
  `updated` — a silent violation of "every transition updates the issue's
  last-modified stamp". Low likelihood, since the helper is a plain `date -u`.
- **Suggestion:** Fail the transition rather than dropping the field.
- **Relates to:** AC "Every transition updates the issue's last-modified stamp
  and refreshes the collection index"

## Deviations & feedback

- **The gap between a script and its surface is not covered by any gate.** The
  build's own verify command for every task was the test suite, and the suite
  passed 1454/1454 — but no test asks whether the skill that exposes a new
  script is permitted to run it. `tests/docsurfaces.sh` sweeps every *other*
  skill's grants and explicitly skips `issue`. A feature can be complete,
  tested, documented and unreachable, and this build produced exactly that.
- **A routed spec insight died between phases.** Handoff Insight 3 flagged the
  centralized-collection complication and routed it to research with
  "Researcher to investigate". Research recorded only that placement is inert
  here; no design decision, task or test took it up; the build met it as an
  implementation detail. The plan review did not notice a handoff insight with
  no corresponding decision. That is a checkable property — every routed insight
  should map to a decision, a task, or an explicit deferral.
- **Documentation drift clustered where the build was most correct.** Four of
  the thirteen findings are stale prose in files the build otherwise changed
  carefully. The pattern is that the code path was updated and the *describing*
  line beside it was not — help text, header comment, script count, argument
  hint. All four are one-line fixes; none was caught by a green suite.
- **The correct pattern was already in the group and was not reused.** Finding 4
  duplicated a pre-existing omission when a correct sibling implementation sat
  two files away, and finding 5 duplicated a helper the group already tracks as
  a unification follow-on. Both suggest reaching for the nearest similar code
  rather than the best example of it.
