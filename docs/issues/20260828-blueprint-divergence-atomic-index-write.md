---
id: 20260828-blueprint-divergence-atomic-index-write
num: 410
title: "Blueprint divergence: atomic-index-write"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:55:12Z
updated: 2026-08-28T11:55:12Z
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
