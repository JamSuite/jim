---
id: 20260630-wire-the-000-blueprint-fold-back-loop-into-review
num: 20
title: "Wire the 000-blueprint fold-back loop into review"
status: open
priority: medium
labels: [000-blueprint, fold-back, review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-30T20:35:18Z
updated: 2026-06-30T20:35:18Z
origin: docs/specs/jim/029-blueprint-spec/spec.md
---

## Description

## Context

Deferred slice of the `000-blueprint` initiative (spec 029 — group blueprint
spec). 029 produces a group's blueprint spec but does not maintain it
automatically.

## What

Add the post-review **fold-back gate**: after `/jim:review` runs, fold the
build's learnings (the verdict ledger + diff) back into the affected group's
`000-blueprint`, so the blueprint stays current as the code evolves.

- A stage *after* review (its own lens: whole-group vs. the living blueprint),
  fed by review's verdict ledger rather than re-deriving the diff.
- Default human-approved (a standard jim gate); an `auto_` knob enables a
  hands-off loop.
- What the human approves is a proposed diff against the blueprint.

## Depends on

Spec 029 (the blueprint must exist first).
