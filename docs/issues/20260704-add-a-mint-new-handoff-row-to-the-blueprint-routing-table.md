---
id: 20260704-add-a-mint-new-handoff-row-to-the-blueprint-routing-table
num: 37
title: "Add a mint-new handoff row to the blueprint routing table"
status: open
priority: low
labels: [blueprint, spec-groups]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T00:22:58Z
updated: 2026-07-04T00:22:58Z
origin: docs/specs/jim/033-context-map/review.md
---

## Description

## Context

Surfaced by the 033 post-build review (origin); flagged independently by
two investigators.

## What

`skills/blueprint/SKILL.md`'s Argument Routing table has no row for the
mint-new handoff invocation (`/jim:spec` → `Skill(jim:blueprint)` with a
proposed-group context as args). Only the § Project tier "Mint-new
handoff" paragraph disambiguates; a literal table read routes any
non-empty argument into the "A group name → Generate mode" arm, so a
handoff passing only a bare group name would misroute to a full
group-tier generate.

## Fix

Add one routing-table row (or a note directly under the table) naming the
mint-new handoff shape and pointing to § Project tier. Low risk in
practice — the advisor passes multi-token context — but the dispatch
table should be self-sufficient.

## Relates to

Spec 033 AC #13; review finding 3.
