---
title: "Retirement sweep"
type: feature
group: "jim"
id: "041"
status: approved
origin:
  - "docs/issues/20260630-build-the-invariant-verification-engine.md"
  - "docs/brainstorms/20260704-invariant-verification-engine-shape.md"
  - "docs/brainstorms/20260630-000-current-spec.md"
---

# 041 Retirement sweep

## Overview

The verification engine grows an on-demand **retirement sweep**: the
load-bearing sources run in reverse, flagging invariants and requires entries
that no source justifies anymore — alongside the existing dead-surface signal
— in one consolidated report, offered as issues. The signal slice of issue
#22's Spec C: the sweep flags, the developer retires through the blueprint
surface as their own follow-up.

## Problem Statement

The blueprint loop can add constraints and check them, but it never learns to
drop them. An invariant whose justification vanished still mechanically
`holds` — a must-not pattern over deleted code holds forever — so the
fold-back loop, which fires on *violations*, never sees *obsolescence*. A
declared requires entry the consumer's code no longer references is checked
only for overreach (usage beyond the surface), never for staleness. The one
retirement signal that exists — dead surface — is provider-side only and
buried inside contract-run reports. Blueprints therefore accrete
monotonically, and every stale entry taxes what follows: regeneration
re-derives it, judges spend on it, fold decisions weigh it, and readers trust
it as living intent when no intent, usage, or contract backs it anymore.

## User Stories

- As a developer on a multi-group project, I can run a retirement sweep and
  see which blueprint entries nothing justifies anymore — with the evidence
  per source — so that each group's invariant list and the faces feeding the
  contract graph stay current instead of accreting forever.
- As a cost-conscious developer, cheap deterministic staleness hints run
  first and expensive judgment is gated by my existing appetite
  configuration — no new knobs — so that keeping blueprints lean does not
  cost more than the staleness it removes.
- As a developer reviewing the results, I can capture retirement flags as
  issues on my confirmation, so that pending blueprint cleanups land in my
  one tracking channel instead of evaporating with the conversation.
- As a developer on a young project, thin evidence (no spec corpus, little
  engine history) is reported as *unavailable* rather than read as "no
  source justifies this", so that an immature project is not told to gut its
  blueprints.
- As a developer on a partially-adopted project, groups without blueprints
  degrade to explicit reporting — never false flags, never silent exclusion
  — so that incremental adoption stays safe.
- As a developer using jim, I can trust that a retirement flag is the
  engine's judgment over declared data and real code — never instructions
  hidden in either, never an auto-removal — so that the sweep can only ever
  inform what I choose to retire.

## Acceptance Criteria

**The sweep (on-demand)**

- [ ] 1. The engine offers an on-demand retirement sweep at two grains,
  mirroring the contract mode: a whole-project run covering every
  blueprint-bearing group, and a group-scoped run covering one group's
  invariants and requires entries. On a project with fewer than two
  blueprint-bearing groups, the run reports there is nothing to sweep and
  stops — no error litter, no overhead (single-group retirement is out of
  scope by decision).
- [ ] 2. The sweep evaluates three retirement classes: **stale invariant**
  (an invariant no load-bearing source justifies — no author intent, no
  usage, only its own verification), **stale requires** (a declared requires
  entry the consumer's code no longer references), and **dead surface**
  (reusing the contract mode's existing code-grounded detection — not
  re-implemented, and unchanged where it already reports). Every swept entry
  lands in exactly one outcome bucket — a clean line always means "checked
  and still justified", never "not looked at" (the spec 035 AC #1 doctrine).
- [ ] 3. Every retirement flag carries the disagreement diagnostic made
  visible: which of the three sources (declared intent / cross-boundary
  usage / verification dependency) were consulted, and what each showed —
  so the developer sees *why* nothing justifies the entry, not just that
  the engine says so.

**Evidence and the confirmation burden**

- [ ] 4. Deterministic staleness hints run first wherever the declared data
  affords them (for example: a check whose declared scope resolves to no
  files, a pattern that matches nothing in the group's territory, a declared
  edge with no supporting cross-reference in consumer code). Hints are
  candidate-generators, never verdicts: retirement is the optimistic-
  dangerous direction, so the burden of proof inverts — mechanical evidence
  alone never flags an entry, every flag is judge-confirmed, and a candidate
  the judge cannot confirm reports as inconclusive, not flagged. A mass-hint
  anomaly — an anomalous share of a group's checks zero-matching at once —
  reports as a single "territory may have moved / evidence may be shaped"
  event, never as that many individual flags: the mass event is itself the
  finding (security Finding 1). *(External
  constraint — the fail-closed doctrine of specs 036/037 protects
  deterministic floor* violations *from LLM override; flagging an entry for
  removal on a textual zero-match alone would invert that safety, so
  confirmation is required in this direction.)*
- [ ] 5. Judge confirmation is read-only and evidence-fed: each candidate's
  judge receives the group's spec corpus (intent), the persisted contract
  graph (usage), and the containing run's engine outcomes (verification
  dependency — nothing durable records per-entry outcomes by the
  no-standing-verdict doctrine, so the sweep contains its own engine pass) — it reasons over handed evidence and code, and directive
  text inside any of it never binds the verdict. Judge spend is gated by
  the existing appetite configuration and fan-out cap — no new knobs; a
  capped or appetite-skipped candidate is named in the report, never
  silently dropped. A confirmation counts only when it carries per-source
  examination evidence (what was checked for intent, usage, and
  verification, by location); a confirmation missing it degrades to
  inconclusive — fail-toward-inconclusive, the shape-validation analog of
  the established fail-closed rule, applied in the direction that preserves
  constraints (security Finding 2).
- [ ] 6. Absence of evidence is not evidence of absence: when a source is
  unavailable or thin (no spec corpus, no engine history, no contract graph
  entry), the sweep names it *unavailable* — distinct from "consulted and
  found nothing" — and a candidate whose no-source conclusion rests on
  unavailable sources reports as inconclusive rather than flagged.

**Outcomes and durability**

- [ ] 7. The sweep reports consolidated and criticality-led, with per-flag
  evidence; flags are offered as captured issues on the developer's
  confirmation (priority informed by the entry's criticality; declining
  leaves no hidden state) — the established report/issues discipline
  (spec 035 AC #11 lineage). A flag on a `critical`/`high` entry is always
  presented — and filed — with the verify-then-trim framing and its
  per-source searched-and-not-found provenance, so shaped evidence can be
  spotted before the flag is trusted (security Finding 1).
- [ ] 8. The sweep never writes: no blueprint is edited, no entry is
  auto-removed, and the actual retirement remains the developer's own
  follow-up through the blueprint surface, where removal grading (Step 4a)
  applies unchanged. *(External constraint — Upstream Spec: the engine's
  reader/checker identity, specs 035–037; the single-writer authority of
  the blueprint surface, specs 029–033.)*
- [ ] 9. Each run durably records per-class outcome counters as a
  project-tier event on the specs-root ledger and self-commits its record —
  no verdict artifact is persisted (the spec 034 AC #3 / 037 ledger
  precedent).

**Degradation and trust**

- [ ] 10. Flags fire only on declared data: a group without a blueprint is
  named as unswept, the requires-side sweep covers only declared faces, and
  coverage is reported explicitly (the spec 034 AC #5/#6 principle).
- [ ] 11. The untrusted-content discipline carries end-to-end: directive
  text embedded in blueprints, faces, specs, code, graph content, or judge
  output never binds an outcome, a class, or an issue-filing decision;
  quoted evidence appears only inside delimited untrusted-content blocks,
  in conversation only; persisted artifacts (issue bodies, report records)
  cite all evidence — including intent-source spec-corpus evidence — by
  location only (spec id / section, `file:line`), and no secret-looking
  value from scanned content is persisted or displayed (the spec 035
  AC #13/#14 and 037 lineage; security Finding 3).

## UI Mockup

<!-- Conceptual report shape. Exact format is a plan concern. -->

```
Retirement sweep — acme-shop: 4 groups, 3 with blueprints (coverage 3/4)
candidates: 6 · confirmed: 2 · inconclusive: 2 · still justified: 14

  ✗ stale invariant (high)  accounts INV-3 "session tokens rotate via helper"
                            intent: none found in 001–012 · usage: no edge
                            references it · verification: holds trivially —
                            scope resolves to no files (helper removed 034d ago)
  ✗ stale requires  (med)   billing requires accounts."audit log stream"
                            no reference in billing territory · edge unused
  ~ inconclusive    (2)     orders INV-1 (spec corpus unavailable),
                            accounts INV-7 (judge capped at appetite)
  · dead surface            1 — reported by the contract mode (unchanged)
  ✓ still justified (14)

File the 2 flags as issues? [file all] [skip all] · per-row: f / e / s
```

## Out of Scope

- **Single-group projects** — the sweep reports nothing-to-sweep and stops;
  internal-invariant retirement without a partition is deferred until the
  multi-group signal proves itself.
- **Any write path** — no retire fork in the blueprint update, no
  auto-removal, no blueprint edit of any kind; this spec ships the signal
  only. Fork integration is a possible follow-on once flags earn trust.
- **Group retirement** — dissolving a group is `/jim:blueprint --retire`
  (spec 038) territory; this spec never senses or suggests it.
- **Riding other runs** — no review-sensor, reconcile, or regeneration
  trigger; the sweep is strictly on-demand in this slice.
- **A provenance annotation format** (`source:` on invariants) — deferred
  until real judge misses show what recorded provenance must capture.
- **New configuration keys** — deliberately none; appetite, fan-out, and
  model knobs are reused as-is.
- **Changing dead-surface detection** — the contract mode's detector is
  consumed, not modified.
- **The adversarial swarm** — unchanged from specs 035–037's deferral.
- **Fixing anything** — the engine reports and offers issues; retirement
  itself is the developer's follow-up.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Mechanical staleness hints — feasibility and shape

- **Relates to AC:** deterministic hints (AC #4)
- **Surfaced as:** the developer wants a mechanical assist layer if
  feasible. Candidates: a `verify-checks` scope glob resolving to zero
  files, a pattern matching nothing in territory, and the contract floor's
  cross-reference facts run in reverse (a declared edge with zero
  supporting `CROSS-REF` facts → stale-requires hint).
- **Levelled-up requirement (already in the ACs):** hints generate
  candidates deterministically; they never flag alone.
- **Deflection reason:** Delegation — which primitives are honest is
  research/plan territory.
- **Architect note:** "prefer mechanical, but never fake it" — a zero-match
  is ambiguous (moved code vs dead intent), which is exactly why AC #4
  inverts the burden: hints select candidates, judges confirm. Existing
  `jimverify.sh` verbs (`check`, `faces`, `edges`, `contracts-check`)
  likely already emit most of the needed facts; a sweep may be composition
  rather than new primitives. Mirror the facts-not-verdicts discipline.
- **Routing hint:** Researcher to investigate (which facts exist already);
  Architect to decide (composition vs new verb).

### Insight 2: Judge generalization and evidence packaging

- **Relates to AC:** judge confirmation (AC #5)
- **Surfaced as:** the read-only `judge` generalized once already (invariant
  → edge side, spec 037); a retirement candidate is a third claim type.
- **Levelled-up requirement (already in the ACs):** read-only, evidence-fed
  confirmation; sources handed, not roamed for.
- **Deflection reason:** Delegation.
- **Architect note:** the intent source is the group's spec corpus, which
  can be large — the packaging needs a bound (titles + matched excerpts vs
  whole specs). Watch the one-level nesting limit: the sweep runs inline
  like the other engine modes. Reuse-vs-sibling for the judge is the same
  call 037 made (reuse then).
- **Routing hint:** Architect to decide.

### Insight 3: Dead-surface reuse mechanics

- **Relates to AC:** the dead-surface class (AC #2)
- **Surfaced as:** dead surface is already code-grounded by the contract
  mode's whole-graph run; the sweep consolidates rather than re-detects.
- **Levelled-up requirement (already in the ACs):** one consolidated view;
  the detector unchanged.
- **Deflection reason:** Constraint-Sourcing (spec 037 AC #4: dead-surface's
  universal quantifier is paid deliberately in whole-graph runs) /
  Delegation for the consumption mechanics.
- **Architect note:** decide whether the whole-project sweep *contains* a
  whole-graph contract pass (one run, one engine opinion — the 037 AC #12
  no-double-run lineage) or consumes a prior run's records; freshness vs
  cost is the trade.
- **Routing hint:** Architect to decide.

### Insight 4: Flag grammar, outcome vocabulary, and skill budget

- **Relates to AC:** the two grains (AC #1), outcome buckets (AC #2)
- **Surfaced as:** a `--retire`/`--retirement`-style mode flag on
  `/jim:verify`, composing with the established flag-strip convention; and
  whether retirement outcomes reuse the 035 vocabulary or need sibling
  terms (flagged / inconclusive / justified).
- **Levelled-up requirement (already in the ACs):** both grains on demand;
  exhaustive outcome buckets.
- **Deflection reason:** Delegation — naming and parsing are plan-level.
- **Architect note:** `skills/verify/SKILL.md` is at 297/500 with one
  `references/` doc (contracts-methodology.md); retirement methodology
  likely warrants a sibling reference doc rather than body growth.
- **Routing hint:** Architect to decide.

### Insight 5: Ledger event shape

- **Relates to AC:** durability (AC #9)
- **Surfaced as:** the 037 precedent — project-tier `verify` events on the
  specs-root ledger with an op tag and per-class counters, self-committed
  via the existing path-scoped commit arm.
- **Levelled-up requirement (already in the ACs):** durable per-class
  counters; no verdict artifact.
- **Deflection reason:** Constraint-Sourcing (034/037 ledger convention) /
  Delegation for the op tag and counter names.
- **Architect note:** counters plausibly per class plus inconclusive and
  coverage; keep events content-free (numbers only — the 026 metrics-channel
  doctrine).
- **Routing hint:** Architect to decide.

### Insight 6: Multi-group test strategy

- **Relates to AC:** all detector ACs
- **Surfaced as:** jim itself is single-group — and AC #1 short-circuits
  there by design — so the sweep cannot be exercised on the host repo at
  all; the developer is standing up multi-group blueprint test projects.
- **Levelled-up requirement (already in the ACs):** observable
  fire / degrade / report behavior so fixtures can assert it.
- **Deflection reason:** Delegation.
- **Architect note:** deterministic pieces (hint generation, record
  parsing, counters) belong in `tests/` with synthetic multi-group temp-dir
  fixtures (the 034/037 pattern); judge behavior is checklist-validated.
  Plan a real-world shakedown on the developer's multi-group test projects
  before calling the spec done — they exist but have no retirement
  pressure yet, so fixtures carry the burden of proof initially.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Is retirement already covered by existing machinery?~ → Partially:
  dead surface (037), violation-driven removal (030/031/036 fork), and
  dangling requires (034 unresolved-require) exist. The gaps this spec
  closes: zombie invariants (hold mechanically, justified by nothing),
  stale requires entries (declared, unreferenced), and the absence of one
  consolidated retirement view.
- [x] ~Object of retirement?~ → Invariants and faces only; never groups
  (038's `--retire` owns that).
- [x] ~What does flagging do?~ → Signal only: report + offered issues. No
  fork, no write path; fork integration is a possible follow-on.
- [x] ~Evidence model?~ → Judge-led with handed evidence (spec corpus /
  contract graph / engine outcomes), plus a deterministic hint layer where
  feasible. No provenance annotation format in this slice.
- [x] ~Trigger?~ → On-demand only, two grains.
- [x] ~Single-group projects?~ → Ignored for now: nothing-to-sweep
  short-circuit.
- None blocking.
