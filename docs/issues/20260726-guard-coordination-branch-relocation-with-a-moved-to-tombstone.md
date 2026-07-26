---
id: 20260726-guard-coordination-branch-relocation-with-a-moved-to-tombstone
num: 117
title: "Guard coordination_branch relocation with a moved-to tombstone"
status: open
priority: low
labels: [id-coordination, config]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:02:02Z
updated: 2026-07-26T19:02:02Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`jimconf` is read per-branch. If a team moves `coordination_branch` mid-project, stale branches keep allocating against the old location → split-brain registries.

Cheap fix: leave a `moved-to` tombstone file at the old registry location; the allocator follows it (or refuses with a clear message) instead of appending to the abandoned log.

Follow-on to `platform/007` (foundation), gap G8; `platform`-group.
