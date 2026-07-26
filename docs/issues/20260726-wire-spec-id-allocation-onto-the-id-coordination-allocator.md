---
id: 20260726-wire-spec-id-allocation-onto-the-id-coordination-allocator
num: 112
title: "Wire spec-ID allocation onto the id-coordination allocator"
status: open
priority: high
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:56Z
updated: 2026-07-26T19:01:56Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`/jim:spec` assigns `group/NNN` by listing the group on the current branch (via `jimfile.sh next-id`), which two branches on separate clones compute identically and then collide on — and a spec ordinal is expensive to unwind because it is already frozen in directory paths and commit trailers.

Once `platform/007` ships, reserve `group/NNN` through the allocator at ID-assignment time in `/jim:spec` instead of deriving it from the tree. The spec directory is still created on the feature branch; the registry reservation always runs ahead of content on the coordination branch (an abandoned branch leaves a permanent gap, which is fine).

Follow-on to `platform/007` (foundation); this is the `sdlc`-group consumer slice.
