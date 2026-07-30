---
id: 20260730-the-shared-spec-fold-resolves-group-aliases-twice
num: 159
title: "The shared spec fold resolves group aliases twice"
status: open
priority: high
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:07Z
updated: 2026-07-30T19:35:07Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

A caller resolves a group through the alias map and then passes the **resolved**
name to `alloc_fold_max_spec`, which resolves it **again** — walking one hop too
far and folding a retired namespace. The ordinal it reports is then already
taken, and `--apply` publishes the duplicate record durably.

## Reproduction

With a log carrying `spec allocate side/001 …`, then
`group rename core legacy`, then `group rename side core`, the alias map is
`side→core, core→legacy`:

```
fold(side) = 1        fold(core) = 0
alloc_next_id_spec side --follow-redirect      → core/001
alloc_reconcile_realize_spec side/P-…          → core/001
alloc_resolve_spec side/001                    → core/001   ← already taken
```

`--apply` publishes the duplicate record **before** the tree-side group-mismatch
halt fires, so the registry double-issues durably. Reproduced end to end during
the review, not inferred.

## This predates `sdlc/017`

`alloc_next_id_spec` has the identical defect; the new realize function inherits
it precisely *because* it reuses the shared fold — which was the right design
decision. The bug is in the fold's contract, not in either caller's choice to
use it.

No test exercises a reused group name at the fold level. The existing alias
tests cover chains and the A→B/B→A cycle — the one shape where double
resolution happens to be harmless.

## Fix

Resolve exactly once. Either:

- have `alloc_fold_max_spec` accept a pre-resolved group and skip its own
  resolution, or
- have callers pass the raw group and let the fold own resolution.

Pick one and make the contract explicit in the docstring, since the whole defect
is two layers each believing the other did not resolve.

Fixture a reused-group-name log against **both** `next-id` and realize — the
shared fold means one fixture cannot stand in for the other.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
