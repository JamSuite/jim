---
title: "Partition-health sensors"
type: feature
group: "jim"
id: "044"
status: approved
origin:
  - "docs/issues/20260704-add-partition-health-sensors-split-merge-signals.md"
  - "docs/issues/20260711-add-a-territory-name-mismatch-partition-health-sensor.md"
---

# 044 Partition-health sensors

## Overview

Partition-health sensors interpret the reconcile ledger's accumulated
measurements and the current map to detect a partition gone bad — split/merge
smells and the territory-name mismatch — delivering a reasoned, advisory
proposal whose remedy pointer is `/jim:partition`. The check runs ad hoc on
demand and hooks into the pipeline at reconcile end behind operator-set
thresholds with `require_health` / `auto_health` knobs.

## Problem Statement

The machinery now *records* partition quality on every reconcile — spec 034's
finding counters and spec 039's graph-health measurements — and
`/jim:partition` (spec 038) is the standing remedy, but nothing *reads* the
accumulating trend. A partition can degrade — a rising cycle count, a
fattening provides face, chronic breaking-change findings, a god-group
concentrating the graph's fan-in — with every datum on the ledger and no
signal ever telling the developer it is time to repartition. Separately, a
docs-only group rename (spec 043, arm b) leaves a group whose name no longer
matches the code directory its territory names; the filed code-move issue is
the only mitigation, and nothing senses the mismatch if that follow-up
stalls.

## User Stories

- As a developer on a multi-group project, I can request a reasoned health
  read of my partition on demand so that I can answer "is this partition
  still right?" without re-deriving trends from the ledger by hand.
- As a developer whose reconcile crosses a threshold I configured, I am
  offered (or, under auto, given) the health read at that moment so that
  degradation is caught near the reconcile that introduces it.
- As a developer who accepted a docs-only group rename, I can see the
  name/territory mismatch flagged until the code move lands so that the
  stalled follow-up does not go unnoticed.
- As a developer acting on a health read, I can file each finding as a
  tracked issue so that the backlog carries the split/merge work together
  with its evidence.

## Acceptance Criteria

- [ ] The health check runs ad hoc on demand — no threshold configuration
      required — reading the recorded reconcile-event series, the current
      map, and the group blueprints; it delivers a conversational report,
      persists no verdict artifact, and mutates nothing (map, blueprints,
      config, code).
- [ ] Four signal classes are sensed: (a) **breaking churn** — recurring
      cross-group breaking-change findings across recent reconciles;
      (b) **graph-shape trends** — edge density, cycle count, fan-in
      concentration (the god-group / blast-radius-breadth signal), and
      territory coverage; (c) **face growth** — a group's provides surface
      growing across reconciles, read from the newly recorded face-size
      measurements; (d) **name mismatch** — the snapshot sensor of AC #8.
- [ ] The report presents each fired signal with its evidence (the
      measurement values and their direction over the window, or the
      mismatch facts) and closes with a reasoned split/merge or
      rename-follow-up proposal naming the affected groups — or an explicit
      all-clear. Measurements stay facts; interpretation is framed as the
      sensor's judgment; the remedy pointer is `/jim:partition`. Findings
      are always advisory — never a veto, never a doctrine violation.
- [ ] Every reconcile additionally records aggregate face-size measurements
      as additive counters within the fixed shape-validated key set, and
      the documented counter contract (specs 034/039/028) is updated in the
      same change. The concentration counters (`faces_max`, and spec 039's
      `fanin`) each carry a slug-validated attribution key naming the
      group(s) holding the maximum — shape-validated on extraction, the
      spec 043 `old=`/`new=` bounded-value precedent — so a trend's
      identity survives history; per-group breakdowns and any other name
      or path content never ride the event.
- [ ] Every reconcile ends with a deterministic threshold evaluation of the
      fresh trend; when no thresholds are configured the hook is silent —
      no output, no interpretation spend — save the one-line unarmed-knob
      notice of AC #6 when a health knob is set (full-run path only).
- [ ] Thresholds are per-signal config keys, unset by default; a malformed
      or non-positive value disables that threshold and is noted in the
      reconcile report — it never mis-fires (the `blueprint_regen_threshold`
      semantics, spec 032). When `require_health` or `auto_health` is set
      truthy while no valid threshold is configured, a full-run reconcile's
      report notes in one line that the hook is unarmed — the fail-open knob
      is never invisible on any run that measures health. The unarmed notice
      is a property of the health hook, which runs on the full-run path only;
      on the nothing-to-reconcile short-circuit (fewer than two
      blueprint-bearing groups) no health verb runs and the
      nothing-to-reconcile note covers health, so the notice does not apply
      there.
- [ ] On a threshold crossing: default (both knobs unset) → one
      conversational offer to run the health check; `auto_health = "true"` →
      the check runs unattended; `require_health = "true"` → the
      reconcile-carrying run's completion is held until the check has run to
      completion (the `require_review` / `require_blueprint` completion-hold
      pattern, specs 026/030). A crossing is the gate's arming condition:
      with no threshold configured or none crossed, `require_health` holds
      nothing. "Run to completion" means the report was delivered, its issue
      offer answered (any answer counts — the spec 031 any-answered-fork
      rule), and the run's stage event recorded (AC #11) — the ledger event
      is the gate's enforcement token. In every mode it is the uncompleted
      phase that can block — the findings themselves never gate anything.
- [ ] The name-mismatch sensor deterministically flags a mapped group whose
      declared territory paths embed an identity token conflicting with the
      group's own name; territory paths embedding no identity token are not
      a mismatch. It requires no reconcile-event trend history — the
      docs-only-rename class may consult recorded rename events (spec
      043) — and is presented as a smell.
- [ ] A trend signal with fewer recorded reconcile events than its minimum
      window reports "insufficient history (N events)" explicitly — never
      silently omitted, never read as healthy. Snapshot signals are
      unaffected.
- [ ] Each fired signal's finding is offered as a tracked issue through the
      established capture flow; declining leaves no artifact.
- [ ] Each health run records a stage event carrying content-free counters
      (signals evaluated / fired), self-committed per the established ledger
      choreography (the spec 035 `commit-verify` precedent; content-free
      metrics channel per spec 026) — the run's only durable trace.
- [ ] Map, blueprint, and issue content quoted in the report rides only
      inside the established untrusted-content delimiters (specs 018/034);
      threshold and firing decisions derive only from the trusted counter
      channel (spec 026), never from claims embedded in scanned content.
- [ ] Events consumed for a trend are shape-validated individually: an
      event failing validation is excluded from the series and the report
      names the exclusion (the spec 039 AC #2 degradation pattern applied
      at series grain); an `na` counter value (not computable) never
      participates in a trend as a numeric value.

## UI Mockup

Ad-hoc run:

```
Partition health — acme-shop: 6 reconciles on record (2026-06-02 → 2026-07-10)

Signals:
  ⚠ cycles rising — 0 → 1 → 2 over last 3 reconciles (billing ⇄ orders; orders ⇄ shipping)
  ⚠ breaking findings recurring — fired in 4 of last 5 reconciles
  ⚠ platform face growing — provides 9 → 14 entries over 6 reconciles; fan-in 5 of 6 groups
  ⚠ group `payments` territory names src/billing/** — identity mismatch
    (docs-only rename follow-up stalled?)
  · density 2.1 → 2.3 — stable
  · coverage — 1 uncovered dir (tools/), unchanged

Read (judgment, not measurement):
  platform is drifting toward god-group shape — breaking churn and most fan-in
  concentrate there while its provides face grows. Split signal: carve the
  messaging surface out of platform. Merge signal: none.
  Remedy: /jim:partition.

File findings as issues? [file all] [skip all] · per-row: f / e / s
```

Reconcile tail (threshold configured and crossed, default mode):

```
Graph health (vs 2026-07-01T09:12:44Z):
  cycles 2 (was 1 ↑) …

Partition-health: cycles ≥ threshold (2). Run the health check? (y/N)
```

## Out of Scope

- **Chronic domain↔domain straddle sensing** and the advisor-side recording
  surface it requires — follow-on (candidate issue filed from this spec).
- **Straddle-count metric** — still behind spec 038's extractor fork
  (per spec 039).
- **Built-in default thresholds or calibration guidance** — thresholds ship
  unset; calibration accrues from real multi-group projects.
- **Gating or vetoing on health values** — verify-side gating remains issue
  #22 slice B2 territory.
- **Automatically invoking the repartition flow** — the proposal points at
  `/jim:partition`; the remedy stays human-initiated.
- **A persisted health report or verdict artifact**, and **backfilling** the
  new face-size counters onto historical events.
- **Changes to `BLUEPRINT.md` content or the derived Contract Graph
  section** — the sensors read; they never write the map.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Aggregate face-size encoding under the fixed-key contract

- **Relates to AC:** *"aggregate face-size measurements as additive,
  content-free counters within the fixed shape-validated key set"* (AC #4)
- **Surfaced as:** per-group provides sizes cannot ride the event as dynamic
  keys — the 028-pattern contract is a fixed key set; encode aggregates
  (e.g. a total and a max, mirroring how `fanin=` carries fan-in
  concentration).
- **Levelled-up requirement (already in the ACs):** the face-growth trend is
  recordable within the fixed-key, content-free counter contract.
- **Deflection reason:** Delegation — exact keys and encodings are plan
  detail.
- **Routing hint:** Architect to decide.

### Insight 2: Deterministic trend extraction as a script verb

- **Relates to AC:** *"reading the recorded reconcile-event series"* (AC #1),
  *"deterministic threshold evaluation"* (AC #5)
- **Surfaced as:** series extraction from the specs-root ledger (the
  `jimledger.sh updates-since` precedent) and threshold evaluation belong in
  script; interpretation belongs in skill (the Bash-vs-Prompt rule). Which
  script owns the verb (jimledger, jimverify, or jimpartition) — and each
  trend signal's minimum window — are the architect's call.
- **Levelled-up requirement (already in the ACs):** deterministic, silent
  threshold hook; explicit insufficient-history degradation.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

### Insight 3: Threshold knob shape

- **Relates to AC:** *"per-signal config keys, unset by default"* (AC #6)
- **Surfaced as:** per-signal keys following `blueprint_regen_threshold`
  semantics (positive integer; junk → disabled and noted). Exact key set and
  each key's unit (an absolute value, a delta, or a consecutive-event count)
  are plan detail. `require_health` / `auto_health` follow the bare-name
  knob family (specs 016/026/030) — fixed by interview decision.
- **Levelled-up requirement (already in the ACs):** operator-calibrated
  firing that degrades safely on junk config.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

### Insight 4: Name-mismatch detection mechanics

- **Relates to AC:** *"embed an identity token conflicting with the group's
  own name"* (AC #8)
- **Surfaced as:** identity-token comparison over declared territory paths;
  a likely home is the script that owns the rename verbs (spec 043). The
  false-positive guard matters: most territories legitimately embed no group
  token at all.
- **Levelled-up requirement (already in the ACs):** deterministic snapshot
  sensor with the no-token-is-no-mismatch rule.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

### Insight 5: Hook wiring and line budgets

- **Relates to AC:** *"every reconcile ends with a deterministic threshold
  evaluation"* (AC #5), *"conversational offer / unattended / held
  completion"* (AC #7)
- **Surfaced as:** the reconcile tail gains the threshold evaluation plus a
  `Skill(jim:partition)` invocation edge from the blueprint surface — a new
  skill→skill site. Health interpretation runs inline with no agent fan-out,
  so the one-level nesting limit is not in play. The blueprint SKILL.md line
  budget is exhausted (500/500, verified in this spec's research) — the hook
  cannot add net lines, so its methodology belongs in a reference doc, with
  the open restructure issue (#43) a likely companion or prerequisite;
  placement is the architect's call.
- **Levelled-up requirement (already in the ACs):** reconcile-anchored hook
  with the three-mode crossing behavior.
- **Deflection reason:** Delegation.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Sensor home — `/jim:partition` or `/jim:verify`?~ → `/jim:partition`:
      detector beside remedy, verify's claim-check vocabulary preserved,
      issue #22 slice B2's gating seam left intact.
- [x] ~Trigger model?~ → Reconcile-anchored threshold hook +
      `require_health` / `auto_health` + ad-hoc invocation.
- [x] ~Threshold calibration?~ → Config knobs, unset by default, junk →
      disabled and noted (spec 032 semantics).
- [x] ~Is #71 (name mismatch) in scope?~ → Yes — folded in as the snapshot
      sensor; close #71 as absorbed when this ships.
- [x] ~Chronic straddle signal?~ → Deferred — needs an advisor-side
      recording surface first; tracked as a follow-on issue.
