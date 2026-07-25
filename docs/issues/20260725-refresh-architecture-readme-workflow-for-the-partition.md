---
id: 20260725-refresh-architecture-readme-workflow-for-the-partition
num: 103
title: "refresh ARCHITECTURE, README, WORKFLOW for the partition"
status: open
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:48Z
updated: 2026-07-25T08:04:48Z
origin: BLUEPRINT.md
---

## Description

ARCHITECTURE.md, README.md, and WORKFLOW.md predate the partition: the architecture doc describes a single jim spec group and the old spec numbering; the strategic docs reference group-era paths. ARCHITECTURE.md refreshes only through /jim:arch (never hand-edited); README/WORKFLOW need a manual pass.

Run /jim:arch to regenerate, then sweep README.md and WORKFLOW.md for group-era mentions (docs/specs/jim paths, single-group framing).
