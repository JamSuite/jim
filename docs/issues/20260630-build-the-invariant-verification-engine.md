---
id: 20260630-build-the-invariant-verification-engine
num: 22
title: "Build the invariant verification engine"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, verification]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-30T20:35:19Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/001-blueprint-spec/spec.md
---

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

- **Spec A — engine core** — ✅ **shipped as spec 035** (2026-07-05,
  `docs/specs/blueprint/007-verify-engine/`): `/jim:verify`, on-demand, one group;
  enum + `check:` format change; native floor (`skills/verify/scripts/jimverify.sh`);
  registry; judge rung; appetite knob; report/issues/ledger. Exercised on
  jim's own single-group repo. Swarm and blast-radius-scoped spend deferred to
  Spec B as planned.
- **Spec B — pipeline integration:** *split at scoping (2026-07-05) on
  feature/code-relationship grounds, as this bullet anticipated.*
  - **B1 — fold-back loop** — ✅ **shipped as spec 036** (2026-07-05,
    `docs/specs/blueprint/008-verify-loop/`): the `/jim:review` living-intent sensor
    (whole-group floor + change-selected judges, a separate `## Living intent`
    dimension that never sets the alignment verdict) and the 030/031 violation
    fork grounded in engine outcomes on **both** adapters (`--from-review` /
    `--since`), with an inline fallback sweep and fail-closed precedence.
    Exercised end-to-end on jim's own blueprint; jim's `000-blueprint` then
    regenerated to structured `check:` data (off the all-judge fallback).
  - **B2 — contract-graph integration** — ✅ **shipped as spec 037**
    (2026-07-05, `docs/specs/blueprint/009-verify-contracts/`): the engine's
    cross-group contract mode — 034's detectors (leak / breaking /
    dead-surface) code-grounded on both sides of each edge, a deterministic
    cross-reference floor (`contracts-check`), edge-generalized judges under
    the existing appetite knob, blast-radius-scoped spend at the
    boundary-change trigger, the review-sensor contracts subsection, and
    provides-entry criticality with the one-way ratchet. Detector-hardening
    and blast-radius stayed one spec, as scoping resolved.
- **Spec C — retirement direction** — ✅ **shipped as spec 041** (2026-07-08,
  `docs/specs/blueprint/013-verify-retirement/`): the on-demand `/jim:verify
  --retirement [<group>]` sweep runs the load-bearing sources in reverse,
  flagging stale invariants, stale requires entries, and dead surface — signal
  only, offered as issues, never written. A new `jimverify.sh scope-census`
  verb supplies the invariant staleness fact; the judge gains a third claim
  type; everything else composes over the existing verbs.

**All slices shipped — the invariant-verification-engine initiative (035 →
036 → 037 → 041) is complete; closing this issue.**

## Follow-through once the engine exists

- **Review as sensor.** With invariant checking available, `/jim:review` can
  verify code against the blueprint's *living* invariant set — not only the
  point-in-time numbered spec. Drift then means "divergence from living
  intent," with two resolutions: fix the code, or fold the learning into the
  blueprint. This is the natural moment to evolve review's lens; until then
  the blueprint stays a downstream consumer of review, never its reference.
  **Lens evolution deliberately deferred** (spec 036 scoping decision,
  2026-07-05): 036 ships the sensor with living-intent results as a
  *separate dimension* in `review.md` — the alignment verdict stays
  spec/plan-scoped, its vocabulary untouched, and living-intent results
  never set it. The deferred follow-on, gated on real-world sensor mileage:
  decide whether the alignment verdict should absorb living-intent drift
  (the lens-shift that re-defines "drift" as divergence from living
  intent). Any such evolution must contend with the verdict vocabulary
  being shape-validated on the ledger (`aligned` / `minor-drift` /
  `major-drift`, spec 028) — changing its semantics or values touches that
  extraction contract.
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

## New inputs from spec 034 (contract graph)

034 shipped (2026-07-05, `docs/specs/blueprint/006-contract-graph/`; origin
[[20260630-add-the-cross-group-contract-graph-and-blast-radius]], since closed)
and delivers the reconciled cross-group contract graph. Its two hand-offs
were consumed by **Spec B2** (spec 037):

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
