---
spec: "issue/011"
type: "feature"
base_sha: "f024b9e378c27935874da4a6533bcfbc6bc648cc"
head_sha: "3c1a78f57834e6fca19a259dddd71f509e166ee5"
commits: "15"
commits_test: "0"
commits_feat: "11"
commits_fix: "0"
commits_refactor: "0"
files_changed: "19"
insertions: "2905"
deletions: "32"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "6385"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "1062"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "34395"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "37569"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "13717"
review_runs: "4"
review_interruptions: "0"
review_duration_seconds: "469298"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "13"
security_regressions: "8"
invariant_violations: "3"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-08-12"
---

# Review: Issue placement — configurable issue content location

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 45 · **Plan deviations:** 13 · **Security regressions:** 8

The fourth review of `issue/011`, and the first over the tree the review-remediation
round produced. Against every ground truth the feature is **better than the third
review found it**: six acceptance criteria are now fully met (up from five), none
is violated, blueprint invariant violations fall from **seven to three**, both
cross-group routing bypasses are closed, and the two `critical` security
regressions the third review recorded — `cmd_begin`'s missing containment gate and
`commit`'s missing placement gate — are genuinely fixed and pinned.

What holds it at `minor-drift` is not the alignment but the tail. Twenty-one
investigators and nine judges found **two data-destroying defects nobody had
found before**, and **two of the round's own fixes introduced new ones**. The
sharpest is a single unquoted expansion at `index.sh:338`: an ordinary filename
carrying a newline, committed by any teammate to the shared destination branch,
splits into two words, re-globs against the *developer's own checkout*, and
publishes that checkout's markdown frontmatter back to the shared branch as
forged issue rows. Three independent agents reached it by different routes.

**The reviewed tree is not the ledger's range.** `jimledger.sh files` returns the
build's **19 files** and `metrics` reports `f024b9e..3c1a78f` (15 commits); the
tree under review is **140 commits and 113 files** past that head (+14920/−237).
The frontmatter above therefore describes the build, not what was judged.
Alignment was assessed against the **working tree**, as the omission class
requires. This is the third consecutive review to record the same gap.

**The third review is superseded but not lost** — it is preserved at commit
`0563c42`, and its per-AC evidence remains the authority for anything this file
does not restate.

## Alignment

### vs. Spec acceptance criteria

- **AC 1 Config contract — met.** One key; the `branch` sentinel is provably
  indistinguishable from an absent key at the gate (`jimconf.sh:96` returns the
  literal `branch`, `place.sh:191` takes one branch for both).
- **AC 2 Default unchanged — drift.** The placement *mechanism* is genuinely
  inert with no key set: the `--auto`/`--reviewed` XOR gate is nested inside the
  `route` branch (`new.sh:124` → `:152`), and all six entry scripts short-circuit
  on `direct`. But three unrelated default-path behaviours changed inside the
  spec's range — `render.sh` now returns rc 1 on a stale-unrebuildable index where
  it returned rc 0 (`render.sh:118-126`, `:778`); `list <typo>` now refuses instead
  of silently creating a directory (`render.sh:395-410`); and `jimconf get`/`list`
  now refuse when run below a project root that holds a config (`jimconf.sh:378-393`).
  Each was argued and issue-backed, but AC 2's "behave exactly as today" is not
  literally met. The second clause is also still unmet: `tests/jimconf.sh:495`'s
  ordered-KEYS assertion had to change for the new key inventory.
- **AC 3 Writes land at the destination — met.** An exhaustive writer inventory
  found no unrouted collection writer anywhere in the repo. Both flows the third
  review named are closed: `skills/spec/scripts/reconcile.sh`'s citation sweep now
  drives `begin`/`commit`, and `/jim:partition` discloses re-points it will not
  apply, through a read-only grant carrying no publish verb. (The sweep's new code
  carries a containment defect — Finding 3 — but it misroutes nothing.)
- **AC 4 One commit per mutation — drift.** Message composition remains airtight
  (closed verb enum + validated slug; no free text reaches a subject, re-verified
  against the new cross-group caller). The third review's empty-commit gap is
  **closed** and pinned (`place.sh:1843-1850`, `tests/place.sh:915`). Three gaps
  remain: the direct arm still publishes via porcelain `git commit` with no hook
  scoping (`place.sh:752`), so a project `commit-msg` hook can rewrite the subject
  the plumbing arm guarantees; a `git status` failure yields rc 0 with nothing
  committed (Finding 4); and a diverged deferral folds N mutations into one commit
  under one mutation's subject, disclosed only as "being reapplied".
- **AC 5 Reads follow placement — drift.** The specific defect the third review
  named is **closed**: no read shape now adopts a filter as a collection or creates
  a stray directory, and all three read doors behave alike on a failed reindex
  (view on stdout, disclosure on stderr, rc 1). One new gap: on the direct arm a
  read of a not-yet-created collection *refuses* (`render.sh:222`, `:397`) where the
  unplaced project serves an empty view at rc 0 — which also breaks the analyst's
  first `insights` on a pre-first-filing project.
- **AC 6 Freshness — drift.** All three of the third review's grounds are **fixed**
  and non-vacuously pinned: last-seen no longer prefers a publish-only ref
  (`place_local_tip:423-440`), a diverged read discloses what it omits
  (`place_disclose_partial_view:546-555`), and the direct arm now probes the remote
  (`place_direct_probe:675-691`). One residual: that omission disclosure is
  origin-tier only (`place_resolve_tips:499`), so an offline read can serve a head
  that omits part of the bookmarked state while announcing it *is* the last-seen
  state.
- **AC 7 Writes never block — drift.** The no-loss property was re-verified from
  scratch across tip-state × tier × arm × attempt × reachability, and **holds** —
  every rc-0-without-publish exit is provably "nothing to publish". Both diagnostic
  gaps are closed: git's stderr is now captured on both tiers and relayed. Two new
  defects: `place_direct_publish`'s fail-open (Finding 4), and a diverged clone that
  can wedge permanently — once diverged, every later write recomputes the same merge
  base and refuses rc 3, under a message advising a re-run that reproduces it.
- **AC 8 Missing destination bootstrap — met.** Parentless, collection-only,
  genuine compare-and-swap on both tiers, matching the registry precedent.
- **AC 9 Coordination branch refused — met.** Compared against the configured value
  with no local default; every verb that can reach git re-establishes the gate in
  its own process — including `commit`, via `place_handle_drift:1070-1086`, which
  closes the third review's recorded violation. The config-drift attack is refused.
- **AC 10 Junk config refused — drift.** The gate never falls back, and the
  remediation closed three of the four fabricated-default routes. Three remain: a
  configured-but-empty value resolves to the sentinel at rc 0; a triple-quoted or
  unterminated value slips the new form check (the latter returning the raw config
  *line* as the value); and a typo'd key still defaults silently — the last a
  recorded decision, not an oversight. Separately the refusal is enforced on only
  **one of three resolver read doors**.
- **AC 11 Dangling origins tolerated — met.** Informational, blocks nothing, exits
  zero; under a placement the skip is *stated* rather than inferred, and the
  fixture now uses a genuinely path-shaped dangling origin.
- **AC 12 Rewrite detection — met.** No remote force-push false negative exists:
  every bookmark advance records only a tip the run actually observed at the
  destination's owner. The `|| -z "$remote"` clause the third review listed as
  uncovered is now pinned, and the direct-arm false alarm is gone. One literal
  edge: a pure rewind of a *remote-less* destination read from another branch is
  undisclosed.
- **AC 13 Auto-file scrub moment — met.** The polarity is no longer fail-open:
  under a placement exactly one of `--auto` / `--reviewed` is required (rc 2 for
  neither or both), the gate fires **before** the allocator spends an ordinal, and
  all nine quiet-path consumers stop on rc 4 and re-present interactively. The
  roster is now a property held to the emitter grant by a mechanical sweep rather
  than a count — in § 7a. Two counts survive in `ARCHITECTURE.md`, outside that
  sweep's corpus (Finding 32).

### vs. Plan tasks

All 13 tasks are implemented; the omission class is empty. Thirteen divergences,
none of them silent failures — but `plan.md` itself has never been amended, so a
reader taking it as current is misled on four design decisions and most of the
interface contract:

- **DD 2 / DD 9 — false, and widened.** Their load-bearing claim was "zero edits to
  the eight surfacing skills' batch blocks", "no §7a contract change for callers".
  Shipped: **11 SKILL.md files plus 3 reference files** edited outside the emitter,
  and §7a's canonical snippet is now `new.sh (--auto | --reviewed) …` with callers
  required to handle rc 2 and rc 4.
- **DD 5 — "reads never regenerate" is false.** Every routed read reindexes
  (`place.sh:1740`, `:1039`). The code and `ARCHITECTURE.md` both now say so and
  explain why; the plan does not.
- **DD 8 — plan-internal contradiction.** Its prose says `--msg`/`--msg-id`; the
  contract block and the code use `--verb`/`--id`.
- **Interface Contracts — five divergences.** `JIM_PLACE_ACTIVE=1` exists nowhere
  in the tree (shipped: `JIM_PLACE_TOKEN` plus an unplanned `JIM_PLACE_PREFIX`);
  exit code **1** is undeclared though live and reachable on a success path
  (`begin --read` returns 1 *with* a usable handle); the `mode` verb — which every
  entry script calls and `/jim:partition` holds a grant for — is absent entirely;
  `--verb` shipped optional on `--read`; `{token}` is an unplanned second
  placeholder; and `new.sh`'s rc 3 and rc 4 are unlisted.
- **Task 13's verify is self-contradictory** — it demands a deletion-free `tests/`
  numstat while task 1 requires editing a pre-existing assertion; the remediation
  widened this by rewriting three more existing cases.
- **Scope, widened past the File Manifest.** `jimconf.sh` was scoped to key
  plumbing; the round changed the **shared resolver's contract** for every consumer
  in the repo.
- **No scope creep against the exclusions.** No flip-migration scaffolding, no
  `timeout(1)`, no shared `valid-branch` verb, no branch-protection docs.

### vs. ARCHITECTURE.md

- **Preamble, no third-party deps, no `source`/`eval`, `set -uo pipefail`,
  BASH_SOURCE composition, `--end-of-options` / `--literal-pathspecs` discipline,
  verb-scoped permission clauses — respected** across the whole changed set.
- **Display-sanitizer form — now respected.** `index.sh:279-281`'s `row_safe`
  carries the corpus cap; all five corpus sanitizers agree.
- **Header accuracy — now respected.** All three inaccuracies the third review
  named (`cmd_mode`'s docstring, the parsing-tools line, `usage()`'s synopsis) are
  corrected, as are both `git cat-file blob` calls missing `--end-of-options`.
- **No artifact citations in script comments — respected in new code, ~43
  pre-existing.** `place.sh` and `skills/spec/scripts/reconcile.sh` are clean; the
  round's additions introduced none. Nothing mechanical enforces the rule.
- **ARCHITECTURE.md's own accuracy — two stale counts and one self-contradiction**
  (Findings 32, 33).
- **Commit discipline — violated.** 74 of 140 subjects in the spec's range exceed
  the 50-character limit; the remediation set this as a standing rule and the ratio
  did not improve.

## Investigation

### High-stakes regions investigated

#### `new.sh` — the single emitter (trust boundary)
- locations examined: `new.sh:1-339` (whole file), esp. `:96-97`, `:122-175`,
  `:202-236`, `:252-273`, `:279-298`, `:304-338`
- callers traced: 12 SKILL.md grant-holders; no production script calls it
- tests checked: `tests/issues.sh:2408-2810`, `:3332-3470`; `tests/place.sh:352-375`
- verdict: partial — `id-gate-before-path` and the `--origin` encoding are both
  genuinely fixed; `--created`/`--updated` reach YAML with neither gate nor
  encoder; eight refusals fire after the append-only ordinal is spent.

#### Publish state machine (`place_commit_changes` and callees)
- locations examined: `place.sh:1834-1930`, `:1527-1565`, `:493-517`, `:1416-1448`,
  `:1362-1390`, `:1293-1341`, `:1470-1497`
- callers traced: `place.sh:1745` (`cmd_run`), `:1179` (`cmd_commit`)
- tests checked: `tests/place.sh:516-606`, `:826-996`, `:1227-1535`, `:2072`
- verdict: partial — the attempt-1/attempt-N collapse is genuine and data-selected;
  `ref_old` is still not re-read on the origin-stays-origin retry while the comment
  above claims it is; four graft edge cases have no test.

#### Two-phase door and direct arm
- locations examined: `place.sh:588-650`, `:724-792`, `:794-933`, `:936-1056`,
  `:1058-1210`
- callers traced: `skills/spec/scripts/reconcile.sh:636,762,772`;
  `skills/issue/SKILL.md:181-195`; `partition-methodology.md:509-527`
- tests checked: `tests/place.sh:2104-2508`
- verdict: partial — both `critical` security regressions are **fixed and pinned**;
  `place_direct_publish`'s own containment gate remains unproven, and its `git
  status` read is fail-open.

#### Cross-group write paths (new code, never previously reviewed)
- locations examined: `skills/spec/scripts/reconcile.sh:439-781`;
  `skills/partition/SKILL.md:18,361-487,592-609`;
  `partition-methodology.md:270-294,474-609,736-804`
- tests checked: `tests/specreconcile.sh:292-345` (one routed case);
  `tests/docsurfaces.sh:217-244`; `tests/jimpartition.sh` — **no placement case**
- verdict: divergence — routing is correct on the arm it was designed for; the
  containment-guard split opens a write escape on the destination-is-checked-out
  arm, one handle leak remains, and `SKILL.md`'s own steps contradict the rule the
  reference doc carries.

#### `index.sh` / `backfill.sh` — untrusted input and artifact integrity
- locations examined: `index.sh:1-645`, `backfill.sh:1-281`
- tests checked: `tests/issues.sh:137`, `:702-747`, `:1674`, `:2513-2546`
- verdict: divergence — all four prior findings are fixed; three new integrity
  defects remain in `index.sh` and one in `backfill.sh`.

#### `jimconf.sh` — the shared resolver
- locations examined: `jimconf.sh:1-453`, esp. `:135-202`, `:207-279`, `:281-306`,
  `:310-346`, `:361-405`
- consumers traced: every `place.sh mode` caller; `render.sh:425`; the
  `deps_command_*` / `verify_command_*` families
- tests checked: `tests/jimconf.sh:44-188`, `:429-534`, `:1249-1288`
- verdict: partial — both new guards are real and correctly scoped, but enforced on
  one of three read doors.

#### `migrate.sh` — migration atomicity
- locations examined: `migrate.sh:1-505`, esp. `:81-154`, `:197-327`
- tests checked: `tests/issues.sh:2238-2386`; no placement case anywhere
- verdict: divergence — the chain-aware failure handler is logically correct and
  its held branch is pinned; a separate rc-0 destruction path sits beside it.

#### `render.sh` + the analyst boundary
- locations examined: `render.sh:1-783`, `agents/issue-analyst.md`,
  `skills/issue/SKILL.md:256-305`
- tests checked: `tests/issues.sh:902-989`, `:3702-3777`; `tests/place.sh:1350-1382`
- verdict: satisfied — both invariants the third review recorded as violated now
  hold; two low residuals.

#### Test-suite integrity
- locations examined: `tests/place.sh` (111 cases), `tests/issues.sh` placement
  region (35), `tests/docsurfaces.sh` (12), `tests/jimconf.sh` (9),
  `tests/specreconcile.sh` (1)
- verdict: partial — **4 of 168** cases cannot fail for the guard they name; on the
  third review's narrower slice, 3 of 146 (it reported 2 of 115). All five guards
  it named as uncovered are now pinned except `place_direct_publish`'s.

#### Resolution-note accuracy
- locations examined: 68 issues tied to this spec; the 10 most recently closed read
  in full
- verdict: partial — **0 fabricated test cases, 0 unresolvable shas, 0 closes
  without a `## Resolution`**; three durable records outrun the tree.

#### Per-AC investigation
Each of AC 1–13 was investigated against the working tree; the verdicts and their
evidence are recorded under *Alignment* above.

### Coverage

- Depth: thorough; `review_model: inherit`.
- **Full high-stakes set investigated.** **21 investigators dispatched, 21
  returned** — 10 by acceptance criterion (13 ACs, four paired), 8 by high-stakes
  region, 3 meta (test integrity, resolution-note accuracy, plan/architecture
  conformance). No undelegated set.
- The configured `review_fanout_cap` is **10**; the developer explicitly authorized
  exceeding it for this run. No region or AC rests on spine-level reading.
- **Convergence as evidence.** Three findings were reached independently by two or
  three agents on different tasks — `place_direct_publish`'s fail-open (AC 4, AC 7),
  the `migrate.sh` destruction path (region, judge), and the `index.sh:338`
  word-split (region, two judges). Each is recorded as confirmed rather than
  plausible.
- **Instrumentation gap:** the ledger's range ends at the build's head, 140 commits
  and 113 files behind the reviewed tree. Metrics describe the build; alignment was
  judged against the working tree. Third consecutive occurrence.

## Living intent

**Sensed:** 9 invariants · **holds:** 6 · **violations:** 3 (in-change 3 ·
pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 0

Down from seven violations in the third review. The four it recorded that are now
**closed**: `id-gate-before-path`, `placement-gate-before-git`,
`insights-capability-boundary`, `staleness-gated-reads`.

### Violations

- **untrusted-body-never-shell** — critical · violated · in-change ·
  `new.sh:317-318`, `index.sh:338`, `migrate.sh:233-239`. `--created` and
  `--updated` are the only frontmatter scalars the emitter writes with neither a
  grammar gate nor an encoder; a newline in either forges a pair that wins
  first-occurrence over the emitter's own `origin:`. The file header's claim that
  "scalar fields are YAML-encoded" is true of three of them. Separately
  `index.sh:338`'s unquoted expansion re-splits and re-globs the file list.
- **materialization-contained** — critical · violated · in-change ·
  `place.sh:1293-1341`, `place.sh:878-899`. All five literal clauses hold. The
  *plain name* clause fails in spirit: nothing rejects control characters, so a
  newline-bearing entry name clears every gate and steers `index.sh`'s enumeration
  out of the collection and into the reader's working directory — publishing the
  developer's own project-root markdown back to the shared branch as issue rows. A
  narrower path corrupts the two-phase base snapshot's line-oriented round trip and
  can delete a dotfile entry from the destination tree.
- **atomic-index-write** — medium · violated · in-change · `migrate.sh:144-148`.
  Atomicity itself is sound everywhere and the chain-aware failure handler
  correctly preserves every staged file that is an issue's last copy. But a row
  downgraded from `rename` to `skip-unmigratable` keeps its filename without
  reserving it, so a later row is assigned that name unopposed, the commit loop's
  second `mv` overwrites the first, the retire loop deletes the survivor, and the
  run exits 0 reporting success. Introduced by this round's own discriminator fix.

Holding: **single-emitter** (high), **id-gate-before-path** (critical),
**placeholder-by-position** (high), **placement-gate-before-git** (critical),
**insights-capability-boundary** (high), **staleness-gated-reads** (medium).

### Coverage

- appetite in force: `low` (no per-group override) — every invariant judged.
- Whole-group floor ran; all nine invariants are `judge`-method, so the floor
  produced no records. Territory conformance is **clean**: **zero strays**; 843
  out-of-territory tracked files bucket as other groups' code (`skills/` 66,
  `tests/` 14, `agents/` 11, `scripts/` 1) and project scaffolding (`docs/` 736,
  root 14, `.claude-plugin/` 1).
- judges: **9 dispatched, 9 returned** — change-selected, all within the cap of 10.
  None skipped by appetite or scope.
- registry: 0 entries — the rung is a no-op, not unconfigured.
- Two invariants carry wording risk rather than code fault: **single-emitter**'s
  separation at the two-phase door is convention, not mechanism (`commit` is
  verb-agnostic and publishes any file a handle-holder creates), and
  **insights-capability-boundary**'s agent doc says "nothing else on disk changes"
  while the granted verb can write an `INDEX.md` into any *existing* directory it
  names.

### Contracts

**Edges checked:** 7 · **holds:** 7 · **violations:** 0 (provider-side 0 ·
consumer-side 0)

- None — every checked edge holds on the mechanical floor (`contracts-check`
  returned `COVERAGE 4 4` with no leak or breaking facts).
- **The edge judge rung was not dispatched** — as in the third review, these seven
  rest on mechanical evidence alone.
- **A declaration-integrity gap sits beside the graph, not in it** (Finding 34):
  `BLUEPRINT.md`'s two new rows — `sdlc → issue` (placement-door) and
  `blueprint → issue` (placement-read) — are not backed by `Requires` entries in
  either consumer blueprint, both of which still read `updated: "2026-07-25"`.
  Since the graph is derived from `Requires` faces and its header says "do not
  edit", the next regeneration drops both rows.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 15 (0/11/0/0) |
| Files changed · insertions · deletions | 19 · +2905 · −32 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·4 |
| Stage durations (spec·research·plan·sec·build·review) | 6385s·1062s·34395s·37569s·13717s·469298s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·0 |
| Artifacts present | spec,research,security,plan,ledger |

The build range is `f024b9e..3c1a78f`. **The reviewed tree is 140 commits and 113
files beyond it** (+14920/−237) — these numbers describe the build, not the
subject. Verdict trajectory: `major-drift` (22) → `major-drift` (28) →
`minor-drift` (30) → `minor-drift` (45).

## Security regressions

Eight, in the reviewed tree. **Two were introduced by the remediation round
itself**; six pre-date it in the build and are found here for the first time.

1. **Containment guard dropped on the routed sweep's direct-handle arm** —
   `skills/spec/scripts/reconcile.sh:644-648`. *Introduced this round.* Handle
   entries are appended *after* the relpath + worktree-containment loop, justified
   by a comment asserting `place.sh` materialized them. True of the plumbing arm
   only: with `issue_placement` naming a checked-out branch, `cmd_begin` hands back
   the working tree's own collection, nothing materialized it, `[[ -f ]]` follows a
   symlink, and `cat > "$f"` writes outside the worktree. The two sibling
   enumerations in the same function reject exactly this.
2. **Row forgery and checkout leakage via an unquoted expansion** —
   `index.sh:338`. Unquoted command substitution with pathname expansion live; a
   shared-branch filename carrying a newline splits and re-globs against the
   developer's CWD, so project-root markdown is parsed as issues and published to
   the shared branch. Reachable because no gate anywhere rejects control characters
   in an entry name (`jimfile.sh:229-246` checks empty / absolute / `..` only).
3. **Silent rc-0 destruction of an issue** — `migrate.sh:144-148`. *Introduced this
   round.* See the `atomic-index-write` violation above.
4. **`place_direct_publish` is fail-open on `git status`** — `place.sh:749-750`.
   The exit status is discarded, so a corrupt index or refused pathspec reads as
   "nothing to publish": rc 0, nothing committed, handle deleted, success reported.
   `place_dirty_guard:601-613` is the same two lines *with* the check, and carries
   a comment naming this exact failure class.
5. **Two frontmatter scalars reach YAML unencoded** — `new.sh:317-318`.
6. **Warnings-section values are neither capped nor control-stripped** —
   `index.sh:517`, `:428`, `:448`, while every row value clears `row_safe`.
7. **A tab in an untrusted `created` re-splits the migration sort record** —
   `backfill.sh:117-131`; the corrupted field then becomes an `awk` operand,
   silently draining the work list.
8. **The resolver's value-form refusal does not cover the families whose values
   reach bash** — `jimconf.sh:228-234`; `deps_command_*` / `verify_command_*`
   resolve empty at rc 0 on an unreadable or malformed config.

No secrets committed. No proven shell-injection path. `GIT_TERMINAL_PROMPT=0`
prevents credential prompts.

## Findings

Forty-five, grouped. Priority is reviewer judgment.

**Data integrity and untrusted input**

1. **critical** — `index.sh:338`: quote the substitution and read the sorted list
   with `while IFS= read -r -d ''` (or `sort -z`), so a filename is one word
   whatever bytes it holds.
2. **critical** — `migrate.sh:144-148`: set `taken["$old"]=1` on the
   discriminated-validation-failure branch before `continue`.
3. **critical** — `skills/spec/scripts/reconcile.sh:644-648`: apply the `-L`
   rejection and worktree-containment check to the handle enumeration whenever
   `place_dir` resolves inside the worktree.
4. **critical** — `place.sh:749-750`: capture and check `git status`'s exit status,
   refusing on non-zero exactly as `place_dirty_guard:604-611` does.
5. **critical** — `place.sh:1293-1341` and `:1362-1389`: reject any entry name
   containing `[[:cntrl:]]`, in both the inbound and outbound gates.
6. **high** — `new.sh:96-97,213-214,317-318`: gate `--created`/`--updated` to the
   `SYNC(ts-shape)` grammar before emission, and add both to the header's untrusted
   list.
7. **high** — `index.sh:361-375`: append to `slugs_seen` only after the frontmatter
   gate, so the row set and the counts derive from the same population.
8. **high** — `backfill.sh:117-131`: strip or reject a tab in `created` before the
   sort record is joined; make the record NUL-delimited.
9. **high** — `jimconf.sh:228-234`: add `|| return 1` to the dynamic-suffix
   `parse_value` call and drop the `-f` short-circuit.
10. **high** — `jimconf.sh:323-329`: have `cmd_list` return non-zero when any
    `resolve` fails, per its own EXIT CODES contract.
11. **medium** — `jimconf.sh:197-199`: require a closing quote in the refusal
    regex, so an unterminated or multi-line string refuses rather than yielding the
    raw config line.
12. **medium** — `index.sh:517`, `:428`, `:448`: route these values through
    `row_safe` as every row value already is.

**Publish engine and placement**

13. **high** — `place.sh:1550`, `:1837`, `:1855`: advance the local ref when
    `merged == upstream`, or replace the "re-run to reapply" advice with the actual
    reconciliation step; today a diverged clone wedges permanently.
14. **high** — `place.sh:752`: scope hooks off for the direct commit (or build it
    with plumbing), and pin the subject against an installed `commit-msg` hook.
15. **medium** — `place.sh:1873-1884`: re-read `ref_old` on the
    origin-stays-origin retry, or narrow the comment to the two paths that do.
16. **medium** — `place.sh:751-752`: reset the staged paths on a failed direct
    commit, or say the collection is left staged.
17. **medium** — `place_disclose_unpublished`'s diverged branch: say the deferred
    mutations are being folded into this commit, and assert the commit count.
18. **medium** — `place.sh:493-517`: compute the head-vs-bookmark relation on the
    local tier too, so the partial-view note is not origin-tier only.
19. **medium** — `render.sh:222`, `:397`: let an absent *named* collection read as
    empty at rc 0 when the name came from the placement plumbing.
20. **medium** — `place.sh:1698`: on the remote-less path compare against
    `place_head_tip`, so a pure rewind is disclosed.
21. **medium** — `place.sh:1388` / `:751`: exclude the tmp namespace from the
    direct arm's `git add`, or add a `.gitignore` entry; a stranded tmp is
    publishable there and otherwise blocks every later placed write.
22. **medium** — `place_snapshot`: return 1 when the enumeration itself fails
    rather than reading a `find` failure as an empty collection.
23. **low** — `place_build_commit:1431`, `:1438`: carry the source mode rather than
    hardcoding `100644`, and relay git's stderr as `place_land` now does.
24. **low** — `place.sh:1551-1553`: branch the graft refusal message on an upstream
    *deletion* instead of reporting "also changed".
25. **low** — `place.sh:1927-1928`: name the surviving handle token in the
    attempts-exhausted message, and stop claiming "not lost" on the `run` path where
    neither the local commit nor the temp state survives.

**Cross-group flows**

26. **medium** — `skills/spec/scripts/reconcile.sh:659-661`: abort the handle
    before the `mktemp` failure return.
27. **medium** — `skills/spec/scripts/reconcile.sh:636-641`: reword the
    `begin`-failure message, which states a rewrite that has not happened.
28. **medium** — `skills/spec/scripts/reconcile.sh:520-523`: drop enumerated paths
    that prefix-match the issues root, not just the pathspec, so a nested root
    cannot double-sweep.
29. **medium** — `skills/partition/SKILL.md:399-401`, `:470-471`, `:607`: add the
    placement caveat; the file that actually loads still instructs the
    unconditional issue write its own reference doc forbids.
30. **medium** — `partition-methodology.md:517-532` and
    `skills/spec/scripts/reconcile.sh`: state the handle release as unconditional,
    and consider a `place.sh` verb that lists or prunes stranded handles.
31. **low** — `partition-methodology.md:544-551`: have the `UNAPPLIED` block name
    the two-phase door as the apply path and offer the rows as a tracked follow-up.

**Records, declarations and process**

32. **high** — `ARCHITECTURE.md:274`, `:320` (and `tests/jimconf.sh:820`): restate
    the surfacing-skill roster as a property, via `/jim:arch`. The closing issue's
    resolution implies these were swept; they were not.
33. **medium** — `ARCHITECTURE.md:395`: "carries placement … with no change to any
    of them" contradicts the same bullet's account of the required declaration;
    scope the clause to routing.
34. **high** — add the reciprocal `Requires` entries to
    `docs/specs/sdlc/000-blueprint` and `docs/specs/blueprint/000-blueprint` via
    `/jim:blueprint`; without them the two new contract-graph rows are dropped on
    the next regeneration.
35. **medium** — `remediation.md:813-814` contradicts `:68`: it still says the two
    cross-group write paths are owed when both are closed.
36. **medium** — file the two unfiled remainders (the `begin` handle fingerprint;
    the five unpinned `place.sh` guards) or reopen their parents; the tracked set of
    eight under-counts by two.
37. **medium** — amend `plan.md`'s DD 2, DD 5, DD 8, DD 9 and the Interface
    Contracts block, or file a divergence note; a reader taking it as current is
    misled on most of the CLI.
38. **low** — `plan.md:223-233`: restate task 13's property as "no pre-existing
    fixture is weakened", verified by neutering.
39. **low** — record the bash 4.3 floor once in `ARCHITECTURE.md`, or drop the
    corpus-wide claim from `place.sh:83-89`.
40. **low** — `jimconf.toml.example:12` still says arrays are "silently ignored";
    `jimconf.sh:137-138`'s docstring contradicts its own body; the platform
    blueprint does not declare the unset-vs-failed guarantee its consumer depends
    on.
41. **low** — commit-subject discipline: 74 of 140 subjects exceed 50 characters.

**Test integrity**

42. **high** — `tests/issues.sh:3464`: drop `--reviewed` so the case exercises the
    bare filing it claims; the XOR gate's `route`-scoping — AC 2's protection for
    the installed base — is pinned nowhere.
43. **medium** — `tests/place.sh:185`: retarget the fixture so the `valid-relpath`
    and leading-dash guards are reachable, and assert each refusal's own wording.
44. **medium** — pin the three load-bearing guards that deletion leaves green:
    `place.sh:746` (direct-publish containment), `place.sh:1276` (`authoritative`),
    and `place.sh:185-189` (the resolver-failure arm); and assert the plain-name
    wording in `tests/place.sh:532`, `:606`.
45. **medium** — `tests/docsurfaces.sh`: scope the `--reviewed` sweep to the
    `INTERACTIVE PATH` block rather than the skill directory, make the roster check
    bidirectional, and replace the three hardcoded floors; also add
    `assert_nonempty` to the unfloored `place_seed_collection` call sites and track
    the second `timeout`-shaped flake at `tests/jimalloc.sh:1131`.

## Deviations & feedback

**The compose-two-changes failure mode recurred, for the third round running.**
The third review recorded that two of the remediation's own defects came from
composing two individually-correct changes. This round did it again in a new way:
`migrate.sh`'s discriminator fix was correct in isolation and correct against its
own test, but it moved a downgrade *past* the reservation loop that the earlier
build-phase downgrades sit inside — and destroyed an issue. And the routed sweep
correctly stopped enumerating the worktree copy, then re-added the handle's entries
past the guard that had been protecting them. Both fixes were proven red-first
against the defect they targeted. Neither was checked against the invariant that
sat one loop away.

**Neuter-and-verify proves a fix; it does not prove the surroundings.** Every one
of this round's eight closes was verified by disabling its guard and watching the
pinning case go red — a genuinely strong discipline, and it is why the four
invariant repairs held up under independent judging. It says nothing about what
else the edit is now adjacent to. The by-file rule was written for exactly this and
was followed for the functions the issues named; the two new defects live in
functions no open issue named.

**A resolution note is still outrunning the tree, and it is mine.** `#317`'s note
implies `ARCHITECTURE.md`'s counts were all restated; two survive, in the same
defect class the issue was filed against. The third review recorded this same
pattern against `#269` and called it "a false clean" for the next reader. `#269`
answered it with a dated `## Correction`, which is the right instrument and should
be used again here.

**The ledger's grounding gap is now a standing defect, not an incident.** Three
consecutive reviews have judged a tree the instrumentation does not describe, each
recording it and working around it. `jimledger.sh files` returning the build's 19
files against a 113-file subject is not a review-time nuisance — it silently
narrows change-selection for the living-intent sensor too. It has never been filed.

**What the numbers say, against what they look like.** Findings rose 30 → 45 while
alignment stayed `minor-drift`. That is not regression: ACs met went 5 → 6, invariant
violations 7 → 3, and both contract bypasses closed. The count rose because this run
dispatched 21 investigators and 9 judges against a tree three prior reviews had
already worked over, and because three of the sharpest findings needed two or three
independent agents to converge before they were visible at all. A review that finds
more in a better tree is measuring its own depth, not the code's decline — but two
of the forty-five destroy user data, and that is the fact the completion gate turns
on.
