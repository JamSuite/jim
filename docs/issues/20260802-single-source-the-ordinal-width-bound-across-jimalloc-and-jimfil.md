---
id: 20260802-single-source-the-ordinal-width-bound-across-jimalloc-and-jimfil
num: P-20260802-single-source-the-ordinal-width-bound-across-jimalloc-and-jimfil
title: "Single-source the ordinal width bound across jimalloc and jimfile"
status: open
priority: medium
labels: [id-coordination, sync-discipline]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T20:57:29Z
updated: 2026-08-02T20:57:29Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/plan.md
---

## Description

## Description

The maximum ordinal width is decided in two places that agree only by
convention. `jimalloc.sh` reads a named constant (`ALLOC_MAX_ORD_DIGITS = 15`);
`jimfile.sh`'s path, rename, and occupancy predicates each inline the literal
`{3,15}` in their own regex. No test asserts the two agree.

`ARCHITECTURE.md` already names this as the one place in the ordinal machinery
where a divergence would not be caught structurally. Two things make it worth
closing now rather than leaving as a documented wart:

1. **The bound became load-bearing.** Before per-side canonicalization, an
   ordinal that failed the width gate dropped its whole rename record — the two
   sides shared one fate, so a disagreement between the files was mostly a
   question of which malformed record got skipped. Now the bound decides, per
   side, whether a destination's establishing claim survives. A `jimfile.sh`
   that admitted a width `jimalloc.sh` rejects would let a directory exist on an
   ordinal the registry treats as unrepresentable — registry-vs-tree drift the
   sweep would report but neither file would have prevented.

2. **The mechanism now exists and is proven.** The provisional-identity grammar
   had the same shape — three hand-synced copies that had already drifted — and
   it was closed with byte-identical bodies under a `SYNC:` comment plus a
   `tests/jimfile.sh` case asserting the copies agree, following the earlier
   `is_valid_id` precedent. The same discipline applies directly here.

## Proposed action

Either extract the bound so both files read one value, or — where a regex
literal is genuinely needed inside a `[[ =~ ]]` gate — assert agreement
mechanically: a test that reads the constant from `jimalloc.sh` and the width
from each `jimfile.sh` predicate and fails when they diverge. The extraction is
preferable if it does not cost a subprocess on a hot path; the fixture is the
fallback that at least makes a divergence loud.

Surfaced during the rename/redirect record emission build, which touched every
reader of that bound but deliberately left this seam alone as out of scope.
