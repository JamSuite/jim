---
id: 20260805-pin-the-lift-s-reserved-ordinal-refusal-on-its-source-side
num: 226
title: "Pin the lift's reserved-ordinal refusal on its source side"
status: closed
priority: high
labels: [000-blueprint, verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T02:19:11Z
updated: 2026-08-05T10:21:33Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

`alloc_lift_state`'s reserved-ordinal gate refuses a zero ordinal on **three**
branches — spec source, spec destination, and realize destination
(`jimalloc.sh:3749-3752`). Its comment says so explicitly:

> The reserved blueprint slot is never a writer's operand … so a row naming one
> **on any ordinal side** is refused before it is judged.

The fixture asserts that claim and does not test it.
`tests/jimalloc.sh:3774` exercises two rows:

```
spec     zed/001          -> zed/000    (destination)
realize  zed/P-20260725-a -> zed/000    (destination)
```

Both name the reserved ordinal as a **destination**. The spec-**source** branch —
`alloc_is_reserved_ord "${src##*/}"` — has no case anywhere in the suite.

It is load-bearing, not decorative. Over a log holding
`spec allocate zed/001 alpha 20260726 kai`, the row
`spec⇥zed/000⇥zed/001⇥20260725` reaches the spec arm with the destination
established (`live[zed/001]`) and the source unclaimed (`live[zed/000]` empty), so
it falls through to `emit` and `alloc_encode_rename_spec zed/000 zed/001` is
appended. Deleting that half of the disjunction leaves the whole suite green.

This is the inverse of the `ordinal-single-source` gap: there the recorded text
overclaims what the guard catches; here the code is correct and the fixture does
not pin it. Both land on the same closing clause of their invariant — "each
refusal pinned by its own fixture" — which is currently false for this branch.

## Proposed action

Add a case exercising the reserved ordinal on the lift's spec **source** side,
asserting `refused:reserved-ordinal` and that no rename record is appended. Verify
it discriminates by deleting the source half of the `:3749` disjunction and
confirming the case goes red.

While there: `refused:destination-conflict` is emitted from three sites in
`alloc_lift_state` and asserted nowhere in the suite. That is tracked separately,
but the two are one afternoon's work in the same file.

## Provenance

`/jim:verify --since 175047c platform` — `blueprint-slot-reserved` (high), judged
`violated` on clause C4, `channel=in-change`. Clauses C1–C3 (one zero-valued
predicate at every consultation site; high-water arithmetic that cannot yield
zero; all nine registry write paths gated as worded) hold. Resolved **fix** at the
blueprint update's violation fork.

## Resolution (2026-08-05)

Fixed as proposed. A case exercises the reserved ordinal on the lift's spec
**source** side and asserts both the refusal and that nothing is emitted.
Verified by deleting the source half of the disjunction, exactly as the issue
asked: the case goes red.

The adjacent gap the issue mentioned rode the same pass —
`refused:destination-conflict` now has cases on all three arms, and on both
directions of the group arm's check.
