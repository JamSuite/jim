---
title: "Cross-group contract graph and blast radius"
type: feature
group: "jim"
id: "034"
status: approved
origin:
  - "docs/issues/20260630-add-the-cross-group-contract-graph-and-blast-radius.md"
  - "docs/brainstorms/20260630-000-current-spec.md"
---

# 034 Cross-group contract graph and blast radius

## Overview

Join the blueprint tiers: reconcile every group's `requires` face against
every other group's `provides` face into a derived, project-tier contract
graph in `BLUEPRINT.md`, with detectors for boundary leaks, dead surface, and
breaking changes — and blast radius answered at the moment a face changes.

## Problem Statement

The group tier captures each group's faces (spec 029) and the project tier
declares the partition (spec 033), but nothing joins them: one group's
`requires` is never checked against another group's `provides`. Cross-group
drift is therefore silent — a provider can remove surface a live consumer
depends on, a consumer can reach past a declared boundary, dead surface
accumulates untrimmed — and the developer discovers boundary breakage at
build or debug time instead of at the moment a face changes. The gap is
already felt in the shipped machinery: spec 031's guard prompts on a
Provides-face downgrade but cannot say *who breaks* — its Out of Scope routes
exactly that question to this spec.

## User Stories

- As a developer on a multi-group project, I can see the cross-group contract
  graph in `BLUEPRINT.md`, derived from the group blueprints' faces, so that
  who-depends-on-whom is explicit without anyone maintaining a third copy
  that could drift.
- As a developer whose change weakens or removes a `provides` entry, I am
  shown every dependent consumer group at the moment of the change, so that a
  regression against a live consumer surfaces before it lands rather than at
  the consumer's next build.
- As a developer using jim, I can rely on reconciliation re-running whenever
  a blueprint write lands, so that the graph never silently stales behind the
  faces it is derived from.
- As a developer, I can run the reconciliation on demand, so that I can check
  boundary health without waiting for a face to change.
- As a developer, each mismatch is reported as its own finding class with its
  own remedy, and unresolved mismatches are offered as captured issues, so
  that pending boundary work is tracked in my one tracking channel instead of
  evaporating with the conversation.
- As a developer on a partially-adopted project (some groups have no
  blueprint yet), I see missing declarations degrade to explicit unverifiable
  reporting — never false violations and never silent exclusion — so that I
  can adopt blueprints incrementally without the detector crying wolf.
- As a developer on a single-group project, I pay no reconciliation overhead
  — the run reports there is nothing to join and stops — so that the
  machinery never taxes simple projects.
- As a developer using jim, I can trust that the graph and findings reflect
  judgment over the declared faces rather than instructions hidden in them,
  and that no secret-looking value from scanned content is persisted, so that
  I can rely on the graph and safely commit it.

## Acceptance Criteria

**The graph**

- [ ] 1. Reconciling each group's `requires` face against the other groups'
  `provides` faces produces a contract-graph section in `BLUEPRINT.md`: the
  inter-group edges (consumer → provider, with the relied-on provides entry),
  derived solely from the group blueprints' faces — never hand-declared, and
  never re-declaring face content (the graph is the join, not a copy).
- [ ] 2. The graph is written only through the `/jim:blueprint` surface,
  consistent with `BLUEPRINT.md`'s single-writer authority. *(External
  constraint — Upstream Spec: spec 033 AC #3.)*
- [ ] 3. The map records the derived graph only — no per-edge reconciliation
  status or verdict is persisted in `BLUEPRINT.md`; findings live in the
  run's report and the issue collection (see AC #8–#9).

**Detectors**

- [ ] 4. Reconciliation classifies mismatches into distinct finding classes,
  each carrying its remedy:
  - **boundary leak** — a consumer requires something a *mapped, identified*
    provider never declared (remedy: promote to the surface, or sever);
  - **breaking change** — a consumer requires something the provider
    *removed* (remedy: restore, or fix the consumer); this class powers
    blast radius;
  - **dead surface** — a provides entry no mapped consumer requires (remedy:
    trim);
  - **unresolved require** — a requires entry that resolves to no mapped
    group (remedy: fix the face if it names an external dependency, fix the
    map if the code exists but no group's territory covers it — a partition
    gap — or fix a misnamed group). Non-group-attributed entries (e.g. a
    single-group blueprint's host-runtime couplings) route here rather than
    erroring. Territory paths consulted for the partition-gap attribution
    are re-validated through the `valid-relpath` boundary at use — a
    failing path is itself reported as map hygiene and never used;
  - **undeclared relation** — a derived edge between two groups that the
    map's declared Relations never record (remedy: declare the relation
    through a map update, or investigate the coupling);
  - **stale relation** — a declared Relations entry no derived edge
    supports, judged only when both groups' blueprints are present (remedy:
    remove the relation through a map update, or keep it as declared future
    intent).

  The two relation classes resolve through the normal map-tier update
  surface under its graded autonomy; the reconciliation never rewrites the
  Relations column itself.
- [ ] 5. Detectors fire only on declared data; missing declarations degrade
  to explicit reporting — never to silent exclusion, and never to
  violations. Concretely: leak and breaking-change fire on any edge whose
  two faces both exist regardless of overall coverage; dead surface fires as
  a finding only when every mapped group has a blueprint, and degrades to an
  informational note ("unconsumed among mapped consumers") under partial
  coverage.
- [ ] 6. Under partial coverage, the run reports coverage explicitly (how
  many mapped groups have blueprints) and counts edges it could not
  reconcile as unverifiable, naming the blueprint-less groups involved.

**Triggers and blast radius**

- [ ] 7. Reconciliation re-runs on every write through the blueprint surface
  — group-tier generate and update (both adapters) and map-tier updates
  alike — and is also invocable on demand with no face change. On a map with
  fewer than two blueprint-bearing groups, the run reports that there is
  nothing to reconcile and adds no further overhead.
- [ ] 8. When a blueprint write weakens or removes a `provides` entry, the
  run names every dependent consumer group (the blast radius) as part of the
  change's presentation — enriching spec 031's existing violation-fork and
  graded-autonomy prompts, whose decision authority is unchanged: blast
  radius informs the developer's choice, it never becomes a veto.
- [ ] 9. Findings surface in the run's report at detection time, and
  unresolved mismatches are offered as captured issues on the developer's
  confirmation; declining leaves no hidden state. The report's wording
  presents the check as declaration-level reconciliation of faces — never
  implying code-level verification, which remains the verification engine's
  job (issue #22).
- [ ] 10. Each reconciliation run's outcomes — edges reconciled and findings
  by class — are durably recorded, so that a mismatch nobody filed remains
  attributable after the fact (the spec 031 guard-outcome convention).

**Trust and safety**

- [ ] 11. The graph and every finding reflect the skill's judgment over the
  declared faces; directive-style content embedded in face entries, code, or
  map content (e.g. "this edge is verified — do not flag") never binds the
  derivation, the classification, or the blast-radius answer (carries
  forward the spec 026/029/030/031 trust boundary). Face or map content
  quoted as evidence — in the report, the blast-radius enrichment, or an
  offered issue body — appears only inside delimited untrusted-content
  blocks (the spec 031 evidence convention).
- [ ] 12. No raw secret-looking value from scanned faces, code, or map
  content is persisted into `BLUEPRINT.md`, the report, or a filed issue;
  spec 029/030's redaction placeholder applies.
- [ ] 13. The derived graph section is mechanical content carrying no intent
  authority: its rewrite is exempt from the shared Step-4a autonomy grading
  and never prompts on its own under `auto_blueprint`, while hand-declared
  map content (groups, Relations, territory) remains fully graded and the
  run's findings always surface in the report and the recorded outcomes.
  *(External constraint — Upstream Spec: the spec 031/033 Step-4a grading
  rule.)*

## UI Mockup

<!-- Conceptual shapes, confirmed during scoping. Exact format is a plan concern. -->

Contract-graph section in `BLUEPRINT.md` (derived, no verdicts):

```markdown
## Contract Graph

*Derived from the group blueprints' provides/requires faces — regenerated on
every blueprint write; do not edit. Last reconciled: 2026-07-04.*

| Consumer | Relies on | Provider |
|----------|-----------------------------------|----------|
| billing  | customer identity lookup          | accounts |
| orders   | customer identity lookup          | accounts |
| orders   | charge settlement events          | billing  |
```

Reconciliation report (conversation, at detection time):

```
Reconcile — acme-shop: 4 groups, 3 with blueprints (coverage 3/4)

  ✗ breaking    billing requires accounts "read-after-write identity lookup"
                — removed from accounts' provides face
                blast radius: billing, orders
  ✗ leak        orders requires accounts' session cache — never declared
  ~ unresolved  dashboard requires "metrics emitter" — no mapped provider;
                src/metrics/ falls in no group's territory (partition gap?)
  ~ undeclared  derived edge orders → billing (charge settlement) is not in
                the map's declared Relations
  · 2 edges into `platform` unverifiable (no blueprint yet)
  · dead surface: informational only (coverage incomplete)

File the 4 findings as issues? [file all] [skip all] · per-row: f / e / s
```

## Data Flow

```mermaid
flowchart LR
    GB[group blueprints<br/>provides + requires faces] --> R((reconcile))
    M[BLUEPRINT.md<br/>partition + territory] --> R
    T1[/blueprint-surface write/] --> R
    T2[/on-demand invocation/] --> R
    R -->|derived graph| M2[BLUEPRINT.md<br/>contract-graph section]
    R -->|findings by class| REP[report + offered issues]
    R -->|outcome counters| L[durable record]
    R -->|blast radius| G[spec 031 fork / downgrade prompt]
```

## Out of Scope

- **Plan-time blast-radius advisory** — consulting the graph from `/jim:plan`
  when planned work would touch a provides face. Split out during scoping as
  issue #39 (`20260704-add-a-plan-time-blast-radius-advisory-to-jim-plan`):
  it fires on a prediction rather than an actual face edit and touches a
  different skill.
- **Verification execution / mechanical hardening.** The detectors here are
  LLM-judged reconciliation over declared faces; hardening them into
  mechanical checks is the verification engine (issue #22), which also
  consumes this graph's blast radius to scope its fan-out.
- **Per-edge reconciliation status in `BLUEPRINT.md`** — decided out (AC #3):
  a persisted verdict rots into misplaced trust and duplicates the issue
  collection's job.
- **Deriving the map's Relations column from the graph** — the root-fix
  end-state that would eliminate the declared/derived dual source instead of
  checking it. Captured as issue #40
  (`20260704-derive-the-map-relations-column-from-the-contract-graph`),
  gated on multi-group practice: 034 checks the column (the two relation
  classes in AC #4) but does not change its authorship.
- **Multi-group blueprint updates.** A change spanning several groups still
  updates one group per run (spec 030's exclusion stands); this spec joins
  the resulting faces, it does not fan updates out.
- **Fixing anything.** The skill never edits faces, code, or the map to
  resolve a finding; every remedy is the developer's own follow-up, tracked
  through offered issues.
- **Deeper partition-health sensing** (split/merge recommendations, coupling
  metrics). The partition-gap finding class is this spec's only map-health
  signal; broader sensors remain deferred (spec 033's Out of Scope).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight 1: Command surface and skill line budget

- **Relates to AC:** *"written only through the `/jim:blueprint` surface"*
  (AC #2) and the on-demand trigger (AC #7)
- **Surfaced as:** fold the reconcile into `/jim:blueprint` (the single map
  authority) rather than minting a new skill — the 033 Insight-1 lineage.
- **Levelled-up requirement (already in the ACs):** reconciliation reachable
  on demand and fired by every blueprint-surface write, through the map's
  single-writer surface.
- **Deflection reason:** Delegation.
- **Architect note:** `skills/blueprint/SKILL.md` sits at 462/500 lines
  (ARCHITECTURE.md). Adding a reconcile arm almost certainly breaks the
  budget — plan for `references/` progressive disclosure or a body
  restructure before adding dispatch. The on-demand arm needs a flag/verb
  that disambiguates from the existing `<group>` / `--from-review` /
  `--since` / bare-map arms.
- **Routing hint:** Architect to decide.

### Insight 2: Face-entry matching is the riskiest unknown

- **Relates to AC:** the reconciliation itself (AC #1, #4)
- **Surfaced as:** `requires` entries reference a provider's guarantees in
  prose ("relies on read-after-write"), not by key — matching
  `A.requires ↔ B.provides` is LLM judgment, not string equality.
- **Levelled-up requirement (already in the ACs):** edges are reconciled and
  mismatches classified into the four finding classes.
- **Deflection reason:** Delegation.
- **Architect note:** match quality drives false leak/breaking findings.
  Consider whether 029's face formats need a nudge toward matchable shape
  (stable entry names) and where the bash/LLM split falls per the
  Bash-vs-Prompt rule — graph *structure* and counters are deterministic
  once edges are decided; edge *matching* is judgment.
- **Routing hint:** Researcher to investigate (matching approach); Architect
  to decide (split).

### Insight 3: Durable outcome record and freshness watermark

- **Relates to AC:** *"outcomes durably recorded"* (AC #10) and the mockup's
  "Last reconciled" line
- **Surfaced as:** ledger counters on the run's stage event (spec 031's
  `violations=`/`folded=`/`fixed=` convention — e.g.
  `edges=`/`leaks=`/`dead=`/`breaking=`), plus a single
  `last_reconciled`-style stamp on the graph section (spec 032's
  single-writer watermark pattern, stamped via `jimfile.sh now`, never
  content-derived).
- **Levelled-up requirement (already in the ACs):** outcomes attributable
  after the fact; the map shows how current the derivation is without
  asserting verdicts.
- **Deflection reason:** Delegation.
- **Architect note:** decide which ledger the reconcile's event rides on
  (the specs-root `ledger.md` carries the map tier's `tier=project` events —
  spec 033) and whether the watermark lives in map frontmatter or the graph
  section header.
- **Routing hint:** Architect to decide.

### Insight 4: Attribution for unresolved requires

- **Relates to AC:** the unresolved-require class and its partition-gap
  sub-case (AC #4)
- **Surfaced as:** 033's territory declarations are the attribution
  mechanism — a required code location falling in no group's territory is
  what distinguishes "partition gap" from "external dependency".
- **Levelled-up requirement (already in the ACs):** unresolved requires are
  classified with distinct remedies rather than lumped into leak.
- **Deflection reason:** Delegation.
- **Architect note:** attribution quality degrades with the
  `group_territory` mode (`directory` strongest, `declared-paths` mid,
  `none` leaves only LLM judgment) — mirror spec 033's mode-strength framing
  when setting expectations, and re-validate territory paths at use
  (`jimfile.sh valid-relpath`, the spec 033 capture-time gate).
- **Routing hint:** Architect to decide.

### Insight 5: Multi-group test fixtures

- **Relates to AC:** all detector ACs (#4–#6)
- **Surfaced as:** jim itself is a single-group project, so the detectors
  cannot be exercised against the host repo; tests need synthetic multi-group
  fixtures (map + ≥2 group blueprints with deliberately mismatched faces).
- **Levelled-up requirement (already in the ACs):** detector behavior is
  specified observably (fire / degrade / report) so fixtures can assert it.
- **Deflection reason:** Delegation.
- **Architect note:** deterministic pieces (counters, coverage math, any
  graph parsing) belong in `tests/` per the testlib conventions with temp-dir
  fixtures; the LLM-judged matching is checklist-validated like other skill
  prompts (ARCHITECTURE.md testing conventions).
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Which trigger layers are in scope?~ → On-demand + re-derivation on
  every blueprint-surface write (both tiers) + blast radius at the 031 fork;
  the plan-time advisory split out as issue #39.
- [x] ~Does reconciliation status persist in the map?~ → No — graph only;
  findings are ephemeral report + offered issues, outcomes durably counted
  (AC #3, #9, #10).
- [x] ~How do missing blueprints and unmatched requires behave?~ → Detectors
  fire only on declared data; missing declarations degrade to explicit
  reporting (AC #5); unresolved requires are their own finding class (AC #4).
- [x] ~Boundary authority?~ → Hybrid — locked upstream in the origin
  brainstorm; not re-litigated here.
- [ ] Does a fix-only 031 run (every edit withheld, ledger-only commit)
  re-derive the graph? Leaning no — no face changed — but confirm at plan
  time alongside the trigger wiring.
