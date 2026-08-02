---
id: 20260802-fix-the-rename-replay-in-the-integrity-classifier
num: 202
title: "Fix the rename replay in the integrity classifier"
status: open
priority: medium
labels: [allocator, registry, rename]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T00:47:12Z
updated: 2026-08-02T00:47:12Z
origin: docs/specs/platform/012-registry-integrity-and-drift/review.md
---

## Description

## Description

The integrity classifier replays rename records to track which identity each
claim currently names. Four defects live in that replay. None is reachable
today — nothing in the tree emits a rename record, and the grammar is frozen
pending the rename-emission spec — but the classifier explicitly parses pushed
records, and rename emission is exactly what will make them live.

In `skills/file/scripts/jimalloc.sh`, `alloc_classify_spec` / `alloc_classify_issue`:

1. **A group rename into an occupied group silently destroys a claim.** The
   group-rename branch overwrites the destination key unconditionally, where the
   sibling spec-rename branch checks occupancy first and reports a duplicate. So
   `allocate a/001` + `allocate b/001` + `group rename a b` collapses two
   identities onto one with no finding at all — and if the tree holds the
   surviving name, the sweep reports fully clean while both ids resolve to the
   same place.
2. **A self-rename (`group rename a a`) deletes every live claim in the group.**
   Both tokens pass the boundary, the destination key is written and then the
   same key is unset, so every spec in `a` reads as missing — and catch-up would
   append a duplicate for each.
3. **A spec self-rename raises a false duplicate.** `spec rename core/001
   core/001` sees its own live claim at the destination and reports `DUP-ORD` for
   a record that duplicates nothing, then vacates the claim.
4. **Duplicate provenance can cite a record that never mentions the identity.**
   The destination inherits the *source's* record number, so a reported
   "records 1 and 3" can point at a line that names a different id, while the
   rename that actually created the collision goes unnamed.

Adjacent, and cheap: the rename-source non-coverage class fires for ids that were
never claimed (the source is recorded before the live-claim check), and the sweep
reduces those ids to a bare count while `uncovered-groups` prints names.

## Proposed action

Take these with the rename-emission work rather than before it — the fixtures
want real emitted records, and the semantics of a rename onto an occupied
ordinal should be decided once, for the emitter and the classifier together.
Fixture each shape; none has a test today.

## Provenance

Surfaced by the post-build review of the registry-integrity spec
(`docs/specs/platform/012-registry-integrity-and-drift/review.md`, Finding 16 /
the classifier investigation), which traced each shape line by line and confirmed
associative-array iteration order is *not* load-bearing in that replay.
