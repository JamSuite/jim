---
id: 20260704-add-a-mint-new-handoff-row-to-the-blueprint-routing-table
num: 37
title: "Add a mint-new handoff row to the blueprint routing table"
status: closed
priority: low
labels: [blueprint, spec-groups]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T00:22:58Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/005-context-map/review.md
---

## Description

Surfaced by the 033 post-build review (origin); flagged independently by two
investigators. Closed: the routing-table row is added.

## What it was

`skills/blueprint/SKILL.md`'s Argument Routing table had no row for the
mint-new handoff (`/jim:spec` → inline `Skill(jim:blueprint)` carrying a
proposed group's name, purpose, role, and rationale). Only the § Project tier
"Mint-new handoff" paragraph disambiguated it, so a literal table read routed
the handoff args into the "A group name → Generate mode" arm — a full
group-tier generate instead of the project-tier scoped-add update flow. Low
risk in practice (the rich multi-token context reads nothing like a bare
group name), but the dispatch table was not self-sufficient.

## Resolution

Added a routing-table row directly under the "A group name" row naming the
mint-new handoff shape and routing it to the project-tier update flow, with a
pointer to § Project tier, Mint-new handoff. The table now disambiguates the
handoff without relying on prose elsewhere in the doc.

Spec 033 AC #13; review finding 3.
