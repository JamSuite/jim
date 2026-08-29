---
id: 20260722-align-partition-split-flow-to-interview-plus-gate-shape
num: 85
title: "Align partition split flow to interview-plus-gate shape"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition, ux]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-22T21:20:25Z
updated: 2026-07-22T21:20:25Z
origin: docs/brainstorms/20260722-partition-merge.md
---

## Description

The partition-merge brainstorm (docs/brainstorms/20260722-partition-merge.md)
settled merge's gate shape as **interview + single hard gate** (the 038
repartition shape): judgment items — differing-text invariant-id collisions,
provides-surface homonyms, non-defaultable edge dispositions, fused blueprint
prose — are resolved conversationally *before* one hard gate presents the
fully-resolved change-set. Rationale: modifying the partition is a high-touch
operation the user should be engaged with, not merely approving.

Split (spec 047) shipped **pure single-gate**: its judgment residue
(spanning-case disambiguation, per-occupant assignment corrections) surfaces
only as confirmable gate rows, with decline-and-rerun as the sole iteration
path.

Consider retrofitting split to the same interview+gate shape so every
partition-changing verb (bare/repartition, split, merge) shares one cohesive
flow: mechanical prep → targeted interview over detected judgment items →
single hard gate → materialize. Rename likely stays gate-only — its change-set
is fully mechanical, with no judgment residue to interview.

Expected surface: prose-only orchestration change in the split flow of
`skills/partition/SKILL.md` (plus its methodology reference) — no script
changes; split's preflight and gatherer already detect the judgment items
(spanning rows) that would seed the interview.

Sequencing: wait until merge's spec lands and its interview shape is validated
in practice, then align split to the proven pattern.
