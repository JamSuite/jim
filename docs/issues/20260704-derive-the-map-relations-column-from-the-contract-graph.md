---
id: 20260704-derive-the-map-relations-column-from-the-contract-graph
num: 40
title: "Derive the map Relations column from the contract graph"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, cross-group, architecture]
relations:
  blocks: []
  depends-on: [20260630-add-the-cross-group-contract-graph-and-blast-radius]
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T07:02:15Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/006-contract-graph/research.md
---

## Context

Surfaced during spec 034 research (see origin). After 034, `BLUEPRINT.md`
*appears* to carry who-depends-on-whom twice: the hand-declared per-group
Relations column (spec 033) and the derived cross-group contract graph
(spec 034). 034 scoped in the *check* — a mechanical pair-set diff yielding
stale-relation / undeclared-relation findings — but deliberately kept the
column hand-declared.

## The decision

Whether the Relations column should become a **derived view** of the contract
graph, retiring the hand-declared column, rather than policing the two against
each other.

## Reframe before deciding — the two are not the same fact

Treating this as "the same edge stored twice" pre-supposes the answer. Per
spec 033 the two channels mean different things:

- **Declared Relations = intent.** "Group A *should* depend on Group B" — a
  normative assertion written at map creation.
- **Derived contract graph = observed reality.** "Group A's blueprint requires
  something Group B's face provides" — descriptive, extracted from the faces.

They share a *shape* (a group-edge pair-set) but not a meaning, and that
distinction is load-bearing: the 034 check has value precisely *because*
intent and reality can diverge — the divergence is the signal. Deriving the
column from the graph makes the two identical by construction, which silently
deletes the check's ability to ever fire. So the "derived from the faces,
never re-declared" doctrine — sound for genuine *descriptions* of the faces
(the graph itself, ARCHITECTURE.md's partition reference) — does not transfer
automatically to a column whose spec-033 role is *intent*. Intent is an input,
not a derivable output.

## The real hinge (empirical)

Does the declared column ever hold a value that is meaningfully and
deliberately *different* from the derived graph? The strongest case for keeping
it hand-declared is **forward-looking intent** — a planned dependency not yet
wired, which only the declared column can express. If in practice the declared
column always just chases the graph one reconcile behind, it is pure toil and
should be derived. Which world we are in is an empirical question, answerable by
observing declared-vs-derived divergence across real multi-group partitions —
jim's blueprint audience — which accrues as those projects run. Low because it
wants that observation, not because the evidence is out of reach.

Frame the eventual decision as **"is this column intent, or a lagging mirror of
reality?"** — not "how do we remove the redundancy."

## Caution on the hybrid

A hybrid lifecycle — hand-declared at map creation, derivation taking over once
faces exist and the first reconcile lands — is tempting because it resolves the
bootstrap wrinkle: at creation there are no group blueprints, so there is
nothing to derive from and the declared column is the assignment advisor's
day-one input. But it yields a column whose *meaning* changes over time (intent
on day one, observed reality thereafter), unreadable without knowing each
group's reconcile history. Prefer committing to one pure semantics: if the data
says derive, drop the intent semantics from this column outright and give
forward-looking intent a different home (or decide it needs none) rather than
straddling.

## Scope note

Amends 033's shipped column-authorship semantics, so it deserves its own
deliberate decision informed by multi-group practice — not a drive-by change.

## Depends on

Spec 034 shipping (the graph to derive from), via
[[20260630-add-the-cross-group-contract-graph-and-blast-radius]] (#21); and
observed declared-vs-derived divergence across real multi-group partitions —
available as consumer projects run, not a blocker.
