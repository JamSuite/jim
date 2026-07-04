---
id: 20260704-derive-the-map-relations-column-from-the-contract-graph
num: 40
title: "Derive the map Relations column from the contract graph"
status: open
priority: low
labels: [000-blueprint, cross-group, architecture]
relations:
  blocks: []
  depends-on: [20260630-add-the-cross-group-contract-graph-and-blast-radius]
  related-to: []
  duplicates: []
created: 2026-07-04T07:02:15Z
updated: 2026-07-04T07:02:15Z
origin: docs/specs/jim/034-contract-graph/research.md
---

## Description

## Context

Surfaced during spec 034 research (see origin). After 034, `BLUEPRINT.md`
carries who-depends-on-whom twice: the hand-declared per-group Relations
(spec 033 — partition-tier intent, written at map creation) and the derived
contract graph (spec 034). 034 scopes in the *check* — a mechanical pair-set
diff yielding stale-relation / undeclared-relation findings — but keeps the
column hand-declared.

## What

Decide whether the Relations column becomes a **derived view** of the
contract graph — eliminating the dual source instead of policing it (the
"derived from the faces, never re-declared" doctrine that governs the graph
itself and ARCHITECTURE.md's partition reference).

- **Bootstrap wrinkle:** at map creation the partition has no group
  blueprints, so there is nothing to derive from — the hand-declared column
  is the assignment advisor's day-one input. A hybrid lifecycle is plausible
  (declared at creation; derivation takes over once faces exist and the
  first reconcile lands).
- **Amends 033's shipped semantics** (column authorship), so it deserves its
  own deliberate decision, informed by multi-group practice — specifically
  whether hand-declared relations retain value past bootstrap, or whether
  the stale-relation detector fires often enough to prove the column should
  stop being hand-maintained.

## Depends on

Spec 034 shipping (the graph to derive from), via
[[20260630-add-the-cross-group-contract-graph-and-blast-radius]] (#21); and
real multi-group usage data.
