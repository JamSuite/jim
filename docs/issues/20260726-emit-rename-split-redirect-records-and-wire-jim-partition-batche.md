---
id: 20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche
num: 113
title: "Emit rename/split redirect records and wire /jim:partition batches"
status: open
priority: high
labels: [id-coordination, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:57Z
updated: 2026-07-26T22:42:00Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`platform/007` defines the rename and group-rename record grammar and forward-replay resolution but **emits allocate records only**. This follow-on makes `/jim:partition`, `rename`, and `split` emit the redirect records (Shape 1: a renumber is a new allocation plus a redirect tombstone, never a mutation), so that trailers frozen in git history stay dereferenceable forever.

Scope:
- A split/partition mass-move becomes one registry commit = one push = one CAS (batch atomicity; no partial renumbering ever visible).
- Group renames are one `group rename` record; resolution applies the group redirect before the ordinal lookup.
- A pre-edit registry fetch surfaces the concurrent edit-vs-rename warning before the git-level rename/modify conflict lands at merge.
- Fold in G6: every ID consumer (skills, humans, plain grep) must become resolution-aware, or jim opportunistically normalizes stale citations in tree content when it touches a file anyway.

Follow-on to `platform/007` (foundation); this is the `blueprint`-group consumer slice.

## Review notes (from the platform/007 build review)

Two latent edges in `platform/007`'s **frozen** resolution / next-id semantics
surfaced during the post-build review. Neither is reachable in the foundation
build (it emits allocate records only and has no `resolve` consumer yet), but
this follow-on is the first to emit rename records — so both must be closed
here, **before** the first rename/group-rename record lands, or a citation
mis-resolves and a vacated ordinal can be reclaimed. Add fixtures for each.

- **Resolution is not anchored for reuse-via-rename-in.** `alloc_resolve_spec` /
  `alloc_resolve_issue` set the forward-replay anchor only on an `allocate`
  match (`skills/file/scripts/jimalloc.sh:169` / `:222`), not when the queried
  id is a rename *destination* (`:172` / `:225`). So a name renamed away and
  later reused by renaming a *different* spec onto the freed name resolves to
  the *old* referent, not the current one — the "mis-resolve to the wrong
  referent" AC 5 forbids. Reuse-via-*allocate* is already anchored correctly; do
  the same for rename-in: also fix the anchor on the last rename whose
  destination equals the queried id. Add fixture cases for reuse-via-rename-in
  (spec and issue).

- **next-id counts rename destinations but not sources.** The high-water
  `next-id` / `next-num` fold in allocate ids and rename destinations, not
  rename sources (`skills/file/scripts/jimalloc.sh:247-266`). The permanent-gap
  guarantee (AC 3) therefore rests on the invariant that every rename source has
  its own prior `allocate` record. When this spec begins emitting renames, either
  count rename sources in the high-water fold or otherwise guarantee that
  invariant, and add a fixture seeding a same-group rename source whose vacated
  ordinal must never be reclaimed.

See `docs/specs/platform/007-id-coordination-allocator/review.md` (Findings 1
and 2) for the full trace.
