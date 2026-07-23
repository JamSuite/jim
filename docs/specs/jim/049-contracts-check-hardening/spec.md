---
title: "Harden contracts-check: blueprint-slot resolver, self-edge guard, edge-outcome tests"
type: refactor
group: "jim"
id: "049"
status: approved
origin:
  - docs/issues/20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin.md
---

# 049 Harden contracts-check: blueprint-slot resolver, self-edge guard, edge-outcome tests

## Overview
A single hardening pass on the verify engine's cross-group contract floor: route
the `000-blueprint` slot through the one resolver that owns it (dropping the
now-redundant `<specs-root>` arg it strands), stop a self-referential edge from
reading as a cross-group contract or a health cycle, and pin the two edge-outcome
behaviors that currently have no test.

## Refactor Rationale

- **Motivation:** The spec 037 post-build living-intent sensor flagged an
  in-change violation of the `blueprint-slot-reserved` invariant — the
  cross-group contract floor derives the `000-blueprint` path by hand,
  duplicating the slot convention the single resolver owns. Folded with it:
  a self-referential edge (consumer == provider) currently reads as a real
  cross-group contract *and* as a one-node health cycle, and the edge-outcome
  path has two untested behaviors (consumer abstain, location-only evidence).
  All four concerns cluster in the same three functions, so they land in one
  pass rather than four.
- **Current State:**
  - The verify engine composes `<specs-root>/<group>/000-blueprint/spec.md`
    inline at three sites — the contract floor's coverage loop and per-edge
    outcome loop, plus the faces-aggregate pass — each duplicating the
    reserved-slot convention that a single path resolver already owns. The
    `blueprint-slot-reserved` invariant is script-wide, so all three copies
    are in scope; leaving any hand-derived means the invariant still does not
    hold.
  - The `<specs-root>` positional that `cmd_contracts_check` and
    `cmd_faces_aggregate` accept is used *only* to compose those blueprint
    paths, and in every call path it equals the config specs-root (production
    passes `jimfile.sh get specs`; tests pass the default `docs/specs`). Routing
    the path through the config-sourced resolver therefore strands the arg — it
    would carry no information the resolver does not already have.
  - The Contract Graph parser emits any `consumer | relies | provider` row
    whose endpoints are valid slugs — including a self-pair where consumer and
    provider are the same group. Both the per-edge outcome loop and the graph
    health metrics consume that parser, so a self-edge produces contract
    outcome records and is counted as a one-node cycle cluster. (The CROSS-REF
    reference scan already skips self-pairs; the edge-outcome and health paths
    do not.)
  - No test asserts that a consumer which declares a contract but does not
    exercise the declared surface *abstains* (emits no outcome record), and
    none asserts that edge-outcome evidence is location-only — the same
    exfiltration guard the CROSS-REF path already has under test.
- **Desired State:**
  - Every `000-blueprint` path the contract floor uses is produced by the
    single reserved-slot resolver; no hand-composed slot string remains in the
    script, so a future change to the slot name or layout is inherited without
    editing the floor.
  - A self-edge is excluded from cross-group contract outcomes and from the
    health edge count and cycle clustering — consistently across both consumers
    — and the exclusion is *visible* in output (a HYGIENE row), never a silent
    drop.
  - The now-redundant `<specs-root>` positional is removed from
    `cmd_contracts_check` / `cmd_faces_aggregate`, and their callers (the verify
    skill, its methodology docs, and the tests) use the shorter signatures — no
    dead parameter is left behind.
  - The consumer-abstain and location-only edge-outcome behaviors are pinned by
    tests.
- **Affected Systems:** `skills/verify/scripts/jimverify.sh`
  (`cmd_contracts_check`, `cmd_faces_aggregate`, `cmd_edges`, `cmd_health`,
  `contract_ref_check`); `tests/jimverify.sh`;
  `skills/verify/SKILL.md` and
  `skills/verify/references/{contracts-methodology,retirement-methodology}.md`
  (the invocation signatures).

## Acceptance Criteria

- [ ] Every `000-blueprint` path the verify engine composes is produced by the
      single reserved-slot resolver; no hand-composed `…/000-blueprint/spec.md`
      string remains in `jimverify.sh` (all three sites).
- [ ] The engine's output over existing fixtures is unchanged by the resolver
      switch — the change is structural, not behavioral.
- [ ] The now-redundant `<specs-root>` positional is removed from
      `contracts-check` and `faces-aggregate`; their callers — the verify skill,
      its methodology docs, and the test invocations — use the new signatures,
      leaving no dead parameter behind.
- [ ] A contract-graph edge whose consumer and provider are the same group
      produces no provider-side or consumer-side outcome record and no CROSS-REF
      record.
- [ ] Such a self-edge is surfaced as a HYGIENE row — the exclusion is visible
      in output, not silent.
- [ ] A self-edge is excluded from the health edge count and never forms a cycle
      cluster (a self-dependency never reads as a one-node cycle).
- [ ] A fixture whose consumer declares a contract but lacks the declared usage
      asserts the consumer side emits no edge record — neither a violation nor a
      failure.
- [ ] A test asserts edge-outcome evidence is location-only (path and line
      only), never matched source content.
- [ ] The refactor preserves behavior: existing test assertions and fixtures
      pass unchanged, except mechanical call-site updates for the new signatures
      and the `missing-args` arity assertion — no assertion is weakened to
      accommodate the change.

## Out of Scope

- The duplicate-row concern from issue #64 (repeated CROSS-REF rows for the same
  consumer→provider pair) — untouched by the self-edge doctrine; it stays
  tracked in #64.
- Any change to the CROSS-REF per-pair emission cap or its capping signal.
- Self-edge handling beyond the exact consumer == provider case (no change to
  genuine cross-group edge semantics).
- Any new health metric, threshold, or verdict — health stays measurement-only.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: where the self-edge guard lives

- **Relates to AC:** *"a self-edge is excluded from contract outcomes and from
  health, consistently, and surfaced as a HYGIENE row"* (the self-edge ACs).
- **Surfaced as:** the origin issue's "layer decision" — place the
  `consumer == provider` skip at the shared graph-parse root (so both the
  edge-outcome loop and the health metrics inherit it) versus guarding each
  consumer independently.
- **Levelled-up requirement (already in the ACs):** the ACs require *consistent,
  non-silent* exclusion across both consumers — they deliberately do not name a
  layer.
- **Deflection reason:** Delegation — the placement is the architect's call, so
  long as the observable end-state (ACs) holds.
- **Architect note:** guarding at the shared graph-parse root — emitting a
  HYGIENE row for a valid-slug self-pair instead of an edge row — makes both the
  edge-outcome loop and the health metrics inherit the exclusion in one place,
  since both already skip HYGIENE rows; it likely makes a per-loop self-pair
  `continue` redundant. The CROSS-REF loop's existing self-pair skip is a local
  precedent to weigh against a single-root guard. If the guard is instead
  dropped lower, the HYGIENE-surfacing and health-exclusion ACs must each be
  satisfied on their own path.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~What is the observable behavior when a self-edge is encountered?~ →
      Drop it from cross-group contract outcomes and surface it as a HYGIENE
      row (name-every-degradation doctrine).
- [x] ~What should health report for a self-dependency once guarded?~ →
      Nothing extra — the self-edge is excluded upstream, so no edge count and
      no cycle cluster; it is surfaced once, at the HYGIENE layer.
- [x] ~Should the spec pin where the guard lives?~ → No — the spec states the
      observable end-state; placement is deferred to the plan (Insight 1).

None outstanding.
