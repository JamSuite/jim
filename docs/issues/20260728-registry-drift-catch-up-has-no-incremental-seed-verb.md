---
id: 20260728-registry-drift-catch-up-has-no-incremental-seed-verb
num: 130
title: "Registry drift catch-up has no incremental seed verb"
status: open
priority: low
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T21:39:26Z
updated: 2026-07-28T21:39:26Z
origin: docs/specs/platform/008-registry-seed/spec.md
---

## Description

## Description

When issues/specs are added via the pre-allocator `next-num`/`next-id` path
after a one-time `seed`, the registry high-water falls behind the collection and
the next coordinated `allocate` collides. There is no incremental "record these
existing ids" verb:

- `seed` **refuses a non-empty log** — `alloc_seed_publish_builder` writes a kind
  only when its log is still empty at the tip, so `seed --apply` against a
  populated registry reports "already seeded" and no-ops.
- `reconcile` only fires on a remote unreachable→reachable transition; it no-ops
  on a repo whose coordination point is already reachable.

## The drop-and-reseed escape hatch does not actually work

A "full drop-and-re-seed" is often cited as the realign path, but it cannot
realign `origin`: `alloc_coord_remote` selects the origin tier whenever an
`origin` remote *exists*, so dropping only the local `jim/registry` ref changes
nothing — `seed --apply` still reads origin's non-empty tip and refuses. And the
origin CAS is a non-fast-forward rejection, so a fresh root-commit seed cannot
replace a populated origin branch without a force-delete of the shared branch
(destroying append history and restamping every date).

## What actually works today (and what the verb should automate)

The 2026-07-28 host realignment was done by **hand-appending** the missing
records to the existing logs and CAS-pushing one commit atop origin's tip — a
plain fast-forward, append-only, so the erosion-prefix invariant is preserved and
no force is needed. This is safe precisely because both high-water functions
(`alloc_next_id_spec`, `alloc_next_num_issue`) scan for the max ordinal
order-independently, so appending at the log tail is correct.

Propose a `seed --catch-up` (or equivalent) that appends the records missing
from a **non-empty** log — derived from the collection exactly as `seed` derives
them — under the same CAS/erosion discipline as an allocation, instead of
requiring manual git plumbing.

Note: `tests/jimalloc.sh` is a separate platform-territory gap, already tracked
as #120 / #125 (map-tier).
