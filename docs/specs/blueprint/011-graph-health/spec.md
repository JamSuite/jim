---
title: "Graph-health metrics in the reconcile pass"
type: feature
group: "blueprint"
id: "039"
status: approved
origin:
  - "docs/issues/20260707-compute-graph-health-metrics-in-the-reconcile-pass.md"
---

# 039 Graph-health metrics in the reconcile pass

## Overview

The reconcile pass computes partition-quality measurements — edge density,
cycle count, fan-in concentration, territory coverage — from the contract
graph it already derives, renders them with their change since the previous
reconcile, and records them on the reconcile's ledger event so health
trends over time.

## Problem Statement

A clean reconcile only proves the declared faces *match* the derived
graph — achievable on any codebase by declaring every messy edge.
Face-accuracy and partition-quality are orthogonal signals; on
well-structured code they coincide, on a tangle they diverge hard. Today
the reconcile records finding counters (spec 034) but nothing about the
*shape* of the graph it writes, so a partition can degrade — a new
dependency cycle, a widening coverage gap, an emerging god-group — with no
signal at the reconcile that introduces the degradation. Spec 038's
migration flow additionally needs this signal as its partition-quality
done-condition (038 AC #10), distinct from clean faces.

## User Stories

- As a developer whose blueprint write triggers a reconcile, I can see the
  partition's health measurements and their change so that a degrading
  partition is caught at the reconcile that introduces the degradation.
- As a developer running a partition migration (spec 038), I can read
  recorded graph health alongside the clean-faces signal so that the
  migration's done-condition distinguishes face-accuracy from partition
  quality.
- As a developer investigating partition drift over time, I can
  reconstruct the measurement series from the ledger alone so that trends
  are queryable without any new artifact or tooling.

## Acceptance Criteria

- [ ] Every reconcile run computes four graph-health measurements from the
      just-derived contract graph and the map's declared territories: edge
      density, cycle count, fan-in concentration, and territory coverage
      (source paths owned by no group).
- [ ] The reconcile report renders a health block with each measurement's
      current value and its delta against the immediately preceding
      reconcile event when one exists; a first reconcile renders baseline
      values with no delta. A prior event that fails shape validation (per
      the specs 034/028 extraction pattern) is treated as absent — baseline
      rendering — and the report names that degradation rather than
      silently hiding it.
- [ ] The health block is measurement-only: no verdicts, thresholds, or
      pass/fail wording (the no-standing-verdict doctrine, per spec 034;
      judgment belongs to downstream sensors and gates).
- [ ] The measurements ride the existing `blueprint finished … op=reconcile`
      ledger event as additive counters alongside the seven spec 034
      counters, and the documented counter contract (fixed key set,
      shape-validated extraction, per specs 034/028) is updated in the same
      change so every consumer validates the extended set.
- [ ] Ledger events stay content-free: health counters carry numeric values
      only — uncovered path names and cycle membership appear in the
      report, never in event fields (the trusted metrics-channel doctrine,
      per spec 026).
- [ ] Under a path-bearing territory mode (`directory` / `declared-paths`),
      territory coverage is the set of tracked source paths belonging to no
      group's declared territory; the report names the uncovered
      directories and the event carries the count.
- [ ] Under `group_territory = none`, or when territory declarations are
      absent, coverage is explicitly reported as not computable — in both
      the report and the event — and is never rendered or recorded as
      "zero uncovered."
- [ ] When the reconcile short-circuits (fewer than two blueprint-bearing
      groups), health short-circuits with it explicitly: the
      nothing-to-reconcile note covers health, and no zero-valued health
      counters are recorded that could read as measurements.
- [ ] The measurements are deterministic: re-running over an unchanged
      graph and unchanged territory declarations produces identical values.
- [ ] Reconcile behavior is otherwise unchanged: finding classes, the issue
      offer, commit choreography, and the persisted `## Contract Graph`
      section are untouched, and a health measurement never alters or
      vetoes a finding.

## UI Mockup

```
Reconcile — acme-shop: 4 groups, 4 with blueprints (coverage 4/4)
  ✓ 12 edges · 0 findings

Graph health (vs 2026-07-01T09:12:44Z):
  groups 4 · edges 12 · density 3.0 (was 2.8 ↑)
  cycles 1 (was 0 ↑) — billing ⇄ orders
  max fan-in 3 — platform (unchanged)
  uncovered 2 dirs — src/metrics/, tools/ (was 2)
```

## Out of Scope

- **Thresholds, warnings, or gating** on health values — that is verify /
  reconcile-gate territory (issue #22 slice B2).
- **Split/merge proposals or any interpretation** of the measurements —
  the partition-health sensors (issue #42) consume this substrate.
- **Straddle count** (one territory unit serving multiple groups) —
  requires code-level dependency extraction, deferred behind spec 038's
  extractor fork.
- **Backfilling** health values onto historical ledger events.
- **A persisted health artifact or report file** — the report is
  conversational, the ledger event is the durable trace.
- **Changes to the persisted graph section or `BLUEPRINT.md` content** —
  health lives in report + ledger only.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting
point to evaluate, not a directive.*

### Insight 1: Deterministic computation as a script verb

- **Relates to AC:** *"measurements are deterministic"* (AC #9)
- **Surfaced as:** compute the metrics in a deterministic script verb over
  the derived edge set (the `jimverify.sh edges` verb already parses the
  persisted graph; the Bash-vs-Prompt rule puts counting/graph-walking in
  script, framing in skill).
- **Levelled-up requirement (already in the ACs):** deterministic,
  reproducible measurements.
- **Deflection reason:** Delegation — where the verb lives (jimverify,
  jimledger, or a reconcile-owned script) is the architect's call.
- **Routing hint:** Architect to decide.

### Insight 2: Integer encoding under shape validation

- **Relates to AC:** *"additive counters … contract updated in the same
  change"* (AC #4)
- **Surfaced as:** the 028-pattern validation expects non-negative
  integers; encode numerators/denominators as integer counters (e.g.
  `groups=`, `cycles=`, `fanin_max=`, `uncovered=`) and let density be
  derived from `edges=`/`groups=` rather than recording a float; encode
  coverage's not-computable state distinctly from zero.
- **Levelled-up requirement (already in the ACs):** extended,
  shape-validated counter contract; not-computable never reads as zero.
- **Deflection reason:** Delegation — exact keys and encodings are plan
  detail.
- **Routing hint:** Architect to decide.

### Insight 3: Delta source is the previous reconcile event

- **Relates to AC:** *"delta against the immediately preceding reconcile
  event"* (AC #2)
- **Surfaced as:** read the prior `op=reconcile` event from the specs-root
  ledger (the `jimledger.sh updates-since` precedent for event querying);
  no new state file.
- **Levelled-up requirement (already in the ACs):** delta rendering with a
  baseline first run.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

### Insight 4: Coverage reuses the territory machinery

- **Relates to AC:** *"tracked source paths belonging to no group's
  declared territory"* (AC #6)
- **Surfaced as:** per-group territory extraction and path validation
  already exist (`jimverify.sh territory`, `safe_path_param`); coverage is
  the union-across-groups complement of the existing per-group conformance
  set difference.
- **Levelled-up requirement (already in the ACs):** coverage under
  path-bearing modes with explicit degradation otherwise.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Same ledger event or a separate health record?~ → Same
      `op=reconcile` event, additive keys; the spec 034 counter contract is
      updated in the same change.
- [x] ~Record-only or render the trend?~ → Render current values + delta
      vs the previous reconcile; record on the event.
