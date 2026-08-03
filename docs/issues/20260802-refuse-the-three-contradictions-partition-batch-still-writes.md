---
id: 20260802-refuse-the-three-contradictions-partition-batch-still-writes
num: 209
title: "Refuse the three contradictions partition-batch still writes"
status: open
priority: high
labels: [id-coordination, registry, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:11Z
updated: 2026-08-03T08:35:15Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

`jimalloc.sh partition-batch` accepts three pair shapes that are contradictions.
All three reproduced.

**1. A vacated ordinal can be re-minted.** The corroboration set
(`alloc_live_claim_set:3196-3201`) holds only `LIVE` rows from
`alloc_spec_replay`; `SRC` rows — ordinals a rename moved away from — are
dropped. So the emitter cannot see that an ordinal was ever spent:

```
allocate jim/001, jim/002
partition-batch:  jim/002 -> core/002      # vacates jim/002
partition-batch:  other/001 -> jim/002     # accepted, rc 0
resolve spec jim/002  ->  jim/002          # the NEW spec, silently
```

A frozen citation now dereferences to a different spec than the one it was
written about. This contradicts the invariant both `alloc_fold_max_spec:789-793`
and `alloc_next_id_spec:881-883` state in their own headers ("an ordinal the
group held and can never reissue" / "a vacated ordinal is a permanent gap").
`partition-batch` is the only writer that bypasses the high-water floor
entirely. Reachable through the split protocol, which densifies fresh children
to `001..N` — a child group name that was previously retired re-mints its old
ordinals.

**2. The reserved `000` slot is accepted as a destination.**
`alloc_canon_specid` admits `grp/000` and the builder never calls
`alloc_is_reserved_ord`. `zed/001 -> zed/000` is written, then reported forever
as `RESERVED` drift by the integrity classifier. Every other writer is
structurally immune (allocate and reconcile go through `next_id`; the lift
requires an established destination).

**3. Group mode never checks the destination's redirect.**
`alloc_partition_group_publish_builder:3286` checks whether `<old>` was renamed
away but not `<new>`:

```
partition-batch group ui surface     # ui -> surface
partition-batch group dashboard ui   # accepted, rc 0
resolve dashboard/001 -> ui/001
resolve ui/001        -> surface/001    # non-idempotent
```

The spec-mode builder guards precisely this on its destination at `:3251`.

## Proposed action

- Fold `SRC` rows into the corroboration set (or add a separate spent-ordinal
  check) so a vacated destination is refused by name.
- Refuse a reserved-ordinal destination through `alloc_is_reserved_ord`.
- Apply the destination-redirect check in group mode, mirroring `:3251`.

Each is a small condition in a builder that already refuses five other shapes by
name. Note AC 5 names "occupied destination, already-vacated **source**" — the
vacated *destination* case falls outside its letter, which is why it shipped;
the never-reuse invariant is what it breaches.

Surfaced by the post-build review of blueprint/025 (findings 4, 5, 6).

## The reserved-slot contradiction compounds into the lift (2026-08-03)

A `/jim:verify` judge over the platform territory reached shape 2 independently
and found it does not stop at `partition-batch`. Three additions.

**1. `lift` is safe only by side-effect.** `alloc_lift_publish_builder` carries no
reserved predicate. A `000` destination is refused today only because
`refused:destination-not-established` fires first — the slot is never claimed, so
nothing establishes it. The moment `partition-batch` mints `<group>/000`, that
incidental guard stops holding and `lift` accepts renames naming it. The two
defects are filed separately; they are one chain.

**2. `pair-events` normalizes `000` and hands it over.** `jimledger.sh:691`'s
`isord` admits three-digit `000`, so a ledger pair naming `<group>/000` passes the
producing side's gate and reaches the lift as a well-formed row. The interface is
fail-closed on charset and width, and open on the reservation.

**3. Three more writers admit the slot**, none of them the emitter this issue is
about: `mv-spec-id` (`jimfile.sh:584`) can rename a spec dir onto `000-<slug>`;
`move-spec-dir`'s `dst_shape` (`jimledger.sh:587`) admits `000-…`;
`rename-tracked`'s new-basename gate (`jimledger.sh:289`) admits `000-blueprint`.
Each is guarded only by the ordinal-occupancy check, which passes in any group
that does not yet hold a `000-*` directory.

The reservation is genuinely enforced on the derivation and reporting paths — one
predicate (`alloc_is_reserved_ord`) drives the seed, the classifier, the sweep and
catch-up, and normal allocator arithmetic can never yield `000`. It is the write
paths that are open, and the only zero-ordinal write guard anywhere is
`jimpartition.sh:1486`'s `10#$start < 1` in `merge-map` — a caller, not the
boundary.

**No test asserts a reserved-slot refusal** in `partition-batch`, `lift`,
`path spec`, or `mv-spec-id`. Whichever way this lands, the fixture set is the
deliverable: the reservation is currently a property of arithmetic rather than of
a gate, which is why it survived every read-path check.

Related: [[20260801-refuse-the-reserved-slot-in-the-generic-spec-path-composer]]
covers the `path spec` composer half.

## The blueprint was weakened to match this defect — closing must reverse that

On 2026-08-03 the `platform` blueprint's `blueprint-slot-reserved` invariant was
**deliberately weakened** so it would stop claiming a reservation the write paths
do not enforce. That fold is a waypoint, not a destination.

**Closing this issue is not complete until the invariant is restored to at least
its pre-fold strength through `/jim:blueprint`** — never by hand. Refusing the
reserved slot at every writer is what earns the original claim back.

The pre-fold text, recorded verbatim so the restoration target needs no
archaeology:

> The `000-blueprint` slot is reserved (sorts ahead of `001`, parses to id `0`,
> ignored by `next-id`) and is resolved only via `jimfile.sh path blueprint
> <group>`

Restoring it as-is would be a small regression of its own: `ignored by next-id`
names a mechanism the tree-scan retirement removed. The restored claim should
say the reservation is enforced at every writer and every composer, name the one
predicate that decides it, and drop the retired-mechanism clause — stronger than
the original, and true for a different reason than the original was.

What must disappear from the current folded text on close: the whole
"enforced on the derivation and reporting paths … **not** enforced on the write
paths … protected by arithmetic rather than by a gate" admission.

The sibling fold on `ordinal-single-source` carries the same obligation under
[[20260802-single-source-the-ordinal-width-bound-across-jimalloc-and-jimfil]];
both were weakened in one pass and both must come back.
