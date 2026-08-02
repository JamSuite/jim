---
id: 20260802-refuse-the-three-contradictions-partition-batch-still-writes
num: P-20260802-refuse-the-three-contradictions-partition-batch-still-writes
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
updated: 2026-08-02T21:35:11Z
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
