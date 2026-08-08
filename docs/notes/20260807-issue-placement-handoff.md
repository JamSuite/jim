# Issue placement (`issue/011`) — handoff

*Written 2026-08-07 at the end of the build + review cycle; revised the same day
after the defect-fix pass. Branch `feat/id-coordination`. Everything described
here is committed; the working tree is clean.*

## Status at a glance

| | |
| :--- | :--- |
| Spec | `docs/specs/issue/011-issue-placement/` — `status: approved` |
| Plan | 14/14 tasks `[x]`, `status: approved` — **deliberately not `complete`** |
| Build | shipped, then the defect-fix pass below; 1279 tests green |
| Review | re-run 2026-08-08 over `f024b9e..HEAD`: **`major-drift`**, 28 findings, 5 of 8 invariants violated, 2 provider-side contract gaps |
| Blueprint | `issue` group refreshed; contract graph reconciled (23 edges, 19 faces, no findings) |
| Follow-ons | 16 from the first review (7 closed); 19 more from the second (#278–#296), all open |
| Build base | `f024b9e` (also in `.git/jim-build-base-011`) |

**The plan is still not complete, and the second review is why.** The fix pass
closed the four original defects but introduced one critical and two high of the
same class. Do not read the first review's "four defects" framing as the current
state — `review.md` was overwritten and is authoritative.

## The defect-fix pass

Six issues closed. Each fix went red-first at a shell, and each new test was
checked non-vacuous by neutering the thing it guards and watching it fail.

| Issue | Fix |
| :--- | :--- |
| **#270** | `place_substitute` matches whole arguments only. A title containing `{}` no longer has the run's temp path substituted into it, or into the slug. |
| **#267** | `place_local_tip` falls back to the bookmark when `refs/heads/<dest>` is absent, so a clone that has only ever read serves what it last saw instead of an empty collection. The ref a local swap must match is no longer the commit's parent, so the CAS old value travels separately. |
| **#265** | Deferral is resumed. A reachable run builds on unpublished local commits when they fast-forward (push carries them, subjects intact) and folds their content in from the common ancestor when the destination moved too. The bookmark no longer advances for a commit the destination never saw, and `cmd_commit` discloses its own deferral. |
| **#264** | `begin --read` in direct mode returns `direct-read`, which `commit` refuses; the write arm re-asserts HEAD and refuses the `branch` sentinel. |
| **#276** | The freshness `touch` is gone; the index is regenerated in the materialized copy, after the base snapshot so a write publishes the correction. |
| **#272** | The vacuous cleanup case, the two "tip unmoved" cases that could not move either way, the dangling-origin case that created its own origin, the unchecked fixture, and the bare `rev-parse` baselines. Adds the direct-token branch, the `issues_path` refusal, `--id` validation, and the local-tier retry. |
| **#262** | AC #13's scrub moment moved from prose to the emitter. `new.sh --auto` declares a batch unreviewed and exits 4, having written nothing, when it would publish to an unacknowledged placement; the nine auto-filing skills pass the flag and fall back to the interactive batch on that code. |

`ARCHITECTURE.md` was refreshed through `/jim:arch` for the behavior these
changed. `review.md` is **not** updated — it is the record of the review that
found them, and the re-review has not been run.

#272 was closed on its proposed action and its top-ranked holes. The tail it
listed is still uncovered and was judged not worth its own issue: `place_commit_tree`'s
fallback identity, `place_snapshot`'s non-regular-file refusal, `place_regraft`'s
already-applied early return, the argument-shape refusals, and `place_shown`'s
control-character scrubbing.

## What shipped

A `issue_placement` config key naming the branch the issue collection lives on.
Default sentinel `branch` = the current working branch (today's behavior,
byte-identical). Any other value names a destination branch, and every read and
write goes there whatever branch the work happens on.

Mechanism — `skills/issue/scripts/place.sh` (~1130 lines, new):

- Writes reach a branch nobody has checked out **by plumbing, never checkout**:
  materialize the tip's collection into a temp dir, run the wrapped command
  against it with CWD still the primary checkout, commit via `hash-object` → a
  scratch `GIT_INDEX_FILE` → `commit-tree` → ref CAS or push-as-CAS.
- **Routing lives inside the six entry scripts**, not their callers. Because the
  emitter is the single write door, all eight surfacing skills' candidate batches
  inherit placement with no per-skill change.
- Suppression is a **run-scoped token pair**, never a boolean — an inherited
  `JIM_PLACE_TOKEN` is ignored and disclosed rather than silently disabling
  centralization.
- A lost race replays the changed set (adds, edits **and deletes**) onto the
  winner's state, or refuses with the path named. The wrapped command is never
  re-run, so a filing race cannot double-allocate an ordinal.
- Direct mode when the destination *is* checked out: stage and commit by path
  rather than moving the ref under the working tree.

Two deviations from the plan text, both approved during the build: the `mode`
verb holds the gate and token comparison in one place rather than six copies,
and `JIM_PLACE_ACTIVE` is **not** set (a boolean that also suppresses routing
would reinstate the very finding the token pair exists for).

## What the review found

Full detail in `docs/specs/issue/011-issue-placement/review.md`. The four that
matter, each **reproduced at a shell**, not argued from the code. All are
placement-only — the default path is clean.

*All four are fixed, and so is everything under "Also worth knowing" except the
`issue-analyst` gap (#266). Kept here because the reproductions are what a
re-reviewer should re-run.*

### 1. Placeholder substitution corrupts the durable id — *critical*

`place_substitute` does an unconditional substring replace of `{}` and
`{token}` over **every** forwarded argument, and `new.sh` is the only entry
script forwarding free-form user text.

```
--title 'Fix the {} placeholder in output'
  -> title: "Fix the /tmp/tmp.P6mm4tbCV4/collection placeholder in output"
  -> slug:  20260807-fix-the-tmp-tmp-p6mm4tbcv4-collection-placeholder-in-output
```

The slug is the durable id, written to an **append-only** registry — the
corruption cannot be corrected by any later append. `{}` in a developer-tool
title is ordinary (`interface{}`, `map[string]interface{}`, a JSON literal).

Fix shape: substitute only arguments that are *exactly* the placeholder. Every
current caller passes them whole, so it is behavior-preserving.

### 2. A deferred mutation is discarded, silently — *critical*

```
offline:   place.sh commit <tok> --verb close --id 20260101-a
           -> rc 0, local commit, no stderr at all
reconnect, one read, then any write:
           -> remote: [open]   local: [open]
```

Three mechanisms compound: nothing ever pushes the deferred commit; `place_land`
force-resets the local ref with no old-value; and the one warning is consumed by
any intervening read. AC #7 says "No mutation is ever silently dropped."

Note the *filing* path is safe — the allocator hard-fails offline first. The
exposure is the `begin`/`commit` edit flow, the one with no allocator gate.

### 3. A read-only handle can publish — *critical, security*

```
$ place.sh begin --read                 ->  direct	docs/issues
$ place.sh commit direct --verb close   ->  rc 0
  HEAD now: HALF-FINISHED PRIVATE NOTE
```

In direct mode `begin --read` returns the fixed literal `direct`, which carries
no read flag and skips the dirty guard. So the insights flow's own token is a
publish capability. `SKILL.md` states "A read handle cannot publish" — true only
for plumbing handles. Same arm also never re-checks HEAD, so a branch switch
between `begin` and `commit` can push a whole feature branch to the shared
issues branch.

### 4. Offline reads serve an empty collection — *high*

A clone that has only ever *read* has no `refs/heads/<dest>`, so an unreachable
remote yields an empty materialization announced as "serving the last-seen
state". The bookmark ref holds the right sha and is simply never consulted.

The fixture hides this: `place_seed_collection` creates the local branch in the
same repo, making the real case unrepresentable.

### Also worth knowing

- **AC #13 was violated, and it was a plan defect** *(fixed — #262)*. The
  auto-file scrub degrade was stated in `skills/issue/SKILL.md` §7a and executed
  by **none** of the nine surfacing skills — each has its own local
  `IF auto_issue_file == "true"` branch, and §7a is not loaded when e.g.
  `/jim:build` runs. A pointer inherits a rule to consult, not a branch to take.
  DD 9's "one edit, eight inheritors" reasoning does not hold for behavior. The
  lesson generalizes past this AC: single-sourcing a *rule* into §7a works,
  single-sourcing a *branch* does not, and the fix was to move the decision
  somewhere mechanical rather than to write the rule in more places.
- **`agents/issue-analyst.md` was never updated** — it still reads
  `docs/issues/*.md` literally, so under placement it takes its roster from the
  destination and its bodies from the branch-local collection.
- **One invariant regression**: `staleness-gated-reads` *(fixed — #276)*.
  `place_materialize` `touch`ed the index so the mtime gate always reported
  fresh, which is sound only while every write goes through the emitter.
  Resolved **fix-code** at the blueprint fork — the invariant's wording stands,
  the code changed.

## Corrections made to my own work during the cycle

Recorded so a resuming agent does not re-derive them:

- I recorded **AC #13 as satisfied**; the AC sweep showed the rule is inherited
  by nobody. `review.md` carries the corrected verdict. My `docsurfaces`
  invariant made this worse by certifying the rule was "stated", which is not
  the property that matters.
- I added `place.sh` to the blueprint's **Provides** face while writing that
  nothing outside the group calls it — a contradiction that would have
  registered as a dead face. Removed (amended into `1d6b2f5`); its guarantees
  live in two new invariants instead.
- Two agents disagreed on whether a newline in a tree entry name silently
  deletes a destination file. I built the fixture — **the victim survived**; the
  claim is refuted. Residual is a spurious rc 3, not data loss.

## Next steps, in order

1. **Fix the three the fix pass introduced**, in this order — they share a
   function and are cheaper together than apart:
   - **#282** the `ahead` deferral losing its commit on a lost race (critical)
   - **#285** the `diverged` arm skipping the graft conflict rule on attempt 1 (high)
   - **#287** the local-tier retry's inverted read order (medium)
   The first two have one shape between them: re-resolve the base inside the
   retry loop, and route the diverged case through `place_regraft` from attempt
   1. That also closes **#284** (the diverged index gap) for free.
2. **Correct the fail-direction prose** — **#278**, in `new.sh`, `SKILL.md` §7a
   and `ARCHITECTURE.md` (high, security). Unconditional and cheap: the text
   claims a property the code inverts. Deciding whether to *change* the polarity
   is a separate design fork recorded in the same issue.
3. **Fix `cmd_begin`'s two refusal-reporting defects together** — **#263** (rc 0
   on a containment refusal) and **#280** (rc 2 flattened to rc 1). Same path,
   same function, both edited around during the fix pass.
4. **Re-run `/jim:review`**, then mark the plan `complete`.

Everything else from the second review is tracked and not blocking: **#279**,
**#281**, **#283**, **#286**, **#288**–**#296**.

**The blueprint fork was deliberately declined.** Five invariants went from
holding to violated because of the fix pass; amending them to match the new code
would record the regression as the spec. Every in-change violation was routed to
an issue instead, so the no-drop guarantee is intact.

Two items were held back from that routing on purpose, because they are
decisions about invariant *text* rather than defects, and they should be taken in
a blueprint pass once the code is fixed:

- `staleness-gated-reads` says "regenerate the index only when stale". In a
  freshly materialized directory staleness is **unknowable** by mtime —
  `place_materialize` writes entries in `ls-tree` order, so relative mtimes
  encode filename order, not edit history. The clause needs to acknowledge that
  arm; the "never serve a stale view" half stands.
- `untrusted-body-never-shell` names `--origin` alongside title and labels, but
  `new.sh` has never encoded origin and its own comment says so deliberately.
  Either encode it or narrow the invariant — but it is not a new regression.

AC #13's enforcement point was settled by choosing the emitter (#262). The
alternatives both put the decision back in the nine skills, which is the failure
this AC already had once. That choice stands; what the second review found is
that its *default* is fail-open and its canonical snippet omits the flag.

Not blocking, in rough priority: **#266** (insights analyst reads the
branch-local collection), **#274** (push failures reported as contention),
**#271** (bookmark false rewrite alarms), **#277** (routing argument
classification), **#268** (missing worktree containment gate), **#273**
(origin-lint cross-branch churn), **#269** (`place.sh` hygiene pass).

**#271 is now the most visible of those.** The fix pass narrowed it — an
offline run no longer rewinds the bookmark — but the alarm itself still fires on
the local tier, where no fetch happened and the "tip" is this clone's own ref.
Making offline reads actually work (#267) means that path is reached more often
than it was. It was left whole rather than half-fixed: closing it properly also
means the `place_direct_publish` half, which advances the bookmark before the
push and does not roll back on rejection.

## Gotchas for whoever resumes

- **The suite takes ~7m40s** and exceeds a single foreground command's timeout.
  Run it in the background to a log and poll:
  ```
  bash skills/meta-test/scripts/run.sh > /tmp/suite.log 2>&1 &
  until grep -q '^Ran ' /tmp/suite.log; do sleep 10; done; tail -1 /tmp/suite.log
  ```
  Do not run two suites concurrently — they contend badly (one 16s file took
  5m41s alongside another run). Tracked as its own issue.
- **Verify every security test is non-vacuous.** The technique that worked: neuter
  the guard and confirm the test goes red. The containment gate, all four race
  cases, and the doc invariants were each checked this way. Without the guards, a
  crafted tree writes `PWNED` outside the collection dir from a *read* verb.
- **Bash namerefs bite silently here.** A nameref whose own name matches the
  array it points at resolves to itself and yields an **empty array** with no
  error. It cost two debugging rounds. `place.sh` uses a per-function prefix
  convention (`_pp_`, `_rg_`, `_ps_`, `_ch_`, `_sv_`, `_ld_`); keep it. Nothing
  mechanically enforces it yet — that is a filed issue.
- **`tests/jimconf.sh` has three unavoidable deletions** against the build base
  (the exhaustive key-registry assertions: `53`→`55` twice, plus the ordered key
  list). Any config-key addition forces them. Task 13's additions-only evidence
  holds over `tests/issues.sh`, `tests/place.sh` and `tests/docsurfaces.sh`.
- **`ARCHITECTURE.md` goes through `/jim:arch`**, never a hand edit.
- **Filing here yields provisional ordinals.** The coordination remote is
  unreachable from this VM, so `new.sh` falls back to a `P-` marker and the
  developer realizes them from the host with
  `bash skills/issue/scripts/reconcile.sh --apply`. Both this session's batches
  (#255–#261 from the build, #262–#277 from the review) were reconciled that way.
  Expect the same on any issue filed in this environment.
