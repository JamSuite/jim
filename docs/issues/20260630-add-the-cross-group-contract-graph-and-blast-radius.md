---
id: 20260630-add-the-cross-group-contract-graph-and-blast-radius
num: 21
title: "Add the cross-group contract graph and blast-radius"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, cross-group, architecture]
relations:
  blocks: [20260704-add-a-plan-time-blast-radius-advisory-to-jim-plan, 20260704-derive-the-map-relations-column-from-the-contract-graph, 20260704-add-partition-health-sensors-split-merge-signals]
  depends-on: [20260630-build-intelligence-for-context-aware-spec-group-definition]
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-30T20:35:19Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/001-blueprint-spec/spec.md
---

## Context

Deferred slice of the `000-blueprint` initiative (spec 029). 029 captures each
group's provides/requires faces but does not join them across groups.

## What

Reconcile groups' `requires` against other groups' `provides` into a
**project-tier contract graph**:

- Detect **boundary leaks** (a group depends on something another never
  declared), **dead surface** (declared but unused), and **breaking changes**
  (a group requires something the provider *removed* — a regression against a
  live consumer; this mismatch class is what powers blast-radius).
- **Pre-build blast radius**: changing a boundary invariant flags every
  dependent group.
- The graph is *derived* from the per-group faces, not a third hand-maintained
  copy. Home: the project-tier **`BLUEPRINT.md`** (resolved in the 20260703
  context-map brainstorm — supersedes the earlier "plausibly the
  ARCHITECTURE.md tier" placement).

## Decided — do not re-litigate

Boundary authority was resolved in the origin brainstorm: **hybrid**. The
provider hand-declares its `provides` face (intentional, low-churn); each
consumer's `requires` face is discovered from its code; the contract is the
checked reconciliation of `A.requires ↔ B.provides`, owned by neither map.
Drift is then a *failed reconciliation* — the detector firing — not silent
divergence.

## Scope refinement (spec 034 scoping, 2026-07-04)

This issue is being spec'd as **034**. Trigger model settled there:

- **In scope for 034:** the on-demand reconcile surface; re-derivation of the
  graph on every blueprint-surface write (group-tier generate/update *and*
  map-tier updates — any write through `/jim:blueprint` refreshes the
  reconciliation); and the spec-031 violation fork consuming blast radius at
  face-change time. 031's Out of Scope routes exactly this question here: a
  Provides-face downgrade should name the consumer groups it breaks.
- **Split out:** the plan-time pre-build advisory —
  [[20260704-add-a-plan-time-blast-radius-advisory-to-jim-plan]] (#39). It
  fires on a prediction rather than an actual face edit and touches
  `/jim:plan`, so it follows the initiative's thin-slice pattern as its own
  follow-on.

## Depends on

Spec 029; ≥2 group blueprints to reconcile; and
[[20260630-build-intelligence-for-context-aware-spec-group-definition]]
(#19), which delivers `BLUEPRINT.md` — the artifact this graph lives in and
reconciles against. *Status 2026-07-04: #19 is closed — spec 033 shipped
`BLUEPRINT.md`, group roles/relations, and territory declarations. The only
remaining precondition is data, not build: a project with ≥2 group
blueprints.*
