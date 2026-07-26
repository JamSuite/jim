---
id: 20260726-seed-the-id-coordination-registry-from-existing-artifacts
num: 114
title: "Seed the id-coordination registry from existing artifacts"
status: open
priority: high
labels: [id-coordination, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:58Z
updated: 2026-07-26T19:01:58Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

A migration/`seed` step builds the initial registry from existing spec directories and the issue `INDEX.md` so the allocator has a correct baseline the moment a project adopts it (otherwise the first allocation recomputes from an empty log and reissues consumed IDs).

Open sub-fork to decide during scoping — historical **duplicate** issue ordinals:
- renumber the younger dupes once at seed time (breaks some old handles, once, then clean), **or**
- grandfather them with dup-tolerant resolution (`show #42` may return two candidates) forever.

Follow-on to `platform/007` (foundation); `platform`-group.
