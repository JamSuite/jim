---
id: 20260707-spell-out-the-superseded-group-set-derivation-for-retire
num: 66
title: "spell out the superseded-group set derivation for --retire"
status: open
priority: low
labels: [partition, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T11:03:54Z
updated: 2026-07-07T11:03:54Z
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
