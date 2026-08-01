---
id: 20260728-registry-drift-catch-up-has-no-incremental-seed-verb
num: 130
title: "Registry drift catch-up has no incremental seed verb"
status: open
priority: high
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T21:39:26Z
updated: 2026-08-01T19:43:01Z
origin: docs/specs/platform/008-registry-seed/spec.md
---

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

## Scoping notes (2026-08-01)

**Priority raised low → high.** Three independent demonstrations are on
record: the 2026-07-28 hand-append above; the `platform/011` / `sdlc/017`
drift repaired by hand on 2026-07-31
([[20260730-align-the-registry-with-tree-scan-era-spec-ordinals]]); and seed's refusal
making every future instance a manual edit of a shared branch. This verb is
what stands between the registry and a reissued id; nothing else does.

- **The publish machinery now exists — the verb reduces to a builder.** Since
  filing, seed and both reconcilers were consolidated onto `alloc_publish`
  (`skills/file/scripts/jimalloc.sh:1615`): in-loop erosion re-check on both
  logs, tier CAS, bounded retry, baseline arming. A catch-up verb derives
  records exactly as seed does and appends the missing difference; the only
  thing it bypasses is `alloc_seed_publish_builder`'s empty-log precondition
  (`:1695`).
- **Four semantics the spec must settle:** the spec-record date stamp (seed
  stamps *today*; the 2026-07-31 manual repair carried each spec's own
  issuance date; advisory either way per `platform/007` AC 4) · the
  provenance marker (`jim-seed` vs a distinct catch-up marker — a repair
  distinguishable from the bootstrap is free forensics) · the rule for a tree
  group with no derivable specs (seed emits `group allocate` only alongside
  ≥1 valid spec row) · conflict semantics when tree and registry disagree at
  one ordinal (halt-and-name per the seed's discipline, vs
  report-and-continue).
- **#121 rides along**
  ([[20260727-normalize-seed-reserved-slot-skip-and-spec-ordinal-magnitude]]):
  the seed derivation this verb reuses still skips the reserved slot with a
  literal `"000"` (`jimalloc.sh:817`), so a `0-foo` dir still derives a
  `<group>/000` record. Fix that first or inherit it knowingly.
