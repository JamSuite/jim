---
id: 20260708-partition-spec-migration-mode
num: 68
title: "Extend /jim:partition with a spec-migration mode (move specs into new groups)"
status: open
priority: medium
labels: [partition, migration, freeze-history]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-08T07:53:09Z
updated: 2026-07-08T07:53:09Z
origin: conversation
---

## Description

## Context

`/jim:partition` (shipped as spec 038) deliberately does **not** move numbered
specs. Its repartition mode migrates only *living* artifacts — the context map,
group blueprints, and future spec filing — while numbered specs stay frozen
where they are (AC #13: "No mode of this skill moves, renumbers, or edits a
numbered spec directory"), rooted in the spec 029 freeze-history doctrine and
reinforced by VISION's "the spec/research/plan archive becomes a go-to reference
for onboarding and decision history."

The consequence: after a repartition, existing specs remain filed under
now-retired group ids, their `Spec: <group>/<NNN>` trailers and directory homes
pointing at groups the new map no longer declares. They are stranded under a
partition authority that has been superseded.

## What

Extend `/jim:partition` with a spec-migration capability that re-homes existing
numbered specs into the new groups a repartition establishes — so that after a
migration the spec archive is coherent with the live partition, not split
between a retired group layout and a current one.

## The crux — this reopens freeze-history

This is not a small extension. Moving specs directly contradicts the doctrine
`/jim:partition` was built to honor. Before any of this is built, the design
fork to resolve is whether the coherence benefit can be had **without** breaking
the immutable-history property VISION depends on:

- **Move vs. forward.** A redirect/alias index (old id → new group home) may
  deliver discoverability without physically relocating or renumbering the
  frozen artifact. Decide whether re-homing is a physical move or a forwarding
  layer over an untouched archive.
- **Id + trailer semantics.** Spec ids are per-group (`Spec: dashboard/001`).
  Re-homing implies a new id or a collision in the destination group, and 038
  put reference-rewriting explicitly out of scope. How are ids, `Spec:`
  trailers, and inbound cross-references handled?
- **Git-history continuity.** A physical move must preserve blame/log continuity
  for the relocated files.
- **Surface + `--retire` interaction.** Is this a `/jim:partition` sub-mode or a
  distinct verb, and how does it compose with the `--retire` arm that already
  marks a superseded group's blueprint as retired — do that group's specs follow
  the same pointer?

## Relation

Extends [[20260703-build-the-partition-migration-skill]] (#34, shipped as spec
038). Sequenced behind the current #22 verification-engine work; filed now so the
freeze-history reopening has a tracked home rather than living only in
conversation.
