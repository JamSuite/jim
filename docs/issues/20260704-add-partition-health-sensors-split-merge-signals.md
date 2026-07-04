---
id: 20260704-add-partition-health-sensors-split-merge-signals
num: 42
title: "Add partition-health sensors (split/merge signals)"
status: open
priority: low
labels: [000-blueprint, cross-group, spec-groups]
relations:
  blocks: []
  depends-on: [20260630-add-the-cross-group-contract-graph-and-blast-radius]
  related-to: []
  duplicates: []
created: 2026-07-04T08:08:24Z
updated: 2026-07-04T08:08:24Z
origin: docs/specs/jim/034-contract-graph/spec.md
---

## Description

## Context

Spec 033's Out of Scope deferred "split/merge health sensors (detecting a
partition gone bad)" to "#21/#22 territory" — but neither issue's text
carries it, and spec 034 (from #21) scopes in only the partition-gap and
relation-drift finding classes. The detector side of partition health is
otherwise untracked. Surfaced during 034 scoping.

## What

Detect a partition gone bad from signals the machinery already produces (or
will, once 034 ships):

- chronic domain↔domain straddle flags from `/jim:spec`'s assignment
  advisor (033);
- fat, chatty faces — a group whose provides surface keeps growing across
  reconciles;
- everything-affects-everything blast radius — boundary changes that flag
  most of the map every time;
- repeated cross-group breaking-change findings (034's ledger counters give
  the trend line).

Output: a reasoned split/merge proposal for the developer — the *detector*
whose *remedy* is [[20260703-build-the-partition-migration-skill]] (#34),
which currently has nothing telling the developer it's time to use it.

## Why low

Needs multi-group practice data before the signals mean anything — same
calibration as the onboarding partitioner (#35). Filed so the deferral has a
home instead of a dangling pointer.

## Depends on

[[20260630-add-the-cross-group-contract-graph-and-blast-radius]] (#21) —
the graph, its finding classes, and the reconcile counters are the primary
signal source; #22's verification failures enrich it later.
