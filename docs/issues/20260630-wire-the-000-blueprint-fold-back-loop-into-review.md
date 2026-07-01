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
updated: 2026-07-01T05:15:16Z
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
- Default human-approved (a standard jim gate). Config knobs: `auto_blueprint`
  (defined in spec 029) auto-writes the fold-back without a prompt;
  **`require_blueprint`** makes the refresh a required, blocking phase — the same
  shape as `auto_review` / `require_review`. `require_blueprint` is deferred here
  from 029: 029 is the on-demand generator, so the enforcing gate belongs with
  this integration, not as dead config in the generator.
- What the human approves is a proposed diff against the blueprint.

## Depends on

Spec 029 (the blueprint must exist first).
