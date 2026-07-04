---
id: 20260704-surface-face-freshness-in-the-reconcile-report
num: 44
title: "Surface face freshness in the reconcile report"
status: open
priority: low
labels: [000-blueprint, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T09:23:24Z
updated: 2026-07-04T09:23:24Z
origin: docs/specs/jim/034-contract-graph/plan.md
---

## Description

## Context

Spec 034's research flagged the garbage-in risk: the contract graph
inherits face staleness (jim's own `000-blueprint` drifted within a day of
033 landing). The shipped report states coverage (M/N groups with
blueprints) and the graph's own `Last reconciled` stamp, but not how fresh
the *inputs* are. Scoped out of the 034 plan.

## What

Echo each face's freshness in the reconcile report — the group blueprint's
`updated` / `last_full_generate` frontmatter (and possibly the 032
`updates-since` count) per group — so a stale input is visible at
detection time and a clean report over stale faces is not over-trusted.

## Why

Findings are only as good as the declared faces; freshness context
calibrates trust the same way the blast-radius line's "graph as of" stamp
does (034 security Finding 9's rationale, applied to the inputs).
