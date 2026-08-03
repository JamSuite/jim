---
id: 20260803-keep-the-record-layer-off-the-reporting-layer-s-sanitizer
num: 216
title: "Keep the record layer off the reporting layer's sanitizer"
status: open
priority: low
labels: [id-coordination, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:29Z
updated: 2026-08-03T05:50:29Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

`alloc_rename_scan` and `alloc_realize_scan` sit in the section documented as
the pure record layer — "operates on a log, no git", no output concerns. Both
now call `alloc_sanitize_field`, which lives in the reporting layer roughly 2200
lines away.

Nothing is wrong today, and the reason the call drifted down is defensible: a
record field that any consumer might echo wants gating once, at the point it is
read. But the section header still claims a separation the code no longer has,
and that layer's purity is exactly what makes it safe to reuse from a resolver,
two folds, a classifier and two emitters without each caller reasoning about
output.

## Proposed action

Decide which way the boundary goes — move the sanitizer into the record layer as
a shared primitive, or return raw fields and gate at each reporting site — then
make the section header state what is true. A header that describes a purity the
code does not have is worse than no header, because it is what the next editor
reasons from.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 20b). Not filed alongside that review's other follow-ons.
