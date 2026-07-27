---
id: 20260727-align-seed-landing-with-the-allocation-cas-path
num: 122
title: "Align seed landing with the allocation CAS path"
status: open
priority: low
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T05:34:22Z
updated: 2026-07-27T05:34:22Z
origin: docs/specs/platform/008-registry-seed/review.md
---

## Description

## Description

Surfaced by the `platform/008` post-build review (review.md Findings 2 and 3) —
two low-severity parity gaps between the seed's landing path
(`alloc_seed_land`, `skills/file/scripts/jimalloc.sh:1021-1081`) and the
allocation CAS (`alloc_cas_append`):

- **Missing in-loop erosion re-check.** `alloc_cas_append` runs
  `alloc_check_erosion` inside its retry loop to hard-fail on a truncated or
  rewritten coordination history; `alloc_seed_land` has no equivalent before
  writing. Narrow in practice (seed only writes a kind whose tip-log is empty and
  reconstructs the full state from the tree, and re-seeding a populated kind is
  already refused), but a literal reading of AC 8's "no path with weaker
  guarantees" flags it.
- **Second registry-writing code path.** `alloc_seed_land` inlines the push /
  `update-ref` CAS rather than reusing `alloc_origin_cas` / `alloc_local_cas`
  (which take a single logfile + piped content), because the seed needs a
  two-blob commit (`alloc_seed_commit`). The mechanics are byte-equivalent, so
  guarantees are identical, but it is a second path kept in sync by convention.

## Fix

- Consider adding the same in-loop erosion re-check to `alloc_seed_land`.
- Consider factoring the shared land step (tier select + CAS + baseline arming)
  so allocation and seed share one implementation.

Low priority — no current correctness gap; consistency/maintainability.
