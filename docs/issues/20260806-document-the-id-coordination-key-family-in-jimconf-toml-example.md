---
id: 20260806-document-the-id-coordination-key-family-in-jimconf-toml-example
num: 255
title: "Document the id_coordination_* key family in jimconf.toml.example"
status: open
priority: medium
labels: [config, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-06T20:20:05Z
updated: 2026-08-06T20:20:05Z
origin: docs/specs/issue/011-issue-placement/research.md
---

## Description

The `id_coordination_*` key family is undocumented in `jimconf.toml.example`. The example file ends (currently at the health keys, ~line 347) without any of `id_coordination_branch`, `id_coordination_unreachable`, or their siblings — while the live `jimconf.toml` in this repo sets `id_coordination_unreachable = "provisional"` (line 24). A user setting up coordination has no precedent block to copy, and a future key addition to that family has no documented home to extend.

Surfaced while researching [[spec-issue-placement-config-for-issue-content-location]] (spec `issue/011`): the placement work adds a new key to the example file and found no coordination-adjacent block to sit it beside.

Proposed action: add a commented `id_coordination_*` block to `jimconf.toml.example` documenting each key, its default, and its accepted values, matching the file's existing per-section conventions.
