---
id: 20260702-surface-targeted-update-count-since-last-full-blueprint-regen
num: 27
title: "Surface targeted-update count since last full blueprint regen"
status: open
priority: low
labels: [000-blueprint, fold-back]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-02T07:00:12Z
updated: 2026-07-02T07:00:12Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

## Description

## Context

Spec 030's blueprint update is deliberately diff-scoped: it edits only the
sections the change affects and never regenerates the rest. That keeps the
per-review cost low, but accumulated targeted updates can drift from what a
full whole-group regeneration (spec 029's generate mode) would produce —
non-local implications the diff lens cannot see. The originating brainstorm
called for a gate *or* a visible staleness flag ("behind N reviewed specs");
the gate shipped (`require_blueprint`, default off) but no staleness signal
exists — with default knobs a declined update leaves no trace.

## What

Surface a lightweight regen-cadence signal: when `/jim:blueprint` runs in
update mode, report "N targeted updates since last full generate" so the
developer knows when a whole-group regen is due. Prefer deriving N from
existing state rather than adding new state — e.g. the blueprint file's git
history (`commit-blueprint` commits are distinguishable from a developer-
committed full generate) or a frontmatter field stamped by generate mode.
Signal only — no new gate, no auto-regen.

See also [[20260630-wire-the-000-blueprint-fold-back-loop-into-review]].
