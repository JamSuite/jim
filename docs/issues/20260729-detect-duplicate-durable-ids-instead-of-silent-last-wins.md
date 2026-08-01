---
id: 20260729-detect-duplicate-durable-ids-instead-of-silent-last-wins
num: 136
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
updated: 2026-08-01T19:43:01Z
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

## Wider than filed (2026-08-01)

The last-wins shape is at three read-path sites, not one — the seed halts on
both duplicate classes, and the read path mirrors neither:

- `alloc_resolve_issue` — the case above
  (`skills/file/scripts/jimalloc.sh:288-295`).
- `alloc_resolve_spec` — two `spec allocate` records naming one id: the later
  record silently wins the replay anchor (`:244-251`), so a duplicate spec
  ordinal is likewise undetected.
- `alloc_reconcile_realize` — the `existing[]` durable-id map takes the last
  duplicate, so a realize can report `have` against the wrong ordinal
  (`:611-618`).

Spec E should scope detection over all three or record why the spec-side
siblings stay out.
