---
id: 20260630-add-the-cross-group-contract-graph-and-blast-radius
num: 21
title: "Add the cross-group contract graph and blast-radius"
status: open
priority: medium
labels: [000-blueprint, cross-group, architecture]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-30T20:35:19Z
updated: 2026-06-30T20:35:19Z
origin: docs/specs/jim/029-blueprint-spec/spec.md
---

## Description

## Context

Deferred slice of the `000-blueprint` initiative (spec 029). 029 captures each
group's provides/requires faces but does not join them across groups.

## What

Reconcile groups' `requires` against other groups' `provides` into a
**project-tier contract graph**:

- Detect **boundary leaks** (a group depends on something another never
  declared) and **dead surface** (declared but unused).
- **Pre-build blast radius**: changing a boundary invariant flags every
  dependent group.
- The graph is *derived* from the per-group faces, not a third hand-maintained
  copy (plausibly the ARCHITECTURE.md tier).

## Depends on

Spec 029, and ≥2 group blueprints to reconcile.
