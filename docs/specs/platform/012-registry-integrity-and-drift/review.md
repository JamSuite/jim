---
spec: "platform/012"
type: "feature"
base_sha: "129e4bae429ee9d54c65cb99adabcbf102392ca8"
head_sha: "0b9ac2ee2abdc9f6436656ff9885ecb5ac66fbea"
commits: "13"
commits_test: "1"
commits_feat: "8"
commits_fix: "2"
commits_refactor: "0"
files_changed: "7"
insertions: "1653"
deletions: "30"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5908"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "949"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "1982"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "7011"
build_runs: "1"
build_interruptions: "1"
build_duration_seconds: ""
review_runs: "1"
review_interruptions: "0"
review_duration_seconds: "777"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "3"
security_regressions: "2"
invariant_violations: ""
contract_violations: ""
alignment: "major-drift"
date: "2026-08-02"
---

# Review: Registry integrity and drift

## Summary

**Alignment:** major-drift · **Depth:** thorough · **Findings:** 15 · **Plan deviations:** 3 · **Security regressions:** 2

Reviewed `129e4ba..0b9ac2e` (13 commits, 7 files, +1653/−30) against the spec's 17
ACs, the plan's 12 tasks, and the project's conventions, with a ten-investigator
fan-out over the write path, the id boundary, the classifiers, the sweep,
consumer tracing, bootstrap-regression risk, three AC sweeps, and conventions.

The shipped mechanism does what it was scoped to do — the sweep runs clean over
the live registry (64 spec records vs 64 tree dirs, 200 issues, the retired `jim`
group correctly named as uncovered), the suite is 1032/1032, and every task
landed. The verdict is nonetheless **major-drift**, on two defects **confirmed by
reproduction, not by reading**:

1. a truncated registry record now breaks the read path outright, where it was
   previously degraded and skipped, and
2. `catch-up --apply` manufactures exactly the registry contradiction this spec
   exists to detect — reporting success, and leaving its own detector blind to
   the damage.

Both are in code written for this spec. That is the pattern this cluster's notes
predicted for E: what a spec *builds fresh* is where its defects live, not what
it repairs.

One reported critical did **not** survive verification and is recorded below as a
false positive, because a review's wrong findings are as much a part of its
record as its right ones.

## Alignment

### vs. Spec acceptance criteria

- **AC 1** — drift: the sweep is read-only toward the registry and the tree, but
  `cmd_sweep` runs `git fetch <remote> <branch>:refs/heads/<branch>`
  (`jimalloc.sh:2213`), which creates or fast-forwards a local branch ref. The
  plan sanctions this as the peek model (`plan.md:201`) while the AC says "never
  mutates … any local state beyond its own report". A genuine spec/plan tension,
  not a build slip — but the AC as worded is not met, and no fixture exercises a
  reachable remote at all.
- **AC 2** — met. All five drift classes and the informational class are emitted
  *and* rendered; a reserved-slot record is drift and never also informational.
- **AC 3** — drift: all five non-coverage classes are named, but a record the
  classifier *degrades and skips* appears in no class and no denominator
  (Finding 6), so the sweep's central promise — a clean report means "checked and
  sound" — does not hold for an unreadable registry.
- **AC 4** — drift: specs and issues report both denominators; the group kind's
  registry-side count is computed (`jimalloc.sh:1153`) and discarded (`:2245`).
  The "records" figure counts live claims after replay, so a duplicated ordinal
  makes the header disagree with the drift row printed beneath it.
- **AC 5** — met for a direct CI consumer (0 / 3 / 4 distinct, 1 and 2 never
  colliding). Two caveats recorded: rc 4 maps to `violated` under the verify rung
  by deliberate design (DD 2), and Finding 5 is a path where a check that did not
  look exits 0.
- **AC 6** — met. Unreachable coordination point still sweeps last-seen state and
  names both the tip and the staleness.
- **AC 7 / AC 8 / AC 10** — met, verified clause by clause: the append set is
  genuinely recomputed at each attempt's tip (never an echo of the preview), the
  publish preserves prior records byte-for-byte in order, and no identity data is
  invented. The spec-record date is today's by DD 6's explicit decision.
- **AC 9** — drift: partial repair exits non-zero and names mismatches, but
  `CU_BLOCKED` collects `MISMATCH` rows only, so duplicate/reserved-slot drift is
  neither named nor reflected in the exit code (Finding 4).
- **AC 11** — drift: all three named sites refuse, but the vacating clear is
  order-insensitive, so a duplicate-then-rename log resolves silently while the
  sweep flags it (Finding 3).
- **AC 12** — met. Every consumer of the advertised tip is covered by the single
  gate; the empty-tip path cannot bypass it.
- **AC 13** — drift: the config wiring landed and the `registry:<name>` path needs
  no engine change, but the blueprint row itself is not yet written. It is a
  completion-gate obligation (DD 10), still pending at this commit — while README
  and WORKFLOW already cite the invariant as fact.
- **AC 14** — drift: 29 guards were mutation-audited and discriminate, but three
  emit sites are undiscriminated (Finding 9), and the audit note in the test
  header overclaims "every classifier class" — true per class, false per
  kind×class.
- **AC 15** — drift: every stdout token is boundary-validated or sanitized, but
  the derivation's conflict lines, which both verbs route into their report
  channel, echo raw tree tokens (Finding 10).
- **AC 16** — met. One numeric predicate, genuinely shared by the derivation and
  the sweep's counter; no remaining path can mint `<group>/000`.
- **AC 17** — drift: the script's usage documents both verbs, but neither
  README's nor WORKFLOW's *command table* gained a row — prose sections landed
  instead (Finding 11).

### vs. Plan tasks

All 12 tasks are done, in order, each with its Verify run. Three deviations:

- **Task 5 (deviation, deliberate and disclosed):** the plan said a duplicate
  claim "halts the batch". Implemented scoped to the identities a batch actually
  resolves, because the literal reading bricks every realization in a group
  whenever two specs share a title-slug and a day — a state the allocator itself
  mints. The scoping is right; the *blast radius* still grew from per-identity to
  whole-batch versus the prior behavior (Finding 8).
- **Task 7 (deviation):** DD 5 specifies `tr -d '\t\n\r'`; the implementation
  translates to spaces. Behaviorally better, unrecorded.
- **Task 10 (deviation):** the plan's File Manifest called for command-table
  rows; prose sections landed. The task's Verify (`grep -c 'catch-up'`) cannot
  distinguish a row from a paragraph, which is why it passed (Finding 11).

Scope creep: none. Two changes went slightly beyond the literal task text and are
recorded as such — the provisional-issue skip in the shared derivation (needed
for AC 3/AC 6, but it rewrote the bootstrap's refusal contract — Finding 12) and
the boundary cache (DD 4's in-run dedupe, whose cost premise was wrong —
Finding 15).

### vs. ARCHITECTURE.md

- Bash-vs-Prompt, no third-party deps, `set -uo pipefail` + `LC_ALL=C`,
  `BASH_SOURCE`-relative composition, preview-then-apply, tests under `tests/`
  with temp-dir fixtures: all respected.
- Single id boundary, no fourth copy: respected in letter — the cache memoizes
  the existing fork rather than reimplementing the rule. Its *behavior* under an
  empty token is Finding 1.
- `no spec IDs in script comments` (CLAUDE.md): two pre-existing violations at
  `jimalloc.sh:1856` and `:1917`, both in `seed` code this build did not touch.
  Every new function is clean.
- `ordinal-single-source`: the reserved-slot rule is now single-sourced across
  derivation and sweep — an improvement — but `alloc_classify_spec:1142` decides
  the RESERVED row with a literal `000` rather than the shared predicate
  (Finding 14).

## Investigation

### High-stakes regions investigated

#### The catch-up write path (the only new code that writes the shared branch)
- locations examined: `jimalloc.sh:2286-2468`, `:1925-2016` (`alloc_publish`),
  `:1867-1899` (`alloc_seed_commit`), `:1381-1427` (erosion + containment)
- callers/consumers traced: `cmd_catchup` → `alloc_catchup_land` →
  `alloc_publish` → builder → `alloc_catchup_compute`; no other caller in tree
- tests checked: `tests/jimalloc.sh:2310-2484`
- verdict: **divergence** — no record-loss path (all four blob edge cases
  traced), `CATCHUP_BLOCKED` propagation sound across CAS retries, no temp file;
  but Findings 2, 4, 5 live here.

#### The id-validation boundary cache
- locations examined: `jimalloc.sh:120-142`; all 31 call sites; `jimfile.sh:199-218`
- verdict: **divergence** — the memoized verdict is pure and the sentinel cannot
  be legitimately empty, but an empty token is an invalid array subscript
  (Finding 1). Reproduced against the pre-build allocator.

#### The classification cores
- locations examined: `jimalloc.sh:1034-1231`; compared against
  `alloc_resolve_spec:242-314` and `alloc_resolve_issue:316-383`
- verdict: **divergence** — three readers apply three different field-validation
  sets, so "clean" and "resolvable" diverge (Findings 2, 3, 6, 7). Associative
  array iteration order was checked explicitly and is *not* load-bearing.

#### The sweep verb
- locations examined: `jimalloc.sh:2055-2284`
- verdict: **partial** — cap arithmetic correct at every boundary; no emitted
  field can carry a tab or newline; Findings 5, 6, 13 live here.

#### Consumers of the changed read paths (omission class)
- callers/consumers traced: exhaustive grep of `skills/`, `agents/`, `scripts/`,
  every `SKILL.md`; `skills/issue/scripts/reconcile.sh`,
  `skills/spec/scripts/reconcile.sh`, `skills/issue/scripts/new.sh`
- verdict: **satisfied, with one exposure** — **no production consumer calls
  `resolve` at all**, and both reconcile consumers gate on the exit status before
  any mutation, so a realize halt cannot strand a partial realization. Their
  correctness rests on `pipefail` with no test asserting it. Finding 7 (grant).

#### Shared-derivation regression (the bootstrap is a second consumer)
- verdict: **partial** — the reserved-slot widening loses no legal identity
  (a width argument, verified); the marker default is byte-identical and
  unreachable from every CLI surface; the provisional-issue skip rewrote the
  bootstrap's refusal contract (Finding 12).

#### ACs 1–6, 7–11, 12–17
- Three dedicated passes; every verdict above traces to one of them.

### Coverage

- Depth: thorough; `review_model: inherit`; 10 investigators, the full
  high-stakes set — no cap reached, no region left un-investigated.
- Two reported criticals were **re-verified by reproduction** rather than
  accepted: one confirmed (Finding 1), one refuted (False positives, below).
- Not covered: no investigator exercised a *reachable* coordination remote (no
  fixture in the repo constructs one), so the `refreshed` path is reviewed by
  inspection only.

## Living intent

Not run at this commit — the sensor is invoked after the verdict is recorded, and
the platform group's `000-blueprint` does not yet carry this spec's invariant
(AC 13's completion-gate obligation). The sensor runs with the blueprint update
that follows this review; its outcome is recorded there, not here.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 13 (1/8/2/0) |
| Files changed · insertions · deletions | 7 · +1653 · −30 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 5908s·949s·1982s·7011s·—·777s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·1·0 |
| Artifacts present | spec,research,security,plan,ledger |

## Security regressions

1. **Read-path denial of service via a truncated record** (Finding 1) — anyone
   who can push the coordination branch can break `resolve` for every clone with
   one short line. The registry is push-writable by design, so this is inside the
   documented threat model.
2. **The repair verb can be induced to break resolution** (Finding 2) — a crafted
   degraded record turns `catch-up --apply` into the instrument that bricks an
   identity, while both the apply and the following sweep report success.

Not regressions: the new `verify_command_id-sweep` key activates a read-only
command through the sanctioned operator-registry channel, which surfaces its own
permission prompt; the config value is developer-controlled.

## Findings

### 1. A truncated registry record breaks the read path

- **Priority:** critical
- **Description:** `alloc_valid_token`'s cache indexes an associative array with
  the raw token (`jimalloc.sh:134`, `:138`). An empty token — produced by any
  record short a field, e.g. `group rename core` — is an invalid subscript.
  Reproduced against the pre-build allocator: `resolve spec core/001` over a log
  containing that line returned `core/001` rc 0 **before**, and now emits two
  `bad array subscript` errors and returns **rc 1 with no answer**. This breaks
  the file's stated contract that a malformed record is "degraded and skipped",
  and it is reachable by anyone who can push the branch.
- **Suggestion:** guard the empty token before the cache (the boundary already
  rejects it), and add a fixture asserting a truncated record leaves resolution
  working and stderr clean.
- **Relates to:** AC 12's boundary discipline, DD 4

### 2. `catch-up --apply` manufactures the contradiction the sweep exists to find

- **Priority:** critical
- **Description:** the classifier drops a record whose *sibling* field fails the
  boundary (`:1087` slug, `:1173` durable id); the resolvers count claims on the
  id field alone. So a degraded record leaves its identity reported `MISSING`,
  catch-up appends a second record for it, and the resolver then refuses.
  Reproduced end to end: sweep says `missing-record issue 5` → `catch-up --apply`
  exits **0** → `resolve issue 5` **refuses** → the next sweep reports **clean**.
  An append-only repair path created a hard read failure, reported success, and
  its own detector cannot see it.
- **Suggestion:** make the three readers agree on what establishes a claim. The
  minimal form: count a claim on the id field alone (as the resolvers do) and
  report the sibling-field failure as its own drift class, so a degraded record
  is never classified `MISSING`.
- **Relates to:** AC 2, AC 7, AC 11

### 3. The duplicate refusal is erased by a later rename

- **Priority:** high
- **Description:** the vacating clear (`:289`, `:293`, `:366`) fires on any rename
  naming the id as source, including one that arrives *after* both duplicate
  allocate records. `allocate core/007` / `allocate core/007` / `rename core/007
  core/009` resolves silently to `core/009`, while `alloc_classify_spec` emits
  `DUP-ORD` for the same log — detect and resolve disagree on the exact condition
  AC 11 exists for.
- **Suggestion:** clear only when no contradiction has been recorded — a rename
  moves one holder and cannot disambiguate two. Fixture the duplicate-then-rename
  order specifically; the shipped fixture uses the safe order.
- **Relates to:** AC 11

### 4. Catch-up is silent on the drift it cannot repair

- **Priority:** high
- **Description:** `CU_BLOCKED` greps `MISMATCH` only (`:2326`, `:2332`), so a
  registry holding a duplicate ordinal, a duplicate durable id, or a reserved-slot
  record yields "nothing to append", **rc 0**, and no mention — while the sweep
  exits 3 naming all three. An operator running catch-up to clear a sweep failure
  reads exit 0 as done.
- **Suggestion:** treat every non-appendable drift class as unrepairable for the
  exit code and the report, not just the mismatch class.
- **Relates to:** AC 9

### 5. `catch-up --apply` doubles as an unmarked bootstrap

- **Priority:** high
- **Description:** AC 7 scopes catch-up to "a **non-empty** log"; nothing enforces
  it. With no coordination branch, the publish builds a root commit and seeds the
  whole collection stamped `jim-catchup` — bypassing `seed`'s one-time-migration
  preview, mis-marking a bootstrap as a repair, and making a later `seed --apply`
  refuse as "already seeded". `cmd_sweep` refuses that same repo with rc 4.
- **Suggestion:** refuse an empty log in `cmd_catchup`, pointing at `seed`.
- **Relates to:** AC 7, AC 8

### 6. A degraded record is invisible in every number the sweep prints

- **Priority:** high
- **Description:** denominators count live claims after replay (`:1152`, `:1229`),
  and the non-coverage block lists only reserved slots, pending provisionals,
  uncovered groups and rename sources. A record skipped for a malformed field
  appears in none of them. A registry half full of unreadable records reports
  identically to a clean one — inverting this spec's own doctrine that a clean
  report must mean "checked and sound".
- **Suggestion:** count skipped records and name them as a non-coverage class.
- **Relates to:** AC 3, AC 4

### 7. Issue ordinals normalize on one side of the comparison only

- **Priority:** high
- **Description:** the classifier reads ordinals numerically (`:1174`, `:1206`);
  `alloc_resolve_issue` compares them as strings (`:334`, `:359`). A registry
  holding `issue allocate 007` with a tree file carrying `num: 7` reads **clean**
  to the sweep, while `resolve issue 7` reports *not allocated* and the fold
  counts 7 as consumed. The seed's own comment (`:1014`) names this split as the
  reason seeding normalizes; the classifier inherited the numeric reading and the
  resolver kept the string one. Live today — no rename record needed.
- **Suggestion:** canonicalize the issue ordinal in the resolver, mirroring
  `alloc_canon_specid` on the spec side.
- **Relates to:** AC 2, AC 11

### 8. The realize halt's blast radius grew from one identity to the batch

- **Priority:** high
- **Description:** the spec-side halt keys on (group, slug, date). Two claimants
  are reachable through ordinary use — the derivation stamps *today* on every
  record, so seeding a group holding `003-auth-fix` and `012-auth-fix` mints two
  records on one key. Previously `spec/scripts/reconcile.sh` halted that identity
  and left the rest of the batch working; now the whole batch is refused, and
  neither the sweep nor catch-up can name or clear the condition (the classifier
  keys duplicates on the canonical id, not the triple).
- **Suggestion:** halt the offending identity, not the batch, matching the
  consumer's documented "other identities are unaffected"; and give the sweep a
  class for a duplicated realize key.
- **Relates to:** AC 11, plan task 5

### 9. Three detections have no discriminating fixture, and the audit note overclaims

- **Priority:** medium
- **Description:** the issue-side `MISMATCH` durable-id-at-another-ordinal branch
  (`:1214`), the issue-side `RENAME-SRC` (`:1225`), and the issue-side
  `INFO-NO-TREE` (`:1221`) can each be deleted with the suite still green. The
  first matters beyond coverage: deleting it makes that input fall through to
  `MISSING`, which is Finding 2's append path. The sweep-level
  `rename-source-ids` assertion (`tests/jimalloc.sh:2203`) asserts zero and
  cannot fail. The mutation-audit note claims "every classifier class" — accurate
  per class, not per kind×class.
- **Suggestion:** add the three fixtures; correct the audit note's scope claim to
  what it measured.
- **Relates to:** AC 14

### 10. The derivation's conflict lines echo raw tree tokens

- **Priority:** medium
- **Description:** both new verbs route the derivation's stderr into their report
  channel (`cmd_sweep:2224-2229` says so explicitly), and those lines interpolate
  raw `basename` output and raw frontmatter scalars (`:924`, `:937`, `:945`,
  `:989`, `:998`) — by construction values that failed the id boundary. A path or
  frontmatter value with a tab, CR, or ANSI escape reaches the operator verbatim.
  Inherited from the bootstrap, but AC 15 binds "every token either verb echoes".
- **Suggestion:** sanitize the conflict lines at emission.
- **Relates to:** AC 15

### 11. Neither command table gained a row, and both docs cite an invariant that does not exist

- **Priority:** medium
- **Description:** AC 17 names README's and WORKFLOW's command tables; prose
  sections landed instead, and the task's `grep -c` Verify cannot tell them apart.
  Separately, both docs and `jimconf.toml` reference the
  `registry-tree-consistency` blueprint invariant, which the platform blueprint
  does not yet carry (AC 13's completion-gate obligation).
- **Suggestion:** add the table rows; land the blueprint row at the gate so the
  references resolve.
- **Relates to:** AC 13, AC 17

### 12. The bootstrap's refusal contract changed without an operator signal

- **Priority:** medium
- **Description:** `alloc_seed_derive_issues` now skips a pending provisional
  issue file where it previously refused the entire seed naming the offender.
  The new ordering is genuinely safer (seed-then-reconcile cannot collide;
  reconcile-then-seed could strand every real record), but `seed`'s preview and
  report never mention what was passed over, so an operator approving
  `seed --apply` gets no signal that an identity was omitted. The issue side of
  the skip also has no derivation-level fixture, where the spec side has three.
- **Suggestion:** name skipped identities in the seed preview and report; add the
  missing derivation-level fixtures.
- **Relates to:** AC 3, plan task 7

### 13. Two accuracy defects in the uncovered-group report

- **Priority:** low
- **Description:** the group name is interpolated into a regex
  (`grep -q "^spec allocate $name/"`, `:2170`), so a group named `a.b` matches a
  record for `axb` and is silently read as covered; and the printed name list is
  capped at 256 bytes by the sanitizer with no "… and N more", the one place a
  drop is silent while the count stays right.
- **Suggestion:** fixed-string match the group; cap the list the way
  `alloc_sweep_list` caps rows.
- **Relates to:** AC 3

### 14. Two comments describe behavior the code does not have

- **Priority:** low
- **Description:** `alloc_catchup_compute:2334` claims the batch keeps "the
  derivation's own ordering … reads exactly as a seed", but `:2355` hoists all
  group records ahead of all spec records — true for one group, false for two.
  And `alloc_is_reserved_ord`'s docstring claims one predicate so the derivation
  and the report "can never disagree", while `alloc_classify_spec:1142` decides
  the RESERVED row with a literal `000`.
- **Suggestion:** correct both to current behavior, or make the second true by
  calling the predicate.
- **Relates to:** ARCHITECTURE.md, `ordinal-single-source`

### 15. DD 4's cost premise was wrong, measured

- **Priority:** low
- **Description:** the plan predicted the sweep's cost would be the id boundary
  and named #142 as the escalation path. Profiled on the live collection: the
  classifiers cost 167 ms of ~14 s; `alloc_seed_derive_issues` alone costs 6.9 s,
  in per-file `sed` forks for frontmatter. The cache added under DD 4 helped, but
  the dominant cost is elsewhere and is not what #142 describes.
- **Suggestion:** file the measurement so #142 is neither closed against it nor
  assumed to fix it.
- **Relates to:** DD 4

## False positives — reported and refuted

Recorded because a review's wrong findings belong in its record as much as its
right ones, and because the refutation is only visible if it is written down.

- **"The token cache lets `@` and `*` bypass the id boundary."** Reported
  independently by two investigators, both reasoning that `${ALLOC_TOKEN_OK[$tok]}`
  with `tok="@"` expands as the all-elements subscript and returns `y` whenever a
  single valid token is cached — which would have been a critical bypass of the
  `ref-validation` invariant, reachable from the AC 12 tip guard. **Executed: both
  `@` and `*` are correctly rejected.** The subscript is the *result* of a
  parameter expansion, not literal `@` text, so the all-elements rule does not
  apply. One investigator explicitly flagged it as needing runtime confirmation
  and supplied the experiment; the other asserted it as a confirmed violation.
  This is the second consecutive build in which a reasoned-from-source finding
  was killed by execution — the same shape as the two refuted findings in the
  previous remediation pass.

## Deviations & feedback

- **The fan-out earned its cost, and the verification after it earned more.** Ten
  investigators produced 15 findings the author's own read produced none of. But
  two of the three reported criticals needed execution to settle — one confirmed,
  one refuted — and neither could have been settled by reading. The practice to
  carry forward is not "run the fan-out" but "run the fan-out, then reproduce its
  criticals before believing them".
- **Every confirmed defect is in code written fresh for an AC.** The riders that
  *repaired* existing behavior (tip validation, reserved-slot normalization,
  marker parametrization) are clean. The defects cluster in the new
  classifier/sweep/catch-up surface and in the one new cache — the fourth
  consecutive confirmation of this cluster's standing prediction.
- **Two defects share one root cause worth naming:** three readers of the same log
  (classifier, resolvers, realize) apply three different field-validation sets.
  Findings 2, 6 and 7 are all instances. A single "what establishes a claim"
  predicate would close all three at once, and is the shape the next pass should
  take rather than three local patches.
- **A green suite said nothing about any of this**, exactly as this cluster's
  fourth practice predicts — 1032 passing tests over two critical defects, one of
  which the suite's own fixture (`case_jimalloc_classify_skips_malformed_records`)
  demonstrates without asserting.
- **The build's own mutation audit was necessary and not sufficient:** 29 guards
  discriminate, and three emit sites still have no discriminating fixture. The
  audit measured what it mutated, and its note claimed a scope slightly wider
  than what it measured — the exact failure mode this cluster's seventh practice
  describes, reproduced by the practice's own author.
