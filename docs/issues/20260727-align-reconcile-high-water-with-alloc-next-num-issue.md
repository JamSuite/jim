---
id: 20260727-align-reconcile-high-water-with-alloc-next-num-issue
num: 124
title: "Align reconcile high-water with alloc_next_num_issue"
status: open
priority: low
labels: [id-coordination, robustness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T11:03:17Z
updated: 2026-07-27T11:03:17Z
origin: docs/specs/platform/009-provisional-reconcile/review.md
---

## Description

## Problem

`alloc_reconcile_realize` and `alloc_next_num_issue` compute the issue
high-water from `issues.log` with different record filters, so they can disagree
on the next ordinal.

- `alloc_next_num_issue` (`skills/file/scripts/jimalloc.sh:287-292`) counts an
  `issue allocate` ordinal (`c3`) toward the high-water whenever `c3` is numeric,
  regardless of the record's full-id field.
- `alloc_reconcile_realize` (`skills/file/scripts/jimalloc.sh:349-355`) counts
  `c3` toward `max` only when the full-id (`c4`) also passes `alloc_valid_token`,
  because the `max` update sits after the `alloc_valid_token "$c4"` gate.

## Impact

With a malformed record present — numeric ordinal, boundary-invalid full-id,
e.g. `issue allocate 2 -bad 20260101 z` — a normal `allocate issue` counts
ordinal 2 while `reconcile` skips it. Reconcile can then realize a provisional
onto display ordinal 2, duplicating the malformed record's ordinal.

Bounded severity: reconcile still counts every *validly-held* ordinal, so it
never reissues a real id; ids carry no authority (platform/007 non-goal); and the
trigger requires push access to the branch-writable coordination log (the same
surface the erosion guard defends, though the guard does not catch an *appended*
malformed record). AC 8 is not violated — the realized ordinal still derives
solely from the registry high-water, just via a stricter record filter.

## Suggested fix

Count `c3` toward `max` whenever it is numeric, independent of the `c4` validity
gate — keep `existing[$c4]` keyed only on a valid `c4`, but move the `max` update
out from behind the `alloc_valid_token "$c4"` continue. This makes the two
high-water computations agree. One-line change in `alloc_reconcile_realize`, with
a fixture asserting reconcile's high-water matches `alloc_next_num_issue` over a
log carrying a malformed record.

Surfaced by the platform/009 post-build review (finding 1).
