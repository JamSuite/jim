---
id: 20260731-close-the-remaining-edges-of-the-ordinal-identity-invariant
num: 181
title: "Close the remaining edges of the ordinal identity invariant"
status: open
priority: low
labels: [file, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:24Z
updated: 2026-07-31T12:39:24Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

Two places where the "two spellings of one ordinal are one ordinal" invariant
stops short.

**Width asymmetry.** `spec_ordinal_holder` skips a sibling whose leading token
exceeds 15 digits (`skills/file/scripts/jimfile.sh:529` — deliberate, documented,
fixtured), while `cmd_next_id` strips leading zeros and counts *any* width
(`:330-338`). A 19-digit-padded `…018-wide` therefore floors `next-id` to `019`
while reading as "018 is free" to the occupancy gate, so a rename onto 018 is
permitted alongside the padded twin.

**The partition move primitives are unguarded.** `jimledger.sh move-spec-dir`
(`:553-620`) and `rename-tracked` (`:275-320`) refuse only an exactly-existing
destination and never consult `spec_ordinal_holder`. Split and merge renumbering
can therefore still land a padding-variant twin.

## Assessment

The first is hand-made-only and pathological. The second is the more meaningful
boundary: the claim that the occupancy halt is *structural rather than
discipline* holds for the spec-creation and realize paths, and stops at the
partition operations, which rename spec directories through a different pair of
primitives.

## Fix

Agree one width policy across the predicate and `next-id`; and either route the
partition primitives through the shared predicate or record explicitly that the
guarantee is scoped to the two paths that do enforce it.

Finding 11 and Finding 12 of
`docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
