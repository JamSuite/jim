---
id: 20260726-add-an-only-door-verification-sweep-for-the-id-registry
num: 116
title: "Add an only-door verification sweep for the id registry"
status: open
priority: medium
labels: [id-coordination, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:02:01Z
updated: 2026-07-26T19:02:01Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

The registry only prevents collisions if allocation is the **sole** path to an ID. Nothing stops someone hand-creating `docs/specs/core/007-foo/` or an issue ordinal without the allocator (old habits, non-jim tooling); the allocator later issues `007` and the collision returns.

Add a mechanical, `jim:verify`-style check (CI-able, deterministic floor) that every spec directory and issue ordinal on the coordination branch has a matching registry record. Rogue entries get adopted into the registry or flagged. Allocation-is-the-only-door is enforced by detection, not trust.

Follow-on to `platform/007` (foundation), gap G2; `platform`-group (verify DNA).
