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
review_runs: "3"
review_interruptions: "0"
review_duration_seconds: "400135"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "11"
security_regressions: "4"
invariant_violations: "7"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-08-12"
---

# Review: Issue placement — configurable issue content location

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 30 · **Plan deviations:** 11 · **Security regressions:** 4

The feature is delivered and the class that produced two prior `major-drift`
rounds is closed: **no state composition loses or silently drops a mutation**,
and attempt 1 is now structurally identical to attempt N. Five acceptance
criteria are fully met, eight are partial, none is outright violated.

**The reviewed tree is not the ledger's range.** The ledger records the build at
`f024b9e..3c1a78f` (15 commits); the tree under review is **45 commits beyond
`3c1a78f`** — the remediation recorded in `remediation.md`. The metric
frontmatter above therefore describes the build, not what was judged. Alignment
was assessed against the working tree, as the omission class requires.

What holds it at `minor-drift` rather than better: two cross-group flows write
into this collection without routing through the placement primitive, so AC 3's
"every collection write" is false as written; a two-argument read shape bypasses
placement at rc 0; and the two-phase door on the checked-out arm hands a
directory to an agent-writer with no containment check.

## Alignment

### vs. Spec acceptance criteria

- **AC 1 Config contract — met.** The `branch` sentinel is genuinely
  indistinguishable from an absent key, and the branch-name gate lives in `mode`,
  so reads refuse identically to writes.
- **AC 2 Default unchanged — drift (literal).** Behaviour on the default path is
  unchanged and the passthrough is a real `exec`. The criterion's second clause
  ("the existing test suite passes without modification") is not literally met:
  three pre-existing assertions in `tests/jimconf.sh` were edited for the new key
  inventory. Any new config key forces this.
- **AC 3 Writes land at the destination — drift.** Every write path *inside* the
  issue group routes correctly. Two documented flows in other groups do not:
  `/jim:spec reconcile --apply`'s citation sweep and `/jim:partition`'s
  rename/split/merge materialization both enumerate the working checkout, rewrite
  issue bodies in place, and regenerate the index with an explicit directory
  argument — which is the routing opt-out.
- **AC 4 One commit per mutation — drift.** Message composition is airtight (verb
  enum + validated id; no free text reaches a subject). Two gaps: an empty commit
  is reachable on the plain-build arm after a retry's base recomputation, and the
  direct arm publishes via porcelain `git commit` without `--no-verify`, so
  project hooks can rewrite the subject the plumbing arm guarantees is fixed.
- **AC 5 Reads follow placement — drift.** `dir_given` returns "a directory was
  named" on argument *count* for the two-argument shapes, so
  `/jim:issue list open high` adopts `high` as the collection, creates
  `./high/INDEX.md` in the developer's checkout, and prints at rc 0 while the
  destination goes unread. `insights` is correct on all three placement states.
- **AC 6 Freshness — drift.** A reachable remote is genuinely fetched before
  serving, and the unreachable case is disclosed. But "last-seen" prefers
  `refs/heads/<dest>`, which only a publish advances, over the bookmark, which
  every authoritative read advances — so a clone can serve *older* than what it
  last saw while announcing the opposite. A `diverged` read serves the local head
  and omits the commits it just fetched, undisclosed. The direct arm never
  consults the remote at all.
- **AC 7 Writes never block on the network — drift (reporting only).** No
  mutation is lost in any traced composition, including deferred → reconnect →
  lost race → remote-drops-mid-retry. Both rc-0-without-publish exits are
  provably "nothing to publish". The gaps are diagnostic: the non-contention
  check is origin-tier only, and the direct arm reports an unreachable remote as
  divergence.
- **AC 8 Missing destination bootstrap — met.** Parentless, collection-only, and
  a genuine compare-and-swap on both tiers, matching the registry precedent.
- **AC 9 Coordination branch refused — met.** Compared against the configured
  value with no local default; an unestablishable guard refuses.
- **AC 10 Junk config refused — drift.** The gate never falls back. The
  *resolver* can hand it a fabricated `branch` at rc 0 — an unreadable config, a
  single-quoted or bare value, a typo'd key, or a run started from a
  subdirectory (jimconf reads `./jimconf.toml` with no walk-up). Pre-existing in
  jimconf's shared read path.
- **AC 11 Dangling origins tolerated — met.** Nothing blocks, nothing exits
  non-zero, the lint is skipped under placement with the skip *stated* rather
  than inferred, and the test now uses a genuinely dangling path.
- **AC 12 Rewrite detection — met.** The bookmark never advances before the
  destination is reached, no silent-rewind path exists, and the detector
  distinguishes `--is-ancestor` rc 1 from rc 128. One precision defect: the
  direct arm can raise a false alarm on a stale checkout.
- **AC 13 Auto-file scrub moment — drift.** All nine quiet-path consumers pass
  `--auto` and degrade on rc 4, verified per skill. The polarity remains
  fail-open and is now documented truthfully in all four places. Three roster
  counts are stale, and the sweep's fallback-target assertion is tautological.

### vs. Plan tasks

All 13 tasks are implemented; the omission class is empty. Divergences:

- **DD 1** — tree built through a scratch index rather than `mktree`. Justified in
  the header: `mktree` cannot preserve paths outside the collection.
- **DD 2** — its load-bearing claim ("zero edits to the eight surfacing skills'
  batch blocks and no §7a contract change for callers") is **false in the shipped
  result**: nine SKILL.md files were edited and the §7a caller contract changed.
  The contract's `JIM_PLACE_ACTIVE=1` does not exist; the shipped pair is
  `JIM_PLACE_TOKEN` plus an unplanned `JIM_PLACE_PREFIX`.
- **DD 5** — "reads never regenerate" diverged; every run reindexes the
  materialized copy, and the code states the opposite rationale. Recorded, and
  the blueprint invariant was amended to match.
- **DD 9** — deliberately diverged: enforcement moved into the emitter, giving up
  exactly the "no cross-group SKILL.md changes" the DD used to justify §7a.
- **Task 13's own verify is self-contradictory** — it demands `tests/` additions
  only, while task 1 requires editing a pre-existing assertion.

Seven items shipped that no task or AC asked for: `render.sh`'s exit-status
change on a pre-existing read surface, the held-stdout mechanism, the origin-lint
suppression, the `mode` verb and positional placeholder gating, nine cross-group
SKILL.md edits, the analyst's directory contract, and a bash floor raised 4.0 →
4.3 recorded in one file's header and nowhere else. No scope creep against the
spec's Out-of-Scope list.

### vs. ARCHITECTURE.md

- **Preamble, no third-party deps, no `source`/`eval`, BASH_SOURCE composition —
  respected** across all seven scripts.
- **Permission conventions — respected.** Three verb-scoped clauses; the executor
  verb `run` is withheld, matching the rule that names this skill as its
  precedent.
- **No artifact citations in script comments — respected in `place.sh`** (zero
  occurrences). ~40 exist in the six sibling scripts, all pre-existing; two sit
  in the comment block this build extended.
- **Display-sanitizer form — violated in new code.** `index.sh:476` introduces a
  sanitizer with no length cap, diverging from the corpus form; the value is the
  config-supplied branch name written unbounded into a committed artifact.
- **Header accuracy — partial.** `cmd_mode`'s docstring still claims to be "the
  only place the config gate is evaluated" (three other functions call
  `place_destination`); the parsing-tools line omits `head` and `cut`; and
  `usage()` still prints `--verb` as required while the header marks it optional.

## Investigation

### High-stakes regions investigated

#### Publish state machine (`place_commit_changes` and callees)
- locations examined: `place.sh:1577-1652`, `:1292-1330`, `:1201-1262`,
  `:473-497`, `:444-452`, `:513-530`, `:1157-1175`, `:1354-1363`
- callers traced: `place.sh:1524` (`cmd_run`), `:974` (`cmd_commit`)
- tests checked: `tests/place.sh:790, 826, 843, 936, 968, 1011, 1056, 1086,
  1191, 1217, 1243, 1271, 1297, 1394`
- verdict: partial — attempt 1 and attempt N are one path; the arm is selected by
  data (`base == tip`), not by attempt number. `ref_old` is not re-read on the
  origin-stays-origin retry though the comment above claims it is; WP2's
  "capture git's stderr" is still unimplemented (`2>/dev/null` at `:1254`,
  `:1260`), so the non-contention message can only guess at the cause.

#### Two-phase handle and direct arm
- locations examined: `place.sh:789-881`, `:884-989`, `:595-646`, `:552-560`,
  `:580-593`, `:684-698`, `:773-787`
- callers traced: `SKILL.md:183, 189, 261, 269` (prose only — no script callers)
- tests checked: `tests/place.sh:570, 1554, 1580, 1650, 1668, 1711, 1749, 1766,
  1800, 1823, 1843, 1884, 1962`
- verdict: divergence — `cmd_begin`'s checked-out arm never calls
  `place_worktree_contained`; the dirty guard is fail-open on any git failure;
  the containment gate in `place_direct_publish` is unproven (deleting it leaves
  the suite green); `cmd_commit`'s plumbing arm re-verifies neither destination,
  prefix, nor HEAD.

#### Untrusted input and trust boundary
- locations examined: `new.sh:146-147, 230-249, 259-276`, `index.sh:340-441,
  469-491, 519-528, 552-574`, `backfill.sh:156-201`, `place.sh:241-261,
  1088-1136`
- verdict: partial — no proven exploitable path, no shell injection, no path
  escape, no secrets. Two data-integrity routes to forging `INDEX.md` rows: the
  ` · `-separator overwrite via unencoded `origin`, and `printf '%b'` escape
  expansion in the warnings section.

#### Convention conformance
- locations examined: `place.sh` (whole), the six sibling scripts' placement
  regions, `SKILL.md:6`
- verdict: partial — see *vs. ARCHITECTURE.md*.

#### Test-suite integrity
- locations examined: `tests/place.sh` (91 cases), `tests/issues.sh:2882-3466`,
  `tests/docsurfaces.sh`
- verdict: partial — **2 of 115 cases** cannot fail when the guard they name is
  deleted, down from a systemic finding in the prior round. Composed states are
  genuinely covered. Uncovered guards: the `|| -z "$remote"` bookmark-advance
  clause (deleting it silently disables rewrite detection for remote-less
  repos), the leading-dash tree-entry gate, `place_snapshot`'s regular-files
  refusal, and attempts-exhausted.

#### Per-AC investigation
Each of AC 1–13 was investigated against the tree by a dedicated investigator;
the per-AC verdicts and their evidence are recorded under *Alignment* above.

### Coverage

- Depth: thorough; `review_model: inherit`.
- **Full high-stakes set investigated.** 16 investigators dispatched — 13 by
  acceptance criterion, 3 by region — plus one for plan conformance. The
  configured `review_fanout_cap` is 10; the developer explicitly authorized
  exceeding it for this run, so no region or AC rests on spine-level reading.
- investigators: 16 dispatched, 16 returned. No undelegated set.
- Instrumentation gap: the ledger's range ends at the build's head, 45 commits
  behind the reviewed tree. Metrics describe the build; alignment was judged
  against the working tree.

## Living intent

**Sensed:** 9 invariants · **holds:** 2 · **violations:** 7 (in-change 7 ·
pre-existing 0 · unlocalized 0) · **skipped:** 0 · **failed/unconfigured:** 0

### Violations

- **untrusted-body-never-shell** — critical · violated · in-change ·
  `new.sh:238`, `new.sh:270`, `backfill.sh:178`. `origin` is emitted as a bare
  plain scalar, not YAML-encoded as the rule states. Separately, `awk -v`
  expands escape sequences in untrusted `created`/`updated` values, so a literal
  `\n` in an issue file becomes a real newline inside the frontmatter block.
- **id-gate-before-path** — critical · violated · in-change · `new.sh:213`,
  `new.sh:218`. A path is composed and stat'd before `valid-id` runs at `:226`;
  the comment block at `:224-225` asserts the ordering those lines break.
- **placement-gate-before-git** — critical · violated · in-change ·
  `place.sh:958-975`. The routed arm of `commit` hands a state-file destination
  to `git push`/`update-ref`/`ls-remote`/`fetch` without re-running validation or
  the coordination-branch refusal; the direct arm re-proves both.
- **materialization-contained** — critical · violated · in-change ·
  `place.sh:810-821`. All five literal clauses hold in `place_materialize`. The
  spirit fails at `cmd_begin`'s checked-out arm, which issues a write handle over
  a shape-checked-only prefix; the containment refusal arrives at `commit`, after
  the agent has written.
- **insights-capability-boundary** — high · violated · in-change ·
  `render.sh:108-112`, `index.sh:301`. The analyst's grant is `Read` plus
  `render.sh *`, but every `render.sh` verb calls `ensure_index`, which `mkdir -p`s
  an analyst-chosen directory and writes an `INDEX.md` into it — so the agent
  doc's "the capability is absent, not merely forbidden" is falsifiable.
- **atomic-index-write** — medium · violated · in-change · `migrate.sh:232-243`.
  The retire loop is rename-chain aware; the *failure* handler is not, so a
  mid-commit `mv` failure on a chain overwrites a pending file's only copy and
  then deletes its staged tmp — a hole, while the error text asserts "none has
  been lost".
- **staleness-gated-reads** — medium · violated · in-change · `place.sh:869`,
  `place.sh:1508-1513`. The three read doors do not behave alike: a routed read
  that served a stale view sends the view to **stderr** labelled "not published"
  with stdout empty, and the two-phase read handle deletes the materialized copy
  and refuses instead of degrading.

Holding: **single-emitter** (high) and **placeholder-by-position** (high).

### Contracts

**Edges checked:** 5 · **holds:** 5 · **violations:** 0

The graph names `issue` as provider on five edges (`emitter` and
`candidate-batch-contract` to both `sdlc` and `blueprint`; `validator-lockstep`
to `platform`). The mechanical floor reports full coverage and produced no leak
or breaking facts. **The edge judge rung was not dispatched** — these five rest
on mechanical evidence alone.

### Coverage

- appetite in force: `low` (no per-group override) — every invariant judged.
- Whole-group floor ran; territory conformance is **clean** (zero strays; 817
  out-of-territory files are other groups' code and project scaffolding,
  bucketed).
- judges: 9 dispatched, change-selected, all within the cap of 10. None skipped
  by appetite or scope.
- registry: 0 entries — the rung is a no-op, not unconfigured.
- **Grounding gap:** the change set came from `jimledger.sh files`, which returns
  the *build's* 19 files. The remediation's 45 commits are outside the ledger's
  range, so selection was computed against a narrower set than the tree judged.
  It did not alter selection in practice — the remediation touched the same files
  — but the grounding is narrower than the subject.
- Two invariants carry wording risks rather than code faults:
  **single-emitter**'s first clause read alone would classify the documented
  two-phase edit path as a breach (recommend "created only through `new.sh`"),
  and **staleness-gated-reads** is self-undermined on the placement arm, where
  extraction order makes the working-tree gate fire on every routed read.

## Metrics

Build range `f024b9e..3c1a78f`: 15 commits (11 feat, 0 fix, 0 test, 0 refactor),
19 files, +2905/−32. Stage durations: spec 6385s, research 1062s, plan 34395s,
sec 37569s (2 runs), build 13717s. This is the third review run.

The remediation beyond the build range is 45 commits and is not reflected in
these numbers. Suite at review time: **1322 passing, 0 failing**.

## Security regressions

Four introduced by this build's own code:

1. **`cmd_begin`'s checked-out arm has no containment gate** — an agent
   following the documented §6a flow can write outside the worktree through a
   symlinked collection path (`place.sh:810-821`).
2. **`commit`'s routed arm does not re-establish the placement gate** —
   `place.sh:958-975`; the reachable case is config drift between `begin` and
   `commit`.
3. **Four sites print config-derived names raw** — `place.sh:168, 196, 556,
   588`; `:196` prints the value *because* it failed validation.
4. **`index.sh:476`'s sanitizer has no length cap**, so a branch name lands
   unbounded in a committed artifact.

Pre-existing, surfaced here, not introduced: the `origin` encoding gap and both
`INDEX.md` row-forgery routes (` · ` separator overwrite; `printf '%b'` escape
expansion), and the `awk -v` frontmatter injection in `backfill.sh`.

No secrets committed. No new injection surface into a shell. `GIT_TERMINAL_PROMPT=0`
prevents credential prompts.

## Findings

Thirty recorded. The ones that would change a decision:

1. **AC 3 — two cross-group flows bypass placement** (`/jim:spec reconcile`'s
   citation sweep; `/jim:partition`'s migrate arms). Untracked before this
   review.
2. **AC 5 — `list <filter> <filter>` bypasses placement at rc 0** and creates a
   stray directory in the checkout.
3. **`cmd_begin` direct arm — no containment before an agent writes.**
4. **AC 6 — "last-seen" can be older than what was last seen.**
5. **`backfill.sh` `awk -v` frontmatter injection**, and **two routes to forging
   `INDEX.md` rows**.
6. **`migrate.sh`'s failure handler is not rename-chain aware** — a hole, under a
   message claiming nothing was lost.
7. **A routed read's view goes to stderr labelled "not published"** when the
   index could not be rebuilt.
8. **`cmd_begin` refuses where `cmd_run` degrades** — the insights door.
9. **Two test cases cannot fail**; the `|| -z "$remote"` bookmark clause is
   untested.
10. **Three stale roster counts** and three header inaccuracies in `place.sh`
    that a closed issue's resolution note claims were fixed.

## Deviations & feedback

**The remediation's own resolution notes overclaim in two places.** #269's note
says the header "names the parsing tools it actually uses" and was corrected;
`cmd_mode`'s docstring, the parsing-tools line, and `usage()`'s synopsis are all
still wrong. #269 also did not fix the `--end-of-options` sweep completely — two
`git cat-file blob` calls remain. A resolution note is the durable record; when
it is more complete than the change, the next reader inherits a false clean.

**Two defects were introduced by the remediation itself, each by composing two
changes that were correct alone.** The held-stdout mechanism (WP13) and the
stale-view non-zero status (WP13) compose into a routed read whose view lands on
stderr. The direct-arm rewrite disclosure (WP8) reintroduces on that arm the
false-alarm class WP5 removed from the plumbing path. This is the same
compose-two-axes failure mode the remediation was written to close, and it
recurred inside the remediation.

**The bar worked.** The data-loss class that produced two `major-drift` rounds is
genuinely closed and was verified by hand across compositions the tests do not
cover. Test integrity moved from a systemic finding to 2 cases in 115. What
remains is concentrated at the edges — the second argument, the third door, the
other group's write path — which is where a feature of this shape fails once its
centre is sound.
