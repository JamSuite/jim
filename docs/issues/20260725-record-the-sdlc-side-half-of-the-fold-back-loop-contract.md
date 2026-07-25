---
id: 20260725-record-the-sdlc-side-half-of-the-fold-back-loop-contract
num: 101
title: "record the sdlc-side half of the fold-back-loop contract"
status: open
priority: low
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:44Z
updated: 2026-07-25T08:04:44Z
origin: BLUEPRINT.md
---

## Description

The fold-back loop spans two groups post-split: the living-intent sensor invocation lives in the sdlc group's review skill, while the engine and the violation fork live in the blueprint group. The fold-back-loop-grounding invariant is recorded in blueprint's 000-blueprint with the span noted.

Author the cross-group half: record the sensor-side obligations (verdict-first ordering, VERIFY-OUTCOME handoff, no-drop of un-forked in-change violations) as an sdlc-side invariant or a contract-checks line on the living-intent-sensor edge.
