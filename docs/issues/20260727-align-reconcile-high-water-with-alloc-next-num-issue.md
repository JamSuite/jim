---
id: 20260727-align-reconcile-high-water-with-alloc-next-num-issue
num: 124
title: "Align reconcile high-water with alloc_next_num_issue"
status: closed
priority: low
labels: [id-coordination, robustness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T11:03:17Z
updated: 2026-07-30T02:14:41Z
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

## Resolution (2026-07-30)

Fixed by `platform/011` (rename-path correctness), where this defect was carried
as **D4** — one of four rename-path defects that had to close before any rename
record is emitted. Shipped in `576527a`, 832/832 suite green.

**Resolved more structurally than the suggested fix proposed.** The suggestion
was to move the `max` update out from behind the `alloc_valid_token "$c4"`
continue — a correct one-line change. What landed instead extracts the
computation: `alloc_reconcile_realize` now takes its high-water from a shared
`alloc_fold_max_issue` that `alloc_next_num_issue` also calls, so the two cannot
disagree by construction rather than by two edited filters happening to match.

That choice came from research finding the fold in **three** functions, not two —
`alloc_reconcile_realize`, `alloc_next_num_issue`, and `alloc_next_id_spec`, none
of which counted rename sources. Fixing this divergence by editing filters would
have meant six coordinated edits held in agreement by convention, which is the
failure mode this issue *is*. Reconcile keeps a separate second pass for its
already-realized `existing[]` map, so the two gates stay distinct: any numeric
ordinal counts toward the high-water, while only a boundary-valid durable id
becomes an identity a pending marker can match.

**Regression guard:** `case_jimalloc_reconcile_high_water_parity`
(`tests/jimalloc.sh`). It asserts the two values are *equal* rather than
asserting a constant, so it cannot pass by coincidence if both paths drift
together. Over this issue's own reproduction shape — a malformed record at
ordinal 9 alongside a valid one at 2 — allocation and reconcile answered 10 and 3
before the fix and both answer 10 after.

**Verified on live data.** The subsequent host-side `/jim:issue reconcile --apply`
realized 8 pending provisional issues onto ordinals 135–142 with no gap and no
collision, against a registry whose high-water was 134 — the parity property
holding in production, not only in the fixture.
