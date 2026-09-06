---
id: 20260704-add-partition-health-sensors-split-merge-signals
num: 42
title: "Add partition-health sensors (split/merge signals)"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, cross-group, spec-groups]
relations:
  blocks: []
  depends-on: [20260630-add-the-cross-group-contract-graph-and-blast-radius, 20260707-compute-graph-health-metrics-in-the-reconcile-pass]
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T08:08:24Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/006-contract-graph/spec.md
---

> **Resolved by spec 044 (partition-health sensors) — 2026-07-12.** The
> split/merge trend sensors and the silent reconcile-tail threshold hook
> shipped in `docs/specs/blueprint/016-partition-health/`; this issue's scope is
> fully covered.

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

The split/merge signals need calibrated thresholds — what counts as *chronic*
straddle, a face too *fat*, a blast radius too *broad*. That calibration reads
real multi-group partitions, and those exist now: jim's blueprint audience is
the multi-group projects built with it, so the calibration surface is available
today, not a far-off someday. What this genuinely waits on is *accumulated
reconcile history* from its input metrics — the spec-034 ledger counters and
the graph-health metrics (#63, shipped as spec 039) — to form a trend line a
sensor can read. Low because that trend has to build up across real reconciles,
not because the data source is missing. Filed so the deferral has a home
instead of a dangling pointer.

## Depends on

[[20260630-add-the-cross-group-contract-graph-and-blast-radius]] (#21) —
the graph, its finding classes, and the reconcile counters are the primary
signal source; #22's verification failures enrich it later.

[[20260707-compute-graph-health-metrics-in-the-reconcile-pass]] (#63) —
supplies the mechanical graph-health metrics (edge density, cycles, fan-in,
territory coverage) these sensors read as their trend line; added
2026-07-07 from the partition-migration dry-run (recorded in #34).
