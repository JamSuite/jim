---
id: 20260801-narrow-the-issue-skill-s-jimalloc-grant-to-verb-level-prefixes
num: 198
title: "Narrow the issue skill's jimalloc grant to verb-level prefixes"
status: closed
priority: high
labels: [issue, permissions, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T20:33:39Z
updated: 2026-08-02T06:52:07Z
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

## Addendum — 2026-08-02: the condition is live, not anticipated

The registry-integrity spec has shipped, so the wildcard now covers verbs that did not exist when this was filed — including `catch-up --apply`, which writes the shared coordination branch, and `sweep`. The body above describes the risk in the future tense ("would be silently auto-permitted"); it is present tense as of this build.

Nothing changed in `skills/issue/SKILL.md`, and the skill body still invokes exactly one verb (`peek issue`) — every other allocator call reaches the CLI from inside `new.sh` / `reconcile.sh`, which carry their own grants. So narrowing the grant to `peek issue` should cost nothing, and that is now worth confirming rather than deferring.

Raised to high: the gap it describes is no longer hypothetical.

Confirmed by the post-build review of `platform/012` (`docs/specs/platform/012-registry-integrity-and-drift/review.md`), which traced every consumer of the allocator's changed surface.

## Resolution (2026-08-02)

Fixed in the pre-B build (`c54e3c9`). The grant is narrowed to
`jimalloc.sh peek issue *` — the one verb the skill body invokes, re-confirmed
by sweep before the edit: every other allocator call reaches the CLI from
inside `new.sh` / `reconcile.sh`, which carry their own grants. The mutating
`catch-up --apply` and the rest of the allocator surface are no longer
auto-permitted inside `/jim:issue`, matching the spec skill's verb-level
discipline. Taken now rather than later because the rename-emission spec is
about to widen the allocator's verb surface again.
