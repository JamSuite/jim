---
id: 20260707-spell-out-the-superseded-group-set-derivation-for-retire
num: 66
title: "spell out the superseded-group set derivation for --retire"
status: closed
priority: low
labels: [partition, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T11:03:54Z
updated: 2026-07-09T11:11:44Z
origin: docs/specs/jim/038-partition-migration/review.md
---

## Description

`skills/partition/SKILL.md:152` says "For each superseded group … `--retire`" but
does not spell out how the superseded set is computed. The retire *mechanism* is
fully operationalized (the `/jim:blueprint --retire <group>` arm), but the set
derivation — which groups count as superseded in a repartition — is left to
run-time judgment.

**Suggestion:** add a one-line rule to the materialize step (or the methodology's
readiness/materialize section) naming the superseded set explicitly, e.g. the old
`BLUEPRINT.md` groups minus the newly approved partition's groups
(`old-map groups ∖ approved-partition groups`).

Relates to AC #19. Surfaced by the spec 038 post-build review (finding 2).

## Resolution (2026-07-09)

Named the set inline in the §5 Materialize retire bullet
(`skills/partition/SKILL.md`): the superseded set is `old-map ∖ approved`
— the old `BLUEPRINT.md`'s groups minus the approved partition's — with a
rename counting as old-name-out / new-name-in. Grounding confirmed the
formula against the blueprint retire arm, where a retired group is one
"absent from [the map]" (`blueprint/SKILL.md:464`); set-difference on group
identity handles rename and split/merge correctly.

**Placement — SKILL.md, not the methodology.** The methodology has no retire
or materialize section (only Readiness, a different run mode), so that option
meant *creating* a home for a one-liner. The gap was exactly at the point of
use — the bullet said "for each superseded group" with the set unnamed — and
partition SKILL had ample budget (269→272 / 500). No new methodology section,
no checklist change (line 264 already references the mechanism; §5 is now the
canonical set definition). No guard clause: the retire arm already no-ops
gracefully on a superseded group that lacks a blueprint
(`blueprint/SKILL.md:457`, "nothing to retire").
