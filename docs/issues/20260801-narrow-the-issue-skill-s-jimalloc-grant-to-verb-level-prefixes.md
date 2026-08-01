---
id: 20260801-narrow-the-issue-skill-s-jimalloc-grant-to-verb-level-prefixes
num: 198
title: "Narrow the issue skill's jimalloc grant to verb-level prefixes"
status: open
priority: low
labels: [issue, permissions, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T20:33:39Z
updated: 2026-08-01T20:33:39Z
origin: docs/specs/platform/012-registry-integrity-and-drift/research.md
---

## Description

## Description

`skills/issue/SKILL.md:6` grants `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimalloc.sh *)` — a wildcard over every allocator verb. The sibling grant in `skills/spec/SKILL.md:10` is scoped to the two verb forms that skill actually invokes (`peek spec *`, `allocate spec *`).

Today the wildcard covers only what `/jim:issue` needs (its body invokes `peek issue`; the emitter and reconciler call the allocator from inside their own scripts). The gap becomes real when the registry-integrity spec lands: new allocator verbs — including a mutating catch-up apply that writes the shared coordination branch — would be silently auto-permitted inside `/jim:issue`'s permission surface, with no grant review.

## Proposed action

Narrow the grant to the verb-level prefixes the skill body actually invokes, matching the spec skill's discipline. First establish which forms those are (at minimum `peek issue`); anything reached only through `new.sh` / `reconcile.sh` does not need a SKILL-level jimalloc grant at all.

## Provenance

Surfaced by the pre-plan research scan for the registry-integrity spec (`docs/specs/platform/012-registry-integrity-and-drift/research.md`), which enumerated every `jimalloc.sh` call site and its covering grant.
