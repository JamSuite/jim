---
id: 20260729-detect-duplicate-durable-ids-instead-of-silent-last-wins
num: P-20260729-detect-duplicate-durable-ids-instead-of-silent-last-wins
title: "Detect duplicate durable ids instead of silent last-wins"
status: open
priority: low
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-29T21:02:33Z
updated: 2026-07-29T21:02:33Z
origin: docs/specs/platform/011-rename-path-correctness/spec.md
---

## Description

Surfaced while scoping `platform/011` (rename-path correctness).

`alloc_resolve_issue` maps a queried durable id to its display ordinal by
scanning `issue allocate` records and assigning on every match with no early
exit, so when two records share a durable id the mapping silently resolves to
whichever appears last in the log.

## Why it is narrow

Three things make a shared durable id hard to produce today:

- the allocator's G9 collision guard suffixes a computed durable id that already
  exists in the registry, so a normal allocation never mints a duplicate;
- `platform/008`'s seed halts and names the offenders on a duplicate durable id
  rather than seeding it;
- ids carry no authority (`platform/007` non-goal), so a mis-mapped id is a
  wrong referent, never a capability.

So reaching it needs a hand-appended or otherwise crafted log on the
push-writable coordination branch — the same surface the erosion guard defends,
which does not catch an appended-but-well-formed duplicate.

## Fix

Make a duplicate durable id a detected, reported condition on the read path
rather than silent last-wins, consistent with how the seed already treats it.
Add a fixture seeding two allocate records that share a durable id.

Note the read path is deliberately degrade-and-skip for *malformed* records; this
is the different case of two individually valid records that cannot both be true.
