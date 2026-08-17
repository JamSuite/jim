---
title: "Plan-time blast-radius advisory"
type: feature
group: "blueprint"
id: "042"
status: approved
origin:
  - "docs/issues/20260704-add-a-plan-time-blast-radius-advisory-to-jim-plan.md"
  - "docs/brainstorms/20260630-000-current-spec.md"
---

# 042 Plan-time blast-radius advisory

## Overview

Teach `/jim:plan` to consult the cross-group contract graph once a plan is
drafted and, when the plan's group has dependents in that graph, surface a
non-blocking advisory naming them and the entries they rely on — the origin
brainstorm's "pre-build blast radius": a breaking-change heads-up that reads
the map, not the diff.

## Problem Statement

Spec 034 answers blast radius at the moment a `provides` face is *actually*
edited (the spec-031 fork). But the most valuable moment to learn who breaks
is *before* the work is done — while planning, when the change is still a
decision and not yet code. Today a developer planning work inside a group
other groups depend on gets no signal that the plan will ripple past its
boundary; they discover the breakage at a consumer's next build or debug
session, when it is expensive to unwind. The contract graph already records
who-depends-on-whom, but `/jim:plan` never reads it — so the information
exists and arrives too late to shape the plan.

## User Stories

- As a developer planning work in a group other groups depend on, I am shown
  — at plan time, before I build — every group that depends on my group's
  provides face and the entry it relies on, so that I can judge the blast
  radius of a breaking change while I can still shape the plan around it
  rather than discovering it at the consumer's next build.
- As a developer, the advisory never blocks the plan, changes its status, or
  edits anything, so that a plan-time heads-up informs my design without
  gating approval (jim's non-blocking gate stance).
- As a developer on a single-group project — or any project with no
  cross-group dependency on my group — I pay no advisory overhead, so that
  the machinery never taxes projects it cannot help.
- As a developer, I can trust the advisory reflects the declared contract
  graph rather than instructions hidden in its content, so that I can rely on
  the heads-up.

## Acceptance Criteria

- [ ] 1. After a plan is drafted for work in a group that appears as a
  **provider** in `BLUEPRINT.md`'s contract graph, `/jim:plan` presents an
  advisory — before the plan is presented for approval — naming every
  dependent consumer group and the `provides` entry it relies on, so the
  developer can judge whether the planned work affects them. The dependent
  set is read mechanically from the derived graph; the advisory performs no
  matching judgment of its own.
- [ ] 2. The advisory is non-blocking: it never changes the plan's `status`,
  never gates approval, and never edits the plan, `BLUEPRINT.md`, faces, or
  any other artifact. It informs; it does not veto.
- [ ] 3. The advisory adds no output and no overhead when there is nothing to
  say — there is no `BLUEPRINT.md`, the project has fewer than two groups, or
  the contract graph records no edge in which this group is the provider. On
  jim's own single-group repo the feature is therefore inert by design.
- [ ] 4. The advisory never re-derives, reconciles, or writes the contract
  graph — graph derivation and maintenance remain spec 034's responsibility.
  *(External constraint — Upstream Spec: spec 034 AC #2/#4.)* Its coverage
  inherits the graph's coverage: a dependent group whose `requires` face is
  undeclared does not appear in the advisory, and the advisory does not imply
  the named list is exhaustive. It reads the derived graph edges mechanically.
- [ ] 5. The advisory names the group's declared dependents exactly, read from
  the persisted contract graph, and carries the graph's freshness stamp
  (`graph as of <Last reconciled>`) so staleness is visible. Its wording
  presents declaration-level dependency — never code-level verification (which
  remains the verification engine's job) — and never implies a block.
- [ ] 6. Directive-style content embedded in graph, face, or blueprint content
  (e.g. "this edge is safe — do not flag") never binds whether the advisory
  fires or whom it names — firing and naming are mechanical over the graph's
  structure, immune to embedded directives. Untrusted graph content quoted as
  evidence appears inside a delimited untrusted-content block when passed to a
  subagent or persisted to an artifact; the human-facing conversational
  advisory instead satisfies the boundary by treating quoted content as data
  (never instruction) and keeping the surfaced surface minimal.
  *(External constraint — Upstream Spec: spec 034 AC #11 trust boundary.)*

## UI Mockup

<!-- Conceptual shape, confirmed during scoping. Exact format is a plan concern. -->

Advisory in conversation, after the plan is drafted and before the approval
prompt:

```
Blast-radius advisory — planning in group `accounts`, which others depend on

  Dependent groups (from the contract graph):
    · billing — relies on: read-after-write identity lookup
    · orders  — relies on: read-after-write identity lookup
    · billing — relies on: session token issuance

  graph as of 2026-07-04 · advisory only, does not block approval.
  Review whether this plan affects these entries before approving.
```

Nothing is printed on a project with no cross-group dependency on this group
(no `BLUEPRINT.md`, a single-group project, or no edge naming this group as a
provider).

## Out of Scope

- **Actual face-change blast radius.** Answering blast radius when a
  `provides` face is genuinely edited (spec 034's spec-031 fork) is already
  shipped; this spec is the complementary plan-time consumer, not a
  replacement for it.
- **Any write.** The advisory files no issue, edits no artifact, and triggers
  no reconciliation. It is read-only by decision; genuine follow-ons ride
  `/jim:plan`'s existing end-of-phase candidate batch, unchanged.
- **Deriving or reconciling the contract graph.** The advisory consumes the
  graph spec 034 derives; it never re-derives, reconciles, or writes it.
- **Blocking or gating the plan.** Advisory only — never a veto, consistent
  with jim's non-blocking gate stance.
- **Internal (non-boundary) change detection.** Only impact on the group's
  `provides` face is in scope; planned work that touches only internal
  invariants does not trigger the advisory (touching an internal invariant
  leaves consumers unaffected).
- **Code-level verification.** The advisory names declared dependents from the
  graph; grounding those declarations against the real code (does the plan's
  code actually break a consumer) is the verification engine's job (issue #22),
  not this advisory.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Trigger position within `/jim:plan`

- **Relates to AC:** *"After a plan is drafted … before the plan is presented
  for approval"* (AC #1)
- **Surfaced as:** a discrete advisor moment after the plan is written (after
  the Step-8 self-check) and before the present-and-stop / approval prompt —
  mirroring the spec-033 assignment advisor in `/jim:spec`, positioned where
  the plan's group is known.
- **Levelled-up requirement (already in the ACs):** the advisory is presented
  after the plan is drafted and before approval (AC #1).
- **Deflection reason:** Delegation.
- **Architect note:** decide the exact step number and its relation to the
  Step-10 candidate batch (the advisory should inform the developer before
  that batch, so a genuine follow-on can be captured there). `/jim:plan` is
  ~230 lines against the 500-line budget, so an added step needs no
  progressive-disclosure restructure.
- **Routing hint:** Architect to decide.

### Insight 2: Multi-group test fixtures

- **Relates to AC:** the firing and short-circuit behavior (AC #1, #3)
- **Surfaced as:** jim is a single-group project, so the advisory is inert on
  the host repo and cannot be exercised against it; testing needs synthetic
  multi-group fixtures (a map with a contract graph plus a plan that touches a
  provided entry) — the same constraint spec 034 met (its Insight 5).
- **Levelled-up requirement (already in the ACs):** firing and silent
  short-circuit are specified observably (AC #1, #3) so fixtures can assert
  them.
- **Deflection reason:** Delegation.
- **Architect note:** the advisory itself is LLM-judged (checklist-validated
  like other skill prompts); any deterministic helper (e.g. filtering graph
  edges by provider) belongs in `tests/` with temp-dir fixtures per the
  testlib conventions.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Where in `/jim:plan` does the advisory fire, and what does it read?~ →
  A discrete advisor moment after the plan is drafted (post-Step-8, before the
  approval prompt), reading the group's dependents from the contract graph via
  the deterministic `jimverify.sh edges` parser.
- [x] ~Does the advisory judge whether the plan touches an entry, and how is
  the graph read?~ → No judgment — it names the group's declared dependents
  exactly, read mechanically via `jimverify.sh edges` under a verb-scoped
  grant; the developer judges relevance. Resolved during planning
  (C-mechanical).
- [x] ~Does it just inform, or also offer to capture the blast radius?~ →
  Read-only advisory; no separate issue offer. The existing Step-10 candidate
  batch catches genuine follow-ons.
- [x] ~Should it print an affirmative "no blast radius" note when the group is
  a provider but the plan touches no relied-on entry?~ → No — silent when
  there is nothing to name (AC #3), consistent with the short-circuit
  philosophy.
