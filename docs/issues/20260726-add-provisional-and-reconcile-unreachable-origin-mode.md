---
id: 20260726-add-provisional-and-reconcile-unreachable-origin-mode
num: 115
title: "Add provisional and reconcile unreachable-origin mode"
status: open
priority: medium
labels: [id-coordination, config]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:02:00Z
updated: 2026-07-26T19:02:00Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`platform/007` ships `on_unreachable = fail` plus local-tier degradation. This adds the opt-in `provisional` mode: visibly non-real provisional IDs (shape TBD, e.g. `P-<date>-<slug>`) issued when origin is unreachable, and a `reconcile` path that on the next successful origin contact allocates real IDs for pending provisionals and rewrites references — for specs, that renames the directory (the same churn as allocate-on-merge).

Open questions to settle:
- Reconcile trigger: automatic on next allocator invocation vs. an explicit verb.
- Provisional-ID shape so it can never collide with an allocated ordinal.

This is also the honest path for fork-workflow contributors (G5) who push only to their fork and cannot allocate against the shared repo: provisional mode plus maintainer-side reconcile at PR review (or the future service backend).

Follow-on to `platform/007` (foundation); `platform`-group.
