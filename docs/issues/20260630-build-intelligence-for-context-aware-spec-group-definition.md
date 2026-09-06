---
id: 20260630-build-intelligence-for-context-aware-spec-group-definition
num: 19
title: "Build intelligence for context-aware spec-group definition"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec-groups, context-boundary, architecture, 000-blueprint]
relations:
  blocks: [20260630-add-the-cross-group-contract-graph-and-blast-radius, 20260703-build-the-partition-migration-skill]
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-30T11:07:07Z
updated: 2026-07-04T00:34:02Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

## Description

## Context

Surfaced while brainstorming the `000-current` group-level master spec (see
origin). That design elevates the **spec group** from a convenient label to a
**load-bearing architectural boundary**.

## The shift

Today a group name is incidental — picked because it fits the spec. The
master-spec model makes the group the **context boundary**: it unifies intent
and code under one umbrella, and is effectively the "loosely coupled" entity of
modular design (a module / bounded context). It gains:

- a **provides/requires** surface (the cross-group contract),
- **verification contracts** at its boundary,
- **external consumers** that depend on its exposed surface.

That is a dramatic shift from the current ad-hoc approach to group naming.

## Why it's a separate concern

The brainstorm designs the *blueprint artifact* and assumes well-formed groups
exist. This issue is the upstream act: **how groups come to be well-formed.**
Careless boundaries propagate bad seams into the blueprint, contracts, and
verification.

## Direction — resolved (2026-07-03 brainstorm)

Design record: `docs/brainstorms/20260703-context-aware-spec-group-definition.md`.
Decided there (do not re-litigate):

- **The context map is a top-level `BLUEPRINT.md`** — a tier-0 blueprint
  gluing the group blueprints into a single project-level scope. Declared
  intent, current-state-only, maintained by the same fold-back machinery as
  the group tier (specs 030–032). Joins the root doc family;
  `ARCHITECTURE.md` stays a generated reflection that references the map,
  never duplicates it.
- **Opinionated vertical-first doctrine** (bounded contexts, not layers),
  with an axis escape hatch (`vertical|layered`) in config. Shared-kernel /
  platform groups stay legitimate via a deliberately small `provides` face.
- **Code-territory binding is a config mode** (`directory` /
  `declared-paths` / `none`) — jim never dictates code layout; the chosen
  mode sets the strength and price of the mechanical verification floor.
- **Day-one map creation runs both directions:** interview what the user
  knows *and* actively propose a partition. **Assignment** (`/jim:spec`
  consumes the map) is advisory with strong pushback — the user decides,
  after a real argument.
- **Freeze history:** numbered specs never re-home; only living artifacts
  (map, blueprints, future filing) migrate.
- **One spec** covers `BLUEPRINT.md` + creation-time intelligence + the
  assignment advisor. Migration is split out to
  [[20260703-build-the-partition-migration-skill]] (#34).
- **Sequencing: this issue → #21 → #22.** The contract graph's home is
  `BLUEPRINT.md`, superseding the earlier "plausibly the ARCHITECTURE.md
  tier" placement.

## Next step

`/jim:spec` with the 20260703 brainstorm as origin.
