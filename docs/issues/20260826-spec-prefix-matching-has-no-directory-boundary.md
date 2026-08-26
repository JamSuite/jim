---
id: 20260826-spec-prefix-matching-has-no-directory-boundary
num: P-20260826-spec-prefix-matching-has-no-directory-boundary
title: "Spec prefix matching has no directory boundary"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, filters]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:35:23Z
updated: 2026-08-26T02:35:23Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`prefix_axis` compares an origin against a composed prefix with a raw string
test — nothing requires the byte after the matched prefix to be a separator. So
`--spec issue/011` would also match an origin under `issue/0110-something`.

## Why it does not bite today

Two invariants make the collision unreachable, and both live in another group:

1. The allocator refuses a duplicate spec ordinal within a group, so two spec
   directories can never share one ordinal.
2. Ordinals are formatted `%03d` — a *minimum*-width format. Values 0–999 print
   as exactly three digits and values ≥1000 are never zero-padded, so a
   three-digit ordinal can never be a literal prefix of a longer one in the same
   group.

## Why it is still worth recording

Neither invariant is referenced where the comparison happens, and neither is
this group's to keep. The correctness of a read view rests on a formatting
choice in `jimalloc.sh` that nothing connects to it. A collection that
accumulates origins captured by hand rather than through the allocator, or a
group whose padding convention changes, silently loses the guarantee.

The acceptance criterion also *wants* the loose reading — "naming a spec's group
and ordinal reaches it without naming the rest of its directory" requires a bare
prefix match. So this is not a bug to fix by tightening; it is a dependency to
state.

## Fix shape

Either state the coupling at `prefix_axis` — a sentence naming the two allocator
invariants the loose match relies on — or require the byte after the prefix to
be `/`, `-`, or end-of-string, which preserves the criterion's ordinal case
while closing the sibling collision. The first is cheaper and matches how this
codebase handles cross-group couplings elsewhere; the second is stronger.

No test currently exercises a sibling-ordinal collision in either direction.
