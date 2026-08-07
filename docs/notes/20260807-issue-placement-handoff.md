# Issue placement (`issue/011`) — handoff

*Written 2026-08-07 at the end of the build + review cycle. Branch
`feat/id-coordination`. Everything described here is committed; the working tree
is clean.*

## Status at a glance

| | |
| :--- | :--- |
| Spec | `docs/specs/issue/011-issue-placement/` — `status: approved` |
| Plan | 14/14 tasks `[x]`, `status: approved` — **deliberately not `complete`** |
| Build | shipped, 1262 tests green (7m36s) |
| Review | **`major-drift`**, 25 findings, `review.md` committed |
| Blueprint | `issue` group refreshed; contract graph reconciled (23 edges, 19 faces, no findings) |
| Follow-ons | 16 issues filed (#262–#277), 15 open, #275 closed |
| Build base | `f024b9e` (also in `.git/jim-build-base-011`) |
| Session range | `f024b9e..c4b5940`, 24 commits |

**The plan is not marked complete on purpose.** Four defects reproduced during
review corrupt or lose user data on ordinary input. Recommendation: fix those
four, re-review, then close.

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

- **AC #13 is violated, and it is a plan defect.** The auto-file scrub degrade
  is stated in `skills/issue/SKILL.md` §7a and executed by **none** of the nine
  surfacing skills — each has its own local `IF auto_issue_file == "true"` branch,
  and §7a is not loaded when e.g. `/jim:build` runs. A pointer inherits a rule to
  consult, not a branch to take. DD 9's "one edit, eight inheritors" reasoning
  does not hold for behavior.
- **`agents/issue-analyst.md` was never updated** — it still reads
  `docs/issues/*.md` literally, so under placement it takes its roster from the
  destination and its bodies from the branch-local collection.
- **One invariant regression**: `staleness-gated-reads`. `place_materialize`
  `touch`es the index so the mtime gate always reports fresh, which is sound only
  while every write goes through the emitter. Resolved **fix-code** at the
  blueprint fork — the invariant's wording stands, the code changes.

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

1. **Fix the four criticals.** The first two are independent; the third shares a
   function with the second, so pair them.
   - **#270** placeholder substitution corrupts titles and durable ids
   - **#265** deferred placement mutation discarded on reconnect
   - **#264** `cmd_commit` direct arm publishes without re-verification
   - **#267** offline placed read serves an empty collection
2. **Fix the invariant regression** — **#276**, regenerate the index on placed
   reads instead of touching it. The blueprint fork already committed to this
   resolution, so leaving it undone leaves a knowingly-violated invariant.
3. **Fix the test suite's own defects before adding tests** — **#272**. One case
   passes even if `place.sh` is deleted; three more pass for reasons other than
   what they name. A test that cannot fail is worse than no test because it
   reports coverage.
4. **Decide AC #13's enforcement point** — **#262**. This is a design question,
   not a bug fix: the issue lays out three shapes. My preference is a `place.sh`
   verb the skills consult, since the config gate already lives there.
5. **Re-run `/jim:review`** once 1–3 land, then mark the plan `complete`.

Not blocking, in rough priority: **#266** (insights analyst reads the
branch-local collection), **#274** (push failures reported as contention),
**#271** (bookmark false rewrite alarms), **#277** (routing argument
classification), **#268** (missing worktree containment gate), **#273**
(origin-lint cross-branch churn), **#269** (`place.sh` hygiene pass).

Closed: **#275**, the permission-conventions record — resolved in the same pass
that filed it.

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
