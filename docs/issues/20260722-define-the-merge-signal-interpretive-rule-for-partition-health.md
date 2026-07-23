---
id: 20260722-define-the-merge-signal-interpretive-rule-for-partition-health
num: 86
title: "Define the merge-signal interpretive rule for partition health"
status: open
priority: medium
labels: [partition, health]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-22T22:24:13Z
updated: 2026-07-23T03:35:54Z
origin: docs/brainstorms/20260722-partition-merge.md
---

## Description

The 044 health mockup's `Merge signal:` line is a first-class output slot, but
no spec defines which pattern of the four sensor classes — breaking churn,
graph-shape trends, face growth, name mismatch — constitutes a *merge*
recommendation. The read is pure inline-LLM judgment today.

The 20260722 partition-merge brainstorm scoped the merge-mechanism spec to
deliberately exclude the detector side. Once the merge verb ships, define the
interpretive rule that turns sensor readings into "merge these N groups" —
e.g. chronic breaking churn concentrated between two specific groups, mutual
fan-in, co-changing faces. Issue #72's chronic domain↔domain straddle flags are
the most merge-shaped input once a recording surface exists; cross-reference it
when designing the rule.

Constraint: stay on the interpretation side of the 039
measurement/interpretation boundary — this work defines how 044's health read
interprets existing (and #72's future) signals; it adds no new measurements to
the reconcile pass.

## Update (2026-07-23) — precondition met

The merge verb shipped in **spec 048** (`/jim:partition merge`), so this
follow-on's "once the merge verb ships" trigger is now satisfied and the work is
unblocked. The merge mechanism deliberately excluded the detector side (spec 048
Out of Scope), leaving `health`'s `Merge signal:` slot on inline judgment — the
gap this issue closes.
