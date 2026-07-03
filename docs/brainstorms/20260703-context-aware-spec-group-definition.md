# Brainstorm: Context-aware spec-group definition

*2026-07-03*

Origin: issue #19 (`20260630-build-intelligence-for-context-aware-spec-group-definition`),
surfaced from the `000-current` master-spec brainstorm
(`docs/brainstorms/20260630-000-current-spec.md`).

## The problem, restated

The blueprint model (specs 029–032, and the deferred #21/#22 slices) promotes
the spec group from a filing convention to a **load-bearing context boundary**:
provides/requires faces, verification contracts, external consumers. Choosing a
group *becomes* drawing a module boundary — but today that choice is ad hoc
("pick a name that fits the spec"). Careless seams propagate into the
blueprint, the contract graph, and verification.

**Level-set (jrko):** jim itself is a *bad example* — it has a single `jim`
group only because it's a small self-hosted plugin. The **normal shape of a
jim-developed project is several groups** (`foundation`, `storage`,
`dashboard`, …). Don't anchor the design on jim's own repo; multi-group is the
operating condition, not a future edge case. Consequences:

- **Assignment** (which group does this spec join?) is a *routine,
  high-frequency* decision on every real project — not occasional.
- **Creation** (minting group #2, #3, …) happens *early* in every project's
  life, when there's little code and few specs to reason from — the
  highest-consequence decisions get made with the least evidence.
- jim's single group means this capability can't be validated by self-hosting
  alone; it needs a multi-group project to exercise it.

## Dimensions of the problem (where "intelligence" could act)

Four distinct lifecycle moments, each a different job:

1. **Assignment** — a new spec arrives: which existing group does it join?
   (The everyday case; happens inside `/jim:spec`.)
2. **Creation** — when is a *new* group warranted, and how is its boundary
   drawn and named? (Rare, heavyweight, highest-consequence.)
3. **Health / evolution** — detecting that an existing partition has gone bad
   (low cohesion, high inter-group coupling) and proposing splits/merges.
4. **Onboarding** — jim adopted on an existing codebase: propose an initial
   partition bottom-up.

## Candidate approaches (seed list)

- **A. Placement advisor at spec time.** A lightweight step in `/jim:spec`:
  read existing group blueprints (responsibilities + faces), recommend
  join-existing vs. mint-new with a stated rationale (cohesion probe: "does
  this spec share invariants/surface with the group's existing scope?").
  Cheap; uses blueprint data that already exists; covers moment 1.
- **B. Group charter + deliberate creation act.** Make minting a group a
  first-class, interviewed decision (a `/jim:group` verb or a blueprint-seeding
  flow): purpose, in/out, naming, relations to neighbors. The charter seeds the
  group's `000-blueprint`. Covers moment 2; boundaries become documented
  decisions rather than side effects of a spec title.
- **C. Emergent boundaries + split/merge sensors.** Doctrine: start coarse,
  split when the evidence demands it. The contract graph (#21) supplies the
  signals — leak density between two groups, cross-group co-change, blueprint
  bloat — and fires *proposals*; human decides. Intelligence as sensor, not
  architect. Covers moment 3; depends on #21/#22 machinery.
- **D. Onboarding partitioner.** Bottom-up analysis of an existing codebase
  (dir structure, dependency graph, git co-change) → proposed initial
  partition, human refines. Covers moment 4; heaviest; adoption-facing.
- **E. Encoded doctrine only.** No new machinery: modular-design principles
  (cohesion, coupling, information hiding, bounded contexts) distilled into
  probes/checklist inside the existing skills' prompts.

Not mutually exclusive — plausibly a sequence (E→A cheap and immediate; B when
blueprints multiply; C/D once the contract graph exists).

## Grounding theory (to draw on, not adopt wholesale)

- DDD bounded contexts (language boundary = context boundary)
- Cohesion/coupling (the classic dial)
- Parnas information hiding (a module hides a decision likely to change)
- Consumer-driven contracts (already chosen for the boundary authority model)

## Resolved so far (session)

- **Day-one partitions: both directions.** The user often *can't* draw good
  boundaries unaided — domain/context partitioning is hard, and the user's
  attention is on the feature, not the bigger picture. So jim both interviews
  (capture what the user knows) *and* actively proposes (LLM analysis of
  vision/arch/domain). Neither alone.
- **Assignment is advisory with teeth.** The user is ultimately in control,
  but this is an area where *strong pushback is warranted*: the agent pushes
  back with reasoning, and agent and user hash out who's right in discussion.
  Not a silent default, not a hard gate — a genuine argument surface.
- **The marriage is the point.** Groups-as-application-design-boundaries is
  *why the issue was filed*. jim's group concept and the application's module
  structure become the same thing — that is what makes blueprint verification
  contracts meaningful (a contract at a boundary that doesn't really exist in
  the software verifies nothing). No credible alternative identified:
  - *Decouple blueprint scope from spec groups* (separate context-map
    partition) → two partitions to maintain + a mapping between them, and
    intent (specs) no longer lives inside the blueprint's boundary — recreates
    the very intent/code split 000-blueprint exists to close.
  - *Use code modules as the boundary* → no code exists at day one; code
    structure churns; and specs (intent) don't file by code module.
  - *One project-wide blueprint* → loses per-group cohesion, blast radius,
    and the contract graph entirely; doesn't scale.

## Tension opened: the partition axis (layers vs. verticals)

The canonical example set (`foundation`, `storage`, `dashboard`) is a
**horizontal/layered** partition. DDD bounded contexts are **vertical**
(domain slices: `billing`, `accounts`, …). The choice has a structural
consequence for jim:

- With **layered** groups, nearly every user-facing feature spec straddles by
  construction (UI + logic + storage) — assignment is perpetually ambiguous
  and cross-group contracts carry most of the load.
- With **vertical** groups, a feature usually lands in one context —
  assignment is mostly clean; contracts are fewer and thicker.

**Resolved: opinionated, vertical-first.** The layered partitions seen in
existing projects were *incidental* — what naturally appeared absent the
blueprint concept, not a chosen doctrine. jrko is willing to change the
approach entirely in service of tight, functional blueprints: **clear
boundaries for AST parsing and contractual obligations are the driving
requirement.** Refinements:

- **Config knob as escape hatch** (e.g. `group_axis = vertical|layered`) for
  users who really want layered. Note: layered mode shifts most load onto
  cross-group contracts and makes straddling normal — the straddle-smell
  detector would need recalibrating (or disabling) under it.
- **Migration path needed** for existing layered projects → vertical. A
  script if mechanical, a skill if LLM reasoning is required — likely a
  hybrid (skill reasons about the new partition and re-homing; script does
  file mechanics).
- Vertical-first ≠ zero horizontal groups: a shared-kernel / platform group
  (`foundation`-like) stays legitimate when it's genuinely shared — but it
  earns its place via a deliberately small, declared `provides` face, not as
  a default dumping ground.

## Resolved: the context map is an architecture-tier artifact

Group definition is not paperwork — it's a **context map** requiring
high-effort, whole-application reasoning. The blueprint becomes the
*authoritative document for its domain*, so the partition must be drawn with a
view to the entire application architecture.

- `/jim:spec` assignment **consumes** the map; it never invents boundaries on
  the fly.
- **Lifecycle symmetry with the hybrid boundary model:** at day one the map is
  *declared* (top-down intent — there are no faces or code to derive from);
  as the project grows, the derived contract graph (#21) provides the
  bottom-up check. The map is then *reconciled* against reality the same way
  `A.requires ↔ B.provides` is — declared intent vs. discovered dependency,
  disagreement as diagnostic. One pattern, both tiers.
- **Group → code territory mapping.** The AST-parsing requirement implies each
  group must bind to concrete code locations (dirs/packages/modules). The
  cheap verification floor (lint/AST/grep) can't scope its checks without
  knowing *where a group's code lives*. The context map likely carries this
  binding (a `code:` face per group).

## Migration wrinkle: per-group spec IDs

Spec IDs are per-group (`dashboard/001`; commit trailers `Spec: <group>/<NNN>`,
issue origins, relations all reference them). Re-homing historical specs into
a new partition breaks every such reference. Fork to consider:

- **Freeze history:** numbered specs are point-in-time artifacts anyway (the
  blueprint doctrine already says so) — leave them where they are, mint the
  new partition for *blueprints + future specs* only. No reference rewrite;
  the map and blueprints migrate, history doesn't.
- **Full re-home:** move/renumber specs into new groups — cleaner directory
  reality, but a reference-rewriting migration (trailers are immutable in git
  history regardless).

**Resolved: freeze history.** Numbered specs are point-in-time artifacts —
they stay where they are. The living artifacts (the map, the blueprints,
future spec filing) migrate to the new partition; no reference rewriting.

## Where the context map lives (options analysis)

**A. A section inside ARCHITECTURE.md.**
- *Pros:* one project-tier doc, no new artifact; the contract graph was
  already headed to this tier (origin brainstorm); existing regen cadence.
- *Cons:* **authority-direction mismatch** — ARCHITECTURE.md is a *generated
  reflection* (code-derived, `/jim:arch` regenerates it, historical in
  orientation); the map is *declared intent* (authoritative — the thing code
  is checked against). Embedding a declared artifact inside a regenerated one
  creates a who-wins-on-regen problem and demands a protected carve-out — a
  mixed-ownership file, the exact failure mode already bleeding on
  ARCHITECTURE.md today (issue #10, hand-edits bypassing `/jim:arch`). Also:
  mechanical consumers (`/jim:spec` assignment, the reconciler) would parse a
  section out of regenerated prose — brittle; and regen cadence (builds) ≠
  map cadence (boundary decisions).

**B. A dedicated project-tier artifact — the map as a tier-0 blueprint.**
The recursive move: each group has its `000-blueprint`; the *project* gets a
map one tier up. Same doctrine (current-state-only, declared intent,
invariant floor), scoped to the partition itself: the groups, their purposes,
their relations, and (mode-dependent) code territories.
- *Pros:* authority coherence — a declared-intent artifact under the same
  intent-leads / fold-back model as blueprints, no mixed ownership;
  mechanically consumable (structured, stable home); the blueprint
  maintenance machinery (fold-back gate, staleness flag, regen cadence —
  specs 030–032) extends for free — one mental model, two tiers;
  ARCHITECTURE.md keeps its clean identity.
- *Cons:* a new artifact (proliferation; lean instincts object); overlap risk
  with ARCHITECTURE.md — needs a strict division: **map = declared partition
  + relations, current-only; arch = generated reflection + history/why**,
  with arch *referencing* (or rendering from) the map, never duplicating it.
  Exact path/naming (a non-group entry at the specs root) is spec detail.

**C. Derived/virtual — computed from the group blueprints' faces.**
- *Pros:* zero maintenance; can't drift.
- *Cons:* fails day one outright — no faces exist to derive from, and the
  map's whole point is intent that *precedes* code. Deriving both sides also
  collapses the declared↔discovered reconciliation diagnostic. The *derived
  graph* remains a separate, later, computed view (#21): it checks the map,
  it isn't the map.

**D. jimconf.toml.**
- *Pros:* trivially machine-readable.
- *Cons:* config is operator dials, not design decisions — no room for
  rationale/prose, wrong review surface. Clean split instead: **decisions
  with rationale → map artifact; dials (axis mode, territory mode) →
  jimconf.**

**Preferred: B.** Ranked reasoning: (1) authority direction is the
load-bearing property — a declared-intent artifact cannot live inside a
regenerated document without recreating the mixed-ownership wound jim already
carries on ARCHITECTURE.md; (2) mechanical consumers need structure and a
stable home; (3) doctrine and machinery reuse — the map is maintained by the
same fold-back loop as the blueprints, nothing new invented; (4) map changes
have a different cadence and approver than arch regen. The cost (one new
artifact) is bounded by strict non-duplication with arch.

## Code-territory binding: mode-driven, not doctrine

Walked back (jrko): "clear boundaries for AST parsing" was too aggressive as
a *mandate* — jim serves multiple people and project types and **must not
dictate code layout**. Resolution: a config **mode** matched to the user's
preferences and project type, e.g.:

- `directory` — each group owns a subtree. Strongest: AST/import checks
  trivially scoped, boundary physically enforced, leaks visible in imports.
- `declared-paths` — the map lists each group's code locations. Mid-strength:
  checks scope to a hand-maintained path list.
- `none` (semantic) — no code binding; the boundary exists in specs and
  blueprints only. The verification floor degrades from mechanical (AST/grep)
  to LLM-judged.

Key consequence: **the territory mode sets the strength and price of the
verification floor (#22)** — it is not cosmetic. Per-group territory
*declarations* (where used) live in the map; the *mode* lives in jimconf.
Greenfield vertical projects get `directory` nearly free; existing layered
projects can adopt at `declared-paths` (or `none`) without touching code
layout.

## Resolved: the map is `BLUEPRINT.md`

Option B confirmed, and named: a **top-level `BLUEPRINT.md`** that glues all
the group blueprints into a single project-level scope. Consequences:

- Joins the root strategic-doc family — `VISION.md` / `ROADMAP.md` /
  `ARCHITECTURE.md` / `BLUEPRINT.md` — rather than being a non-group entry
  at the specs root (resolves the path/naming question; follows existing
  precedent for root-level named docs).
- Clean identity split at the root: `ARCHITECTURE.md` = generated reflection
  + history/why; `BLUEPRINT.md` = declared partition + relations,
  current-state-only.
- The tier symmetry is now literal: `BLUEPRINT.md` (project tier) ↔
  `000-blueprint` (group tier) — same doctrine, same fold-back maintenance
  model; the 030–032 machinery (update, guard, regen cadence) extends up a
  tier.
- **Amends #21's placement assumption:** the contract graph's home was
  "plausibly the ARCHITECTURE.md tier" in the origin brainstorm and #21's
  body — it is now `BLUEPRINT.md`. The #19 spec should state this
  supersession explicitly (and #21 can be edited when picked up).

## Resolved: scoping

- **One spec** covers the capability: `BLUEPRINT.md` (the map artifact) +
  creation-time intelligence (interview + proposal) + assignment advisor in
  `/jim:spec` (advisory with strong pushback).
- **Migration skill is its own issue** (layered→vertical re-partition;
  territory-mode upgrades `none`→`declared-paths`→`directory`) — candidate
  for the end-of-session batch.
- Split/merge sensors (moment 3) stay deferred to #21/#22 territory.

## Prerequisite or parallel? (thread 1 analysis)

What actually breaks if a multi-group project adopts the blueprint model
*without* this work: nothing structural — 029–032 machinery runs per-group
regardless of seam quality. The failure is **value degradation +
calcification**:

- Blueprints over bad (layered/ad-hoc) seams are accurate but low-value:
  faces are fat and chatty (every feature crosses boundaries), verification
  contracts at meaningless boundaries verify little, blast radius reports
  "everything affects everything."
- Worse than useless: contracts + blueprint content **calcify the bad
  partition** — every artifact invested in a wrong seam raises the cost of
  the eventual migration (which is exactly the skill we just agreed needs
  filing).

Dependency directions are *soft* both ways: day-one `BLUEPRINT.md` is
declared (needs nothing from blueprints); reconciliation needs #21's derived
graph (later); the assignment advisor reads map + blueprints as they exist.

So the answer is **split by audience**:

- **For jim's own repo (single-group):** parallel. Nothing blocks; blueprint
  development continues.
- **For multi-group adoption (real projects):** prerequisite. Adopting
  blueprints before the map exists bakes in migration debt on day one. The
  roadmap's Now bucket ("begin active testing with real-world projects")
  puts this on the critical path — real projects are multi-group by the
  level-set.
- **For #21/#22:** prerequisite, concretely — #21's graph now lives in / is
  reconciled against `BLUEPRINT.md`, so building #21 first would target the
  wrong home. Sequencing confirmed: **#19 → #21 → #22.**

## Session outcome (wrap-up)

- Filed **#34** `20260703-build-the-partition-migration-skill` (migration
  split out; `depends-on` #19).
- Updated **#19**: direction resolved per this brainstorm; `blocks` #21 and
  #34; next step `/jim:spec`.
- Updated **#21**: contract-graph home corrected to `BLUEPRINT.md`;
  `depends-on` #19.
- Roadmap deliberately untouched (jrko: ignore for now).
