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
updated: 2026-07-26T19:01:57Z
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
