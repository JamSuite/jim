---
id: 20260729-provide-a-recovery-path-for-a-group-that-exhausts-its-ordinal-sp
num: 137
title: "Provide a recovery path for a group that exhausts its ordinal space"
status: open
priority: low
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-29T22:21:54Z
updated: 2026-07-29T22:21:54Z
origin: docs/specs/platform/011-rename-path-correctness/plan.md
---

## Description

Surfaced while planning `platform/011` (rename-path correctness).

That plan makes an exhausted spec group a hard failure: once a group's high-water
reaches the largest ordinal the registry's bootstrap accepts, `next-id` errors
instead of returning the next value. That is the correct behavior — the
alternative was silently minting a 4-digit ordinal the seed refuses, producing a
spec directory the registry can never be rebuilt from. But it leaves a group at
the ceiling with nowhere to go: the error reports that you are stuck, not how to
get unstuck.

## What a recovery path would need to answer

- **Renumber, or widen?** Compacting a group's ordinals into the gaps below the
  ceiling reuses vacated numbers, which the never-reuse guarantee forbids.
  Widening the accepted range instead (4-digit ordinals) means the seed, the
  fold, `jimfile.sh`'s tree scan, and every existing directory name have to agree
  on the wider form.
- **What happens to the gaps?** A group reaches the ceiling by *allocation
  count*, not by having 999 live specs — permanent gaps from renames and
  abandoned work consume ordinals too. So a group can exhaust while holding far
  fewer than 999 directories, which makes "just widen it" the more likely answer
  than "compact it."
- **Is a split the real answer?** A group approaching the ceiling is arguably a
  partition smell, and splitting it is already a supported operation. That may
  make this a documentation question rather than a code one.

## Why low

No demand: the largest live group holds 24 specs, so the ceiling is roughly two
orders of magnitude away. Filed as a trend marker so the hard failure the plan
introduces has a recorded destination if it ever fires, rather than surprising
whoever hits it first.
