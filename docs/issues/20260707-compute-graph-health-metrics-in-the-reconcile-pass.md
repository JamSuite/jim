---
id: 20260707-compute-graph-health-metrics-in-the-reconcile-pass
num: 63
title: "Compute graph-health metrics in the reconcile pass"
status: closed
priority: medium
labels: [000-blueprint, contract-graph, spec-groups]
relations:
  blocks: [20260703-build-the-partition-migration-skill, 20260704-add-partition-health-sensors-split-merge-signals]
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T03:07:44Z
updated: 2026-07-25T07:49:14Z
origin: conversation
---

## Description

## Resolution

Shipped as **spec 039** (`docs/specs/blueprint/011-graph-health/`, 2026-07-07), which
names this issue as its origin. The reconcile pass now computes all four
measurements (edge density, cycle count, fan-in concentration, territory
coverage) deterministically and records them as additive counters on the
`blueprint finished … op=reconcile` ledger event; review confirmed all ten ACs
met, 434/434 tests passing. **Straddle count** remains deferred behind the
extractor fork (spec 038 / [[20260703-build-the-partition-migration-skill]]),
as scoped here. Downstream consumers stay open work: threshold/gating on these
metrics is [[20260630-build-the-invariant-verification-engine]] slice B2, and
split/merge interpretation is
[[20260704-add-partition-health-sensors-split-merge-signals]].

## Context

Surfaced by a 2026-07-06 partition-migration dry-run on a private project —
a manual end-to-end exercise of
[[20260703-build-the-partition-migration-skill]] (#34): a clean reconcile only proves the declared faces *match* the derived graph —
achievable on any codebase by declaring every messy edge. Face-accuracy and
partition-quality are orthogonal signals; on well-structured code they
coincide, on a tangle they diverge hard. The reconcile currently records
the seven spec-034 outcome counters (edges + six finding classes) but
nothing about the *shape* of the graph it writes.

## What

Have the reconcile pass compute partition-quality metrics from the contract
graph it already derives, and record them alongside the spec-034 counters
on the `blueprint finished` ledger event so they trend over time:

- **edge density** — edges relative to group count;
- **cycle count** — circular group dependencies;
- **fan-in concentration** — god-groups most of the map depends on;
- **territory coverage** — source dirs no group's territory owns: the
  proactive set-difference form of the partition-gap check (today it fires
  only reactively, when an unresolved-require happens to point at uncovered
  code). Computable under `declared-paths` / `directory` modes.

Health becomes a maintained property, not a one-shot diagnostic: a rising
cycle count or a new coverage gap is caught at the reconcile that
introduces it, not at some future migration.

Deferred: **straddle count** (one territory unit serving multiple groups)
needs code-level dependency extraction jim does not ship — it waits on the
extractor fork tracked in [[20260703-build-the-partition-migration-skill]].

## Consumers

- [[20260703-build-the-partition-migration-skill]] (#34) — measures the
  `actual` graph against a proposed `target` partition; its
  "partition-blocked-on-refactors" terminal state needs this quantitative
  basis.
- [[20260704-add-partition-health-sensors-split-merge-signals]] (#42) — the
  split/merge sensors read these metrics as their trend line.
- [[20260630-build-the-invariant-verification-engine]] (#22, slice B2) —
  gives `/jim:verify` or a reconcile gate something quantitative to warn on
  when a change degrades the partition.
