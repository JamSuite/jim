---
id: 20260725-record-the-sdlc-side-half-of-the-fold-back-loop-contract
num: 101
title: "record the sdlc-side half of the fold-back-loop contract"
status: closed
priority: low
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:44Z
updated: 2026-07-25T18:44:18Z
origin: BLUEPRINT.md
---

## Description

The fold-back loop spans two groups post-split: the living-intent sensor invocation lives in the sdlc group's review skill, while the engine and the violation fork live in the blueprint group. The fold-back-loop-grounding invariant is recorded in blueprint's 000-blueprint with the span noted.

Author the cross-group half: record the sensor-side obligations (verdict-first ordering, VERIFY-OUTCOME handoff, no-drop of un-forked in-change violations) as an sdlc-side invariant or a contract-checks line on the living-intent-sensor edge.

## Resolution

Recorded as an **sdlc-side invariant**, not a contract-checks line: the three obligations are behavioral/ordering guarantees, which the contract-checks grammar (`provider-ref`/`consumer-ref` pattern matches + criticality) structurally cannot express — they need the judge.

Authored via `/jim:blueprint`:

- **sdlc `000-blueprint`** gains the `fold-back-sensor-obligations` invariant (criticality `high`, check `judge`) capturing all three obligations, mirroring the blueprint-side row. The `review.md` + verdict-record Provides guarantee was also tightened to name the no-drop routing, which the face had omitted.
- **blueprint `000-blueprint`**'s `fold-back-loop-grounding` row drops its "the cross-group half is tracked as a contract follow-up" clause, now pointing at the sdlc-side invariant instead.

Both obligations trace to the review skill's real behavior (verdict assigned before the sensor runs; the VERIFY-OUTCOME block handed to the fork rather than re-run; every in-change violation routed to the fork or, on a declined/absent update offer, filed as an issue). Neither edit changed a contract edge; the reconcile pass refreshed the graph timestamp only.
