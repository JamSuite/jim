---
id: 20260704-add-a-plan-time-blast-radius-advisory-to-jim-plan
num: 39
title: "Add a plan-time blast-radius advisory to /jim:plan"
status: open
priority: medium
labels: [000-blueprint, cross-group, plan]
relations:
  blocks: []
  depends-on: [20260630-add-the-cross-group-contract-graph-and-blast-radius]
  related-to: []
  duplicates: []
created: 2026-07-04T06:09:52Z
updated: 2026-07-04T06:09:52Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

## Description

## Context

Split out of [[20260630-add-the-cross-group-contract-graph-and-blast-radius]]
(#21) during spec 034 scoping. 034 delivers the derived cross-group contract
graph: an on-demand reconcile surface, re-derivation on every
blueprint-surface write, and the spec-031 violation fork consuming blast
radius at face-change time. The plan-time consumer was deliberately deferred:
it fires on a *prediction* (planned-but-unwritten work touching a provides
face) rather than an actual face edit, and it touches a different skill —
the same thin-slice pattern as 030/031/032 over 029's artifact.

## What

When `/jim:plan` plans work in a group whose **provides** face the work would
touch, consult the project-tier contract graph (`BLUEPRINT.md`) and surface an
advisory naming every dependent group — the origin brainstorm's "pre-build
blast radius": a breaking-change detector that reads the map, not the diff.

- Advisory, never a veto — consistent with jim's non-blocking gate stance.
- Whether planned work touches a provides face is LLM judgment over the plan
  against the group's declared face; set precision expectations accordingly.
- Natural shape: an advisor moment in `/jim:plan` mirroring the spec-033
  assignment advisor in `/jim:spec`.

## Depends on

Spec 034 (the contract graph this advisory reads), and ≥2 reconciled group
blueprints so the advisory has consumers to name.
