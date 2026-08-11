---
id: 20260808-diverged-deferral-publishes-an-index-omitting-the-other-side
num: 284
title: "Diverged deferral publishes an index omitting the other side"
status: closed
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:48Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

In the `diverged` deferral case, the published commit carries the teammate's
issue file **and an index that omits it**.

## Mechanism

`INDEX.md` is regenerated over `PLACE_COLL`
(`skills/issue/scripts/place.sh:1199`, `:1208`), which was materialized from
`PLACE_WORK_TIP` — the local head. That collection never contained the
teammate's issue.

The regenerated index differs from the base snapshot, so
`place_build_commit:949-951` writes it into the tree. The tree itself is seeded
from the onto-tip, which *does* carry the teammate's file (correctly — the
merge-base is the right base, so their file is neither in `before` nor `after`
and is left alone).

Result: the destination holds an issue file that its own `INDEX.md` does not
list. Since `render.sh` parses `INDEX.md` rather than scanning, that issue is
invisible to every reader until the next write regenerates.

## Contrast

`place_regraft` handles this correctly: it skips `INDEX.md` from the graft
(`:1046`) and regenerates over the *merged* result (`:1062`). Attempt 1 in the
diverged case has no merged directory and no equivalent step.

## Proposed action

Falls out of the fix for the sibling issue on the diverged arm's missing
conflict check: if the diverged case goes through `place_regraft` on attempt 1,
it inherits the correct index handling for free.

If the two are fixed separately, the diverged arm needs to regenerate the index
over a materialization of the onto-tip with the changed set applied, not over
the work-tip collection.

## Test

`tests/place.sh:794` asserts the three issue files survive but never inspects
the published `INDEX.md`. The assertion pattern at `:884-886` (index knows both
sides) is what would have caught it.

## Resolution (2026-08-11)

Fixed in `867ec04`, as a consequence of the diverged case going through
`place_regraft` on attempt 1 — which excludes `INDEX.md` from the graft and
regenerates it over the merged result. Pinned by an index assertion added to
`case_place_deferred_mutation_survives_a_moved_destination`.
