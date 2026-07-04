---
id: 20260630-build-the-invariant-verification-engine
num: 22
title: "Build the invariant verification engine"
status: open
priority: medium
labels: [000-blueprint, verification]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-30T20:35:19Z
updated: 2026-07-04T00:40:56Z
origin: docs/specs/jim/029-blueprint-spec/spec.md
---

## Description

## Context

Deferred slice of the `000-blueprint` initiative (spec 029). 029 records each
invariant's criticality + intended verification method but runs nothing.

## What

Execute the recorded verification methods to **check code against a group's
blueprint**:

- A fixed cheap **floor** (always-on mechanical checks — lint / type / AST) plus
  a tunable expensive **ceiling** (tests / judges / adversarial swarm).
- The invariant's type picks the rung; appetite is a config knob keyed off
  **criticality** (verify critical invariants hard, low ones cheaply), with a
  global default and a **per-group override** (spend hard on `auth`, lightly
  on `dashboard`).
- Detection fans out (per region / layer / invariant); the contract the swarm
  checks IS the blueprint's invariant set.

## Follow-through once the engine exists

- **Review as sensor.** With invariant checking available, `/jim:review` can
  verify code against the blueprint's *living* invariant set — not only the
  point-in-time numbered spec. Drift then means "divergence from living
  intent," with two resolutions: fix the code, or fold the learning into the
  blueprint. This is the natural moment to evolve review's lens; until then
  the blueprint stays a downstream consumer of review, never its reference.
- **Retirement direction.** The load-bearing sources (declared intent /
  cross-boundary usage / verification dependency) also run in reverse: an
  invariant no source justifies anymore is flagged for retirement — the
  disagreement diagnostic lets the loop *drop* constraints, not only add and
  check them (e.g. verification asserts it, but no intent or usage backs it →
  stale / over-fit).

## New inputs from spec 033 (context map)

033 shipped the project tier and explicitly deferred enforcement here:

- **Territory enforcement.** `BLUEPRINT.md` records per-group code territory
  as data only (spec 033 AC #8). This engine is the consumption-time
  backstop: re-validate territory paths at use (`jimfile.sh valid-relpath`
  is the capture-time gate to reuse) and scope the mechanical floor checks
  by each group's declared territory.
- **The map tier is a second checkable artifact.** Roles, relations, and
  territories in `BLUEPRINT.md` are invariant-class content, and the
  `group_territory` mode sets the strength and price of this engine's
  mechanical floor (`directory` strongest; `declared-paths` mid;
  `none` degrades to LLM-judged) — spec 033, security Findings 4/9.

## Depends on

Spec 029 (which records the invariants + methods); spec 033
(`BLUEPRINT.md`, territory declarations, and the `valid-relpath` gate).
