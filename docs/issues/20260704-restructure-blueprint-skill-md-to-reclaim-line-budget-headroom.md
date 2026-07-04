---
id: 20260704-restructure-blueprint-skill-md-to-reclaim-line-budget-headroom
num: 43
title: "Restructure blueprint SKILL.md to reclaim line-budget headroom"
status: open
priority: low
labels: [000-blueprint, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T09:23:23Z
updated: 2026-07-04T09:23:23Z
origin: docs/specs/jim/034-contract-graph/plan.md
---

## Description

## Context

Spec 034's reconcile arm brought `skills/blueprint/SKILL.md` to 497/500
lines (ARCHITECTURE.md's progressive-disclosure ceiling). The 034 plan's
pre-identified fallback was already applied — per-mode commit choreography
lives in `references/reconcile-methodology.md` — so the next
blueprint-touching spec has ~3 lines of slack and will bust the budget on
contact.

## What

Restructure the SKILL.md body to reclaim headroom before the next feature
needs it. Candidate levers:

- Push more of the § Update mode / § Project tier prose into the existing
  references (`map-methodology.md`, `reconcile-methodology.md`), keeping
  dispatch + process skeletons in the body (the 033/034 precedent).
- Consolidate the validation checklist's per-mode items.

## Why

The 500-line ceiling is a locked ARCHITECTURE.md constraint; hitting it
mid-spec forces an unplanned restructure inside an unrelated build.
