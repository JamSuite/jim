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
updated: 2026-07-04T20:32:09Z
origin: docs/specs/jim/029-blueprint-spec/spec.md
---

## Description

## Context

Deferred slice of the `000-blueprint` initiative (spec 029). 029 records each
invariant's criticality + intended verification method but runs nothing.

**Shape resolved 2026-07-04** in
`docs/brainstorms/20260704-invariant-verification-engine-shape.md` — that
brainstorm supersedes the framing below where they differ, and slices the
work A → B → C (see Slicing).

## What

Execute the recorded verification methods to **check code against a group's
blueprint**:

- A fixed cheap **floor** (always-on mechanical checks) plus a tunable
  expensive **ceiling** (tests / judges / adversarial swarm).
- The invariant's type picks the rung; appetite is a config knob keyed off
  **criticality** (verify critical invariants hard, low ones cheaply), with a
  global default and a **per-group override** (spend hard on `auth`, lightly
  on `dashboard`).
- Detection fans out (per region / layer / invariant); the contract the swarm
  checks IS the blueprint's invariant set.

## Resolved shape (brainstorm, 2026-07-04)

- **Data→execution boundary:** closed method enum; inert parameters (grep
  patterns, globs, judge prompts) consumable from the blueprint; executable
  commands referenced **by name only** and activated through an
  operator-owned `verify_commands` registry in config — the blueprint
  proposes, only the operator's config channel activates. No relaxation knob.
- **Three-tier floor:** (1) jim-native zero-config primitives
  (pattern / structure / containment — containment is 033's territory
  enforcement) in a deterministic `jimverify.sh`; (2) registry-activated
  project tooling (lint / type / test — AST is explicitly *not* a jim
  capability, only a hook); (3) LLM rungs (judge, swarm) as the
  criticality-gated ceiling and universal fallback. Progressive upgrade:
  every invariant is at minimum judge-able; structured `check:` data
  upgrades it to mechanical.
- **Format reach-back:** the blueprint invariant table's method column
  becomes a structured, optional `check:` annotation — shipped *inside* the
  engine spec; existing blueprints degrade gracefully to the judge rung.
- **Surface:** a new skill, **`/jim:verify`** — reader/checker identity,
  never a blueprint writer; runs inline (one-level nesting preserved for the
  judge fan-out); triggers wire via inline `Skill()` calls.
- **No persisted verdict artifact** (034 AC #3 doctrine): report at run
  time, findings → offered issues, outcomes → ledger counters.

## Slicing

- **Spec A — engine core** (first): `/jim:verify`, on-demand, one group;
  enum + `check:` format change; native floor; registry; judge rung;
  appetite knob; report/issues/ledger. Fully exercisable on jim's own
  single-group repo. Swarm and blast-radius-scoped spend deferred.
- **Spec B — pipeline integration:** review-as-sensor (fix-code /
  fold-intent wired to the 030/031 fork); 031 fork hardening; 034 detector
  hardening; blast-radius-scoped ceiling. Needs multi-group fixtures or a
  real multi-group project; split review-sensor vs detector-hardening if it
  balloons at scoping.
- **Spec C — retirement direction** (last): the reverse load-bearing-source
  analysis below.

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

## New inputs from spec 034 (contract graph), once it ships

034 (in scoping, from [[20260630-add-the-cross-group-contract-graph-and-blast-radius]])
delivers the reconciled cross-group contract graph; two hand-offs land here:

- **Blast radius scopes the fan-out.** The graph names the groups a boundary
  change affects, so this engine's expensive ceiling can spend on
  blast-radius-affected groups instead of fanning out blindly — the
  criticality knob picks how hard, the graph picks where.
- **Contract edges are checkable invariants.** 034's detectors
  (leak / dead surface / breaking change) are LLM-judged reconciliation; this
  engine is where those checks can be hardened mechanically, the same way
  spec 031 notes its violation-fork detection awaits hardening here.

## Depends on

Spec 029 (which records the invariants + methods); spec 033
(`BLUEPRINT.md`, territory declarations, and the `valid-relpath` gate).
