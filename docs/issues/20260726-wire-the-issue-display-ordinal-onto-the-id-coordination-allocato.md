---
id: 20260726-wire-the-issue-display-ordinal-onto-the-id-coordination-allocato
num: 111
title: "Wire the issue display ordinal onto the id-coordination allocator"
status: open
priority: high
labels: [id-coordination, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:55Z
updated: 2026-07-26T19:01:55Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

The issue display ordinal (`#42`) is derived at `INDEX.md` render time today, so reindex and concurrent branches produce duplicate ordinals and hard `INDEX.md` git collisions.

Once `platform/007` ships the coordination allocator, wire `/jim:issue` filing to allocate the ordinal **once** via the mechanism and store it in the issue frontmatter; `INDEX.md` becomes a pure, idempotent projection with no allocation authority, so duplicate ordinals become structurally impossible. `show #42` resolves via frontmatter/registry lookup.

This consumer also introduces the `issue_placement` config (content-on-branch vs reservation-only) that `platform/007` deferred as a consumer-side concern.

Follow-on to `platform/007` (foundation); this is the `issue`-group consumer slice.
