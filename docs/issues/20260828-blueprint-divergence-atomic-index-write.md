---
id: 20260828-blueprint-divergence-atomic-index-write
num: 410
title: "Blueprint divergence: atomic-index-write"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:55:12Z
updated: 2026-08-29T04:57:46Z
origin: "docs/specs/issue/015-epic-authoring-and-views"
---

## Description

resolved: fix the code

The invariant stands. It requires that "a failure handler never discards a
staged file that is an issue's only remaining copy". `transition.sh` does
exactly that on one path.

## The path

`skills/issue/scripts/transition.sh:442-453`:

    if [[ -n "$changes" ]]; then
      set_fields "$file" "$changes" || { ...abort...; return 1; }
    fi

    bash "$INDEX_SCRIPT" "$work" >/dev/null 2>&1 || {
      echo "error: could not regenerate the index" >&2
      [[ -n "$token" ]] && bash "$PLACE" abort "$token" >/dev/null 2>&1
      return 1
    }

By the second block `set_fields` has already succeeded — the transition is
durably written into `$work`. Under a branch placement `$work` is the
materialized handle collection, and `place.sh abort` is `rm -rf -- "$handle"`.
The completed, unpublished transition is deleted.

## Reproduced

With a repo whose `issue_placement` names a branch other than the checked-out
one, and index regeneration made to fail transiently (succeeding for the
door's materialize reindex, failing for the post-write one):

- at the moment of the failing call, the materialized collection carried
  `claimed-by` — the write had landed;
- the run reported `error: could not regenerate the index` and exited 1;
- the destination branch still read `claimed-by: ""`;
- the written transition survived nowhere on disk.

A control run with no injected failure completes normally and publishes.

## Blast radius

Branch placements only. Under the default placement `abort` on a direct handle
returns without removing anything, so the write stays in the working tree. It
also needs the failure to be transient — a persistent index failure aborts at
the door's own materialize reindex, before `set_fields` runs.

## What the rest of the group does instead

Every sibling multi-step operation takes the opposite branch on the same
"write succeeded, reindex failed" shape: it keeps the written state and flags
the stale index rather than discarding the work. `migrate.sh`'s apply path goes
further and explicitly refuses to discard a staged file whose original name has
already been overwritten.

## The fix

On the post-write reindex failure, preserve the handle and report it — the
developer can then publish or recover. Aborting is correct only for the
failures that happen *before* the record is written, which is what every other
`abort` call on this path is.

## Resolution

Fixed in `bc9631eb`.

**Not the fix as filed.** The record asks the post-write handler to preserve
the handle instead of aborting. Reading `place.sh` first showed why that handler
existed at all: `place.sh commit` regenerates the index of whatever it publishes
— `cmd_commit`'s plumbing arm and `place_direct_publish`'s checked-out arm both
do it, and only the no-placement arm returns early without one. So
`transition.sh`'s own pre-publish regeneration was **redundant on exactly the
path where it was destructive**. The call is now made only where nothing
downstream will make it: a collection named with `--dir`, or the working tree
under no placement. The destructive branch stops existing rather than being made
safe.

Measured through a counting shim: a branch-placement transition drops from
**three** full index regenerations to two, a checked-out-destination one from two
to one, and the unplaced path is unchanged at one.

**Every remaining `abort` on the mutation path is correct**, and now provably so
by position: each one either precedes the write or sits inside `set_fields`'s own
failure handler, where the tmp+mv left the previous file untouched. That is the
property `atomic-index-write` asks for, expressed structurally rather than
argued.

**Five cases pin it, and two mutations bracket it.** Restoring the destructive
handler fails four of them — including the one that asserts the written move
survives on disk, which is the data loss itself. Never regenerating fails the
other two, which is the over-correction that would leave every unplaced
collection with an index that never moves. A third mutation, dropping only the
`--dir` arm, was already caught by two pre-existing cases.

The reproduction rig is in the test file as `index_shim_scripts`: a scripts
directory of symlinks whose `index.sh` counts its invocations and refuses past a
given call. Counting is what lets a case ask *who* regenerates an index rather
than only whether it ends up regenerated; refusing past a call is the only way to
reach a failure that lands *after* a write, since a collection that cannot be
indexed at all is refused at the door before anything is written.

**What this does not fix.** On a refused publish the handle and its edits
survive, but `transition.sh` still drops the token silently, so recovering by
hand means finding `.git/jim-place/handle.*` without being told it is there. A
single message naming the token would be wrong on one of the two exits — a
conflict at rc 3 needs `begin`, reapply and commit again, not a plain re-commit —
so the reporting half of the filed fix is deliberately left for a record of its
own. In practice a transition's payload is a mechanical field change and cheap to
redo; what was unacceptable was destroying it while reporting failure.
