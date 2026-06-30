---
id: 20260630-build-intelligence-for-context-aware-spec-group-definition
num: 19
title: "Build intelligence for context-aware spec-group definition"
status: open
priority: high
labels: [spec-groups, context-boundary, architecture, 000-current]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-30T11:07:07Z
updated: 2026-06-30T11:07:07Z
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

## Proposed direction

Before adopting the master-spec model, invest in **intelligence / guidance for
defining spec groups as deliberate context boundaries** — choosing boundaries
and naming inter-group relations with modular-design principles (cohesion, loose
coupling, bounded contexts) in view, rather than per-spec convenience.

## Out of scope here

Resolving this is out of scope for the `000-current` brainstorm; filed for
separate consideration (likely a research dive and/or its own spec).
