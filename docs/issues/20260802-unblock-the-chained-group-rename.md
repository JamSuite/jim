---
id: 20260802-unblock-the-chained-group-rename
num: 213
title: "Unblock the chained group rename"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T21:35:11Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

A group renamed once cannot be renamed again. Reproduced:

```
allocate spec dashboard "alpha"
partition-batch group dashboard ui      -> rc 0
partition-batch group ui surface        -> rc 1
   error: partition-batch refuses 'ui' — the registry holds no record for it
```

`alloc_partition_group_publish_builder:3291` gates on
`alloc_group_has_records "$old"`, and that predicate (`:2620-2644`) recognises a
group by three things only: its own `group allocate` record, a `spec allocate`
under it, or a **spec**-rename source (`:2639` filters on `rk == spec`). It does
not recognise a group established solely as a **group-rename destination** — and
the rename path writes no `group allocate` for the new name, by design.

So after `dashboard → ui`, the registry knows `ui/001` is live but does not
consider `ui` a group it holds. The block persists until some other verb happens
to allocate into `ui`.

## Why it matters

This blocks the Close documented at `skills/partition/SKILL.md:328` for any
group whose name came from a prior rename — not an exotic shape in a system
whose whole premise is that groups get renamed, split, and merged.

Note the polarity difference at the other new call site: `alloc_lift_state:3489`
applies the same predicate to the **destination**, which is its designed sense.
Applying it to the **source** is what exposes the blind spot.

## Proposed action

Either teach `alloc_group_has_records` to count a group-rename destination as
coverage, or gate group-mode's source on live-claim presence under that name
instead (`live[$old/*]` non-empty, or the alias map naming it). The first is
probably right — a group the registry has recorded a rename *into* is plainly a
group it holds — but it also widens what "covered" means for the sweep's
`uncovered-groups` line, so the change wants a fixture on both surfaces.

None of the four group-mode tests renames twice in sequence.

Surfaced by the post-build review of blueprint/025 (finding 3).

## Resolution (2026-08-05)

`alloc_group_has_records` counts a group-rename destination as coverage, so a
group renamed once can be renamed again. Pinned on both surfaces — the emitter's
source gate and the sweep's `uncovered-groups` report.

Verified by reproducing the defect on a true `a21f55d^` checkout and then again
under single-hunk isolation, so the unblock is attributable to this hunk alone
rather than to a later commit in the same range. The chain is correct, not merely
unblocked: records form a real chain and a spec issued under the original name
resolves through it. Depth is unbounded — `a→b→c→d→e` all succeed — not merely
depth 2. The widening does not make the source gate vacuous (a never-seen name
still refuses) and does not open a new blindness class: a mid-chain waypoint was
already silent through the group-allocate arm, so the change makes coverage
consistent rather than looser. Both fixtures shown red without the fix.

Residual, tracked separately: the same commit widened the function's `read`
without extending its `local` list, and left the header describing two coverage
arms where the body now has four.
