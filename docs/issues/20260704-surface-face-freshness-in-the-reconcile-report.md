---
id: 20260704-surface-face-freshness-in-the-reconcile-report
num: 44
title: "Surface face freshness in the reconcile report"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T09:23:24Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/006-contract-graph/plan.md
---

## Context

Spec 034's research flagged the garbage-in risk: the contract graph inherits
face staleness (jim's own `000-blueprint` drifted within a day of 033
landing). The shipped report states coverage (M/N groups with blueprints) and
the graph's own `Last reconciled` stamp, but not how fresh the *inputs* are.
Scoped out of the 034 plan.

## What

Surface **stale faces as the exception** in the reconcile report, rather than
echoing a freshness readout for every group. On a multi-group partition a
per-group census buries the one thing that matters — the face old enough to
undermine the finding — so flag (or sort to the top) the faces past a
staleness bound and let clean ones stay quiet. A stale input is then visible at
detection time, and a clean report over stale faces is not over-trusted.

**Signal to read — the load-bearing pair.** Use the group blueprint's
`last_full_generate` stamp together with the 032 `updates-since` count: when
the face was last fully regenerated, and how much has landed against that group
since. That pair tracks face-vs-code drift. Plain `updated` is the weak signal
here — it moves on any edit, including a targeted face update, so a recent
`updated` can read as "fresh" while the face is actually adrift; treat it as
secondary at most, not the headline.

The staleness bound is **calibrated against real multi-group projects** — the
consumer repos jim's blueprint feature actually targets — not deferred for lack
of data. That calibration surface exists today.

## Scope boundary — calibration, not enforcement

This is passive trust-calibration: it tells the reader to trust a finding less;
it does nothing to refresh the stale face. The active fix for *chronic* drift
(jim's own blueprint drifting within a day is the motivating evidence) is
upstream — keeping faces fresh, or a reconcile-time refresh prompt — which is
adjacent territory, not this issue. Naming the boundary keeps this from being
mistaken for solving drift.

## Why

Findings are only as good as the declared faces; freshness context calibrates
trust the same way the blast-radius line's "graph as of" stamp does (034
security Finding 9's rationale, applied to the inputs).
