---
id: 20260723-single-source-the-000-blueprint-directory-name-in-jimpartition-s
num: 83
title: "Single-source the 000-blueprint directory name in jimpartition.sh"
status: open
priority: low
labels: [verify, partition, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-23T06:09:14Z
updated: 2026-07-23T06:09:14Z
origin: docs/specs/jim/049-contracts-check-hardening/review.md
---

## Description

Surfaced by the spec-049 post-build living-intent sensor while judging the
`blueprint-slot-reserved` invariant (verdict: holds).

The `000-blueprint` **directory** name is still hand-built at three sites in
`skills/partition/scripts/jimpartition.sh` — the rename/split/merge
`blueprint-exists` structural probes:

- `jimpartition.sh:962` / `:1057` / `:1218` — `[[ -d "$specs_dir/$old/000-blueprint" ]]`
  (with sibling `emit_check` message strings).

These are **not** a `blueprint-slot-reserved` violation: that invariant governs
the reserved *slot spec.md* path (`.../000-blueprint/spec.md`), which is resolved
only via `jimfile.sh path blueprint <group>`. These three probes construct the
*directory* path instead, and the resolver currently has no directory-yielding
form to route them through — so they are the last direct literal-coupling to the
reserved `000-blueprint` directory name in production code.

**Proposed action:** add a directory-yielding form to the resolver (e.g.
`jimfile.sh path blueprint-dir <group>` → `{specs}/<group>/000-blueprint`,
slug-validated like the existing `path blueprint`) and route the three
`jimpartition.sh` probes through it. This fully single-sources the reserved
directory name and removes the last hand-composition.

Out of scope for spec 049 (which only touched `jimverify.sh`); tracked here as a
low-priority hardening follow-on.
