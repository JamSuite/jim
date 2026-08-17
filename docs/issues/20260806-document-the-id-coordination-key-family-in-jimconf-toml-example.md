---
id: 20260806-document-the-id-coordination-key-family-in-jimconf-toml-example
num: 255
title: "Document the id_coordination_* key family in jimconf.toml.example"
status: closed
priority: medium
labels: [config, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-06T20:20:05Z
updated: 2026-08-15T07:38:35Z
origin: docs/specs/issue/011-issue-placement/research.md
---

## Description

The `id_coordination_*` key family is undocumented in `jimconf.toml.example`. The example file ends (currently at the health keys, ~line 347) without any of `id_coordination_branch`, `id_coordination_unreachable`, or their siblings — while the live `jimconf.toml` in this repo sets `id_coordination_unreachable = "provisional"` (line 24). A user setting up coordination has no precedent block to copy, and a future key addition to that family has no documented home to extend.

Surfaced while researching [[spec-issue-placement-config-for-issue-content-location]] (spec `issue/011`): the placement work adds a new key to the example file and found no coordination-adjacent block to sit it beside.

Proposed action: add a commented `id_coordination_*` block to `jimconf.toml.example` documenting each key, its default, and its accepted values, matching the file's existing per-section conventions.

## Resolution (2026-08-15)

`jimconf.toml.example` now carries the block at `:111-140`, added whole by
`abd0e1f` — every line in that range blames to it.

Against the proposed action:

- **Each key, commented, with its default shown** — `id_coordination_mechanism =
  "git"` (`:124`), `id_coordination_branch = "jim/registry"` (`:129`),
  `id_coordination_unreachable = "fail"` (`:140`). That is the whole family; no
  sibling is missing.
- **Accepted values** — `mechanism` names `git` as the only one built and states
  that an unrecognized value is refused rather than silently degraded;
  `unreachable` enumerates `fail` and `provisional`, each with what it does, and
  names the reconcile verb that realizes a provisional token later.
- **Section conventions** — a `# --- ID coordination ---` rule, a purpose
  paragraph, then one comment-and-key stanza per setting: the same shape as its
  neighbours (compare `# --- Post-build review gate ---` at `:142`).

The file no longer "ends at the health keys" as the description observed — the
coordination block sits ahead of the review gate, so the future key this asked
for has a documented home to extend. The same family is also documented for
readers rather than configurers in `docs/features/id-coordination.md`
§ Configuration.
