---
spec: "standalone"
status: Active
date: "2026-07-24"
supersedes: "docs/research/20260717-competitive-landscape-sdd-skills.md"
---

<!-- Word budget deliberately exceeded, as with the 2026-07-17 survey this updates: a landscape doc going deep on six newly-shipped capability surfaces. The DoD <1500-word rule is overridden for this survey. -->

# Research: Competitive Landscape Refresh — SDD Skills & Frameworks (2026-07, blueprint-aware)

A capture of the new/refreshed URLs from this file is in `20260724-competitive-landscape.csv`. This doc **updates** `20260717-competitive-landscape-sdd-skills.md` (one week prior) — that survey remains valid for the original seven lanes; this one re-draws jim's position now that the `feat/blueprint` branch has landed.

## Why this update exists

The 2026-07-17 survey was written **blind to `feat/blueprint`** — 637 commits, specs 026-052, shipping **`/jim:review`**, the **blueprint system** (`000-blueprint` living specs, the `BLUEPRINT.md` context map, the contract graph, `/jim:verify`, `/jim:partition`), and the **pipeline ledger**. That matters because the prior survey named several of these as jim's *biggest missing capabilities and structural gaps*. They are no longer missing. This refresh does two things:

1. **Marks the closed gaps** — what the prior doc filed as "jim's most novel *missing* capability" and candidate future specs, jim now ships.
2. **Finds the real analogues for the new surfaces** — which turn out to live largely **outside** the Claude-Code SDD-skills ecosystem, in architecture-conformance tooling, DDD context mapping, consumer-driven contract testing, and SDLC-telemetry. The competitive frame widens accordingly.

**Currency note.** The prior survey verified every source on 2026-07-17. Only one week has passed, so competitor *currency* is intact and is **not** re-litigated here — the original per-lane study guide (brainstorm / spec / research / plan / build / sec / meta) carries forward unchanged, with a single correction flagged below. New research energy went entirely into the six new capability lanes, each swept fresh and verified **2026-07-24** via parallel research agents (WebSearch + WebFetch against primary sources).

---

## Part 1 — The headline: jim built its biggest gaps

The prior survey's own words, against what specs 026-052 delivered:

| Prior-doc claim (2026-07-17) | Where it appears | Now delivered by |
|---|---|---|
| "spec-lifecycle / post-ship amendment model … jim's most novel *missing capability*"; "**Biggest structural gap surfaced**" | Peer Feedback (b); Cross-Cutting Pattern #2; Takeaways | **`000-blueprint`** — a living, present-tense, build-grade spec, plus the **fold-back loop** (intent leads, build/review learnings feed back) |
| "a **`/jim:review`** skill … may warrant its own spec" | Peer Feedback (a) | **`/jim:review`** (specs 026-028) |
| "**Drift / convergence phase** … a code-vs-intent closing pass jim's pipeline lacks" | Cross-Cutting Pattern #3 | **`/jim:review`** + the **`/jim:verify` living-intent sensor** (035-037, 041) |
| "an **independent review step**"; "**verification-before-completion** evidence gate" | build gap analysis; Opportunities | **`/jim:review`** read-only investigator fan-out (per-region + per-AC, omission class) |
| "**Adversarial verification / second-opinion**" | Cross-Cutting Pattern #4 | verify judge ceiling + review investigators — read-only *by capability*, not merely by rule |

And four surfaces the prior survey had **no analogue for at all**, because jim had not conceived them yet:

- **The contract graph** — `provides ↔ requires` reconciliation into a derived, drift-proof join with named finding classes and pre-decision blast radius (034, 042, 045, 049).
- **`/jim:partition`** — propose a partition from the real dependency graph, evolve it via rename / split / merge / health (033, 038, 043, 044, 047, 048, 051).
- **The verify engine's three-tier ladder** — a zero-config mechanical floor + an operator-owned command registry + a criticality-gated read-only judge, with a five-outcome taxonomy and contract/retirement modes (035-037, 041).
- **The pipeline ledger** — a committed, content-free, trust-boundaried SDLC flight recorder.

The strategic consequence: jim moved from *"a strong interviewer/researcher with a post-ship blind spot"* to *"the only tool in this ecosystem carrying a **living, verifiable, contract-checked architectural specification** across the whole build → review → fold-back loop."* The differentiation the prior doc argued (integrated, human-in-the-loop, compounding memory) didn't just hold — it acquired a second, harder-to-copy pillar: **institutional memory that is now executable** (verified against code, not just archived).

---

## Part 2 — The landscape widened

The single most important finding of this refresh: **none of the new capabilities' true competitors are SDD skills.** The prior survey's rivals (spec-kit, OpenSpec, superpowers, GSD, Kiro, cc-sdd) still barely touch these problems. The real analogues are mature engineering disciplines jim has quietly walked into:

| jim's new surface | The discipline it now competes in | Strongest incumbent(s) |
|---|---|---|
| `000-blueprint` (living spec) | Living documentation / spec lifecycle | **OpenSpec** (structural), **spec-kit `/converge` + `/constitution`** (mechanism) |
| Contract graph | Consumer-driven contracts + DDD context mapping | **Pact BDCT** (runtime), **Context Mapper** (design), **Riftmap** (AI blast-radius) |
| `/jim:verify` | Architecture conformance / fitness functions | **ArchUnit** family, **SonarQube 2026.4 Architecture Management** (GA + free, 2026-05-20) |
| `/jim:review` | Post-build spec-conformance review | **spec-kit `/converge`** (concept), **obra/superpowers** (mechanism) |
| `/jim:partition` | Modularization / monorepo boundaries | **Context Mapper** (shape), **Mono2Micro / CARGO / MicroAgent** (code-moving) |
| Ledger | SDLC telemetry / provenance | **Liza `log.yaml`** (closest), DORA platforms, SLSA/Rekor |

This is a stronger competitive position, not a weaker one — jim is now the **integration point** across disciplines that ship as separate tools. But it also means the honest bar rose: several of these incumbents are deterministic, free-per-run, and battle-tested, and a few own jim's headline phrases in market discourse. The per-lane analysis below is scrupulous about where jim is genuinely novel versus where a strong incumbent will be cited as prior art.

---

## Part 3 — Per-capability study guide (the six new lanes)

Format mirrors the prior doc: **look-for → Tier 1 (study) → Tier 2 (mine) → Tier 3 (reference) → where jim is ahead / behind → novelty verdict.** Every status verified 2026-07-24.

### A. `000-blueprint` — the living, current-state spec
*Look for: a present-tense spec that build learnings fold back into, where intent leads and code never becomes the authority.*

**Headline:** No full analogue. Two systems capture opposite halves; the mature "living documentation" tradition **inverts jim's core doctrine**.

**Tier 1**
- **OpenSpec** (`Fission-AI/OpenSpec`, **62.4k★** direct-verified, active) — the closest *structural* half. `openspec/specs/<domain>/spec.md` is explicitly "the canonical, current-state specifications"; `changes/<id>/` deltas use `ADDED`/`MODIFIED`/`REMOVED Requirements`; `openspec archive` **mechanically merges** deltas into the canonical spec. *jim ahead:* OpenSpec updates from pre-authored *plan* deltas, not build/review *learnings* — no post-implementation reconciliation; no Provides/Requires split (verified: "no requires/provides relationships"); no cross-spec map; no invariant floor/criticality. *OpenSpec ahead:* fully deterministic merge (jim's fold-back is LLM-mediated) and a clean `ADDED/MODIFIED/REMOVED` diff grammar **worth borrowing** for jim's targeted section diffs.
- **GitHub Spec Kit** (**123.6k★** direct-verified) — the closest *fold-back mechanism* half. **`/speckit.converge`** assesses the codebase against spec/plan/tasks and appends unbuilt work; **`/speckit.constitution`** (`.specify/memory/constitution.md`) is the nearest **invariant-floor** analogue — but global, hand-written, ungraded, enforced as a gate wired into every command. Real reconciliation is still community-grade (`/speckit.reconcile` issue #1063; `stn1slv/spec-kit-reconcile`; `bgervin/spec-kit-sync`). *jim ahead:* no living current-state spec ("per-feature artifact collections … no formal amendment process; no diff between spec v1/v2; no record of *why*"); converge appends *build tasks*, not learnings-into-intent; constitution is project-global not per-group-graded. *Spec Kit ahead:* constitution-as-enforced-gate integration; 30+ agent breadth.

**Tier 2**
- **Amazon Kiro** (kiro.dev, intl launch 2026-05-07, commercial IDE) — specs (`requirements/design/tasks`) are pre-implementation and **unidirectional** in the official docs (third-party "drift detection / spec-as-source-of-truth" claims are **not corroborated** by kiro.dev — treat as marketing). **Steering docs** (`product/tech/structure.md`) are present-tense conventions ≈ jim's **ARCHITECTURE.md**, not the group blueprint; runtime-integrated (silently shape every generation) — an enforcement surface jim's docs lack.

**Tier 3 — the philosophical CONTRAST (they invert jim's doctrine)**
- **Cucumber/BDD** Gherkin, **Structurizr/C4-as-code**, **arc42 / FINOS architecture-as-code** — all keep docs current by making **code/tests the authority** and generating the doc from them. jim deliberately does the opposite: intent leads; only *learnings* update intent. Their tradition solves *staleness* but not *intent-authority*. Borrow Structurizr's systems/containers/components relationship metamodel for the map tier; take nothing of their authority model.

**Novelty verdict:** four blueprint properties have **no combined precedent** anywhere surveyed — (1) the intent-leads / learnings-feed-back loop; (2) the Provides (hand-authored intent) vs Requires (code-discovered) split on one surface; (3) the invariant floor with criticality; (4) the two-tier per-group-blueprint + project-map structure consumed by an assignment advisor. **Closest to study:** OpenSpec's `specs/` + `archive/` lifecycle and spec-kit's `converge` + `constitution`.

### B. The contract graph — reconcile provides ↔ requires
*Look for: deriving and checking a cross-module contract graph from separately-declared provides (intent) and requires (from code), classifying mismatches.*

**Headline (jim's most competitively-exposed lane):** every *ingredient* has a 2026 incumbent; jim's novelty is the **synthesis and the venue**, not any single mechanism.

**Tier 1**
- **Pact + BDCT / Matrix / `can-i-deploy`** (docs.pact.io; PactFlow/SmartBear; dominant 2026) — **the strongest prior art.** Bi-Directional Contract Testing has the provider publish an OpenAPI spec (a *provides* face) and the consumer publish a pact (a *requires* face), then reconciles by checking **consumer ⊆ provider** — structurally identical to jim's `A.requires ↔ B.provides`. The **Matrix** *is* "pacts joined to verifications" (so jim is **not** novel on "graph is the join, not a third copy"); **`can-i-deploy`** *is* mature blast radius. *jim ahead:* design-time / pre-code (Pact needs services running and tested), intra-repo architectural scope (not deployed HTTP services), richer taxonomy (Pact lacks first-class *dead-surface* and *leak* classes), no test infrastructure. *Pact ahead:* production-proven at scale, per-field schema matching, CI release gating.
- **Context Mapper** (contextmapper.org; CML DSL v6.12.0, active) — the closest **strategic-design** analogue. Has *both* a hand-authored face (CML: Bounded Contexts + Open Host Service / Published Language / ACL / Conformist) *and* a code-derived face (discovery lib) — **but they never meet** (verified: "does not reconcile or compare against hand-authored maps"). No reconcile, no drift detection, no finding classes, no blast radius. jim's whole thesis — the graph is the *checked join* so it can't drift — is exactly the gap Context Mapper leaves open. Its relationship vocabulary is far richer than jim's Provides/Requires and worth studying.
- **Riftmap** (riftmap.dev, marketed production July 2026, MCP) — **owns jim's "blast radius before an agent changes code" framing** in market discourse. A cross-repo graph from *declared* manifest edges (Dockerfile/Terraform/Helm/package) with confidence scoring; blast radius = transitive dependents. But a single declared edge-type, no two-face reconcile, no finding-class taxonomy. (Vendor-blog stats treated as unverified marketing.)

**Tier 2**
- **knip** (~40M npm downloads/mo; **ts-prune archived → knip**) — the **purest dead-surface analogue** (unused exports), but one-directional, no contract graph, no provider-intent face.
- **Microsoft API Extractor** — `.api.md` is a provider-declared surface snapshot; a diff catches **breaking changes** at review — but provider-only, no consumer face, no graph.
- **Nx** `enforce-module-boundaries` + Conformance — allow/deny edge rules on hand-declared tags ≈ a *coarse* boundary-leak check; no surface/breaking/dead/blast concepts.
- **CodeGraph / GitNexus / CodeGraphContext** (MCP AI code-graphs) — discovered-from-code impact graphs; pure *requires* side, no provides face, no reconcile.
- **Spring Cloud Contract** — provider-driven contract test generation; no requires-discovery, no derived graph.

**Tier 3:** dependency-cruiser (`orphan` ≈ distant dead-surface), madge, ts-prune (archived).

**Novelty verdict:** No single ingredient is new — join (Pact Matrix), requires ⊆ provides (BDCT), provides-snapshot (API Extractor), dead-surface (knip), blast-radius (`can-i-deploy` / Riftmap) each have a strong incumbent. jim's genuine novelty is **the specific pairing** (a hand-authored, guarantee-bearing *intent* provides-face × a purely code-*discovered* requires-face — nobody pairs *these*; Pact BDCT pairs two *authored* faces), **the venue** (design-time, pre-code, single-codebase, spec-group granularity, static scan, no execution), and **a unified finding-class taxonomy over one drift-proof graph** (the market has each class in a *separate* tool). **Positioning guidance: do not claim reconcile / join / blast-radius as inventions — claim the composite.** Most-exposed axes: LLM cost/determinism (competitors are deterministic and free-per-run); Pact BDCT's "we already do requires ⊆ provides" rebuttal; Riftmap owning the AI-blast-radius phrase.

### C. `/jim:verify` — architecture conformance
*Look for: automated conformance between a declared architecture/invariant spec and the actual code; any hybrid deterministic + judgment ladder.*

**Headline:** the *deterministic floor* is a mature, commoditizing field; the **hybrid mechanical-floor + criticality-gated read-only judge ladder** has **no shipping-product equivalent**.

**Tier 1**
- **ArchUnit** (TNG, Java, **v1.4.2, 2026-04-18**) — the reference implementation; JUnit rules over bytecode; `FreezingArchRule` grandfathers existing violations. Deterministic-only. Notably, `freeze` is the **opposite** of jim's retirement mode (it *grandfathers* stale violations; jim *hunts* stale rules).
- **SonarQube Architecture Management** — **GA in SonarQube Server 2026.4, free across commercial editions, 2026-05-20** (absorbed Structure101; deprecated the old architecture-as-code). Architect declares intended architecture as a UI allow-list; Sonar reverse-engineers current architecture every analysis and surfaces forbidden dependencies as maintainability issues. **Explicitly positioned for agent-generated-code drift** — but purely deterministic; its AI move is the *inverse* of jim's (feeds architecture context *to* coding agents via the SonarQube MCP Server = prevention). **jim's strongest mainstream deterministic competitor, now GA and free.**

**Tier 2**
- **ArchUnitNET / NetArchTest** (.NET), **ArchUnitTS v2.3.3** (now the most-starred TS arch-test lib) / ts-arch / arch-unit-ts, **Konsist** (Kotlin), **dependency-cruiser** (richest deterministic JS dep-rule engine), **Spring Modulith 1.4 GA (2026-03-27)** — all **deterministic-floor-only**, no judge tier.
- **Building Evolutionary Architectures** fitness functions (Ford/Parsons/Kua) — mainstream in 2026 ("renaissance of the monolith"). Crucially, the book's **"Future Directions" explicitly names AI-based fitness functions as future work** — jim is an early concrete instantiation of a direction the canon named but hadn't built. jim differs on criticality gating (fitness functions are always-on) and the five-outcome taxonomy (they're binary).

**Tier 3 (closest research prior art to the judge tier)**
- **Thoughtworks Technology Radar — "Architecture drift reduction with LLMs"** (Assess ring, Vol 34, April 2026) — a *technique*, not a product. The single closest published articulation of jim's mechanical + LLM combination, and it independently validates the thesis. But it is loose (no outcome taxonomy, no registry, no contract/retirement modes), its LLM also **fixes** code (jim's judge is strictly read-only), and it has **no criticality/appetite gating**.
- **arXiv 2606.14948v2** (2026-07-06) — LLM Architecture Complexity/Quality Judges with a gating threshold — but gated by task complexity/quality for **training-data curation**, not criticality-for-conformance; it *infers* conventions from code rather than checking *declared* invariants.
- **CodeScene** — behavioral (git-history) drift, orthogonal to declared-spec conformance; complementary.
- **Claude Code ecosystem** — the documented Anthropic pattern (`/design` checks changes vs `DESIGN.md`, plus `/verify` etc.) is pure-LLM single-tier. **No published CC skill combines a deterministic floor with a criticality-gated judge.**

**Novelty verdict:** the deterministic floor is **not novel** (and, with SonarQube 2026.4, increasingly commoditized — jim's real competition here got stronger). **Novel among shipped tools:** the criticality-gated **read-only** judge (no shipping precedent); the **five-outcome honesty taxonomy** — `failed` (check couldn't run, contained) and `unconfigured` (names a registry entry the operator didn't provide) encode engine honesty about its *own* coverage gaps, which no competitor surfaces; **contract mode** (bilateral edge check, no analogue); and **retirement mode** — the reverse-direction "is this recorded rule still justified?" — the **single most novel element**, with no analogue found (ArchUnit's `freeze` is its opposite; dead-code detectors find unused *code*, never unused *rules*). The industry is visibly converging on jim's thesis; as of 2026-07 no shipped product assembles these pieces.

### D. `/jim:review` — post-build spec-conformance review
*Look for: checking what shipped against what was scoped (not generic code-quality); build-range scoping; per-criterion verification; omission-hunting; a recorded verdict.*

**Headline:** four of jim:review's distinctive properties have **no full match anywhere** — per-AC investigator fan-out, the omission class as a first-class mandate, a directional alignment verdict with a recorded trajectory, and self-instrumentation as a ledger stage. The closest *conceptual* analogue is spec-kit `/converge`; the closest *mechanical* analogue is obra/superpowers; neither combines the two the way jim does.

**⚠️ Correction to the prior doc:** addyosmani `code-review-and-quality` was rated a "near-complete blueprint for jim:review." Refreshed against its current `SKILL.md`, it is a **generic 5-axis code-*quality* review** — no spec-conformance framing, no diff/SHA scoping, no per-AC structure, no omission check, no verdict. It remains an excellent **severity-taxonomy and change-sizing reference** (and its "verify the verification" phase is worth borrowing), but it is **not** a conformance analogue. Demoted accordingly.

**Tier 1**
- **GitHub spec-kit `/speckit.converge`** (verified: a **new arrival** since the prior doc) — the closest *conceptual* analogue. Post-implementation only; classifies every gap as **`missing` / `partial` / `contradicts` / `unrequested`** (maps almost 1:1 onto jim's drift concerns; **`unrequested` = scope creep, which jim does not explicitly surface — worth borrowing**); binary `converged` / `tasks_appended` with a re-run loop; a 4-pillar 0-100 quality score on convergence. But it uses **no git** ("no branch comparison, no history" — scopes by artifact-declared file paths + keyword), is single-pass with no subagents, does not hunt the omission class, and records no directional verdict or trajectory.
- **obra/superpowers `subagent-driven-development`** — the closest *mechanical* analogue and **the only one that records a build BASE SHA** ("record BASE before dispatching … review over `BASE..HEAD`, never `HEAD~1`"). Dual verdict (spec + quality), whole-branch review on the most capable model, and a **"⚠️ Cannot verify from diff"** flag — the field's *nearest gesture* toward the omission class (it acknowledges requirements in unchanged code, but punts them to the controller rather than investigating). Per-task, session-held BASE (not a persisted ledger; doesn't reconcile multi-spec branches); review is **blocking**, opposite jim's advisory stance.

**Tier 2**
- **dev-process-toolkit** (nesquikm, new 2026 CC plugin) — `spec-review` walks the AC checklist ✓/✗/⚠ with evidence-or-what's-missing, and has a **bounded convergence-escalation** ("if round 2 surfaces the same issue classes, stop and escalate to a human") — a loop-safety pattern **jim lacks and could borrow**.
- **shipspec** (jsegov) — triple-axis final review (ACs + design + PRD coverage), blocking.
- **anthropics/claude-code official `code-review` plugin** — now runs as a **background subagent**; fans out 4 agents **per LENS** (2 Sonnet for CLAUDE.md compliance, 2 Opus for bugs) + a false-positive validation pass; **"HIGH SIGNAL only"** discipline (a sharp guardrail for jim's investigators). Advisory (`--comment` opt-in).
- **wshobson/agents `comprehensive-review`** — checkpoint-gated multi-lens; clean severity vocabulary (blocking/important/nit/suggestion). *(skills.sh page truncated this session; checkpoint/risk-score specifics carried over from the prior doc, unrefreshed.)*

**Tier 3:** getsentry `security-review` (read-only by capability, confidence HIGH/MED/LOW), anthropics `claude-code-security-review` (per-**finding** fan-out + confidence-≥8 gate, `git diff --merge-base` scoping), and the commodity **per-lens parallel PR-reviewer** pattern (3-9 agents, branch-diff). These establish the field norm: fan-out is **per-lens or per-finding**, scoping is **branch-relative**, and no one binds to acceptance criteria, hunts omissions, or records a verdict trajectory.

**Novelty verdict:** the field produced a genuine post-build conformance command (`/converge`) and a wave of SDD-plugin final-review steps since the prior doc, **but none combine ledger-range scoping + per-AC investigators + omission-hunting + a recorded drift trajectory.** jim:review is ahead on its core thesis; the field is ahead on *scoped mechanical outputs* jim could selectively fold in (converge's `unrequested` class and 4-pillar numeric scores; the convergence-escalation loop; per-finding confidence gating; the HIGH-SIGNAL false-positive discipline).

### E. `/jim:partition` — propose and evolve a partition
*Look for: proposing a project partition from a real import/dependency graph, and evolving module boundaries via rename/split/merge with cross-boundary edge re-derivation.*

**Headline:** No shipping tool does this. The market splits into three camps that each own one piece — (A) **enforce a hand-declared partition** (Nx, Turborepo, Bazel, import-linter, dependency-cruiser); (B) **propose from real deps, but to *move code* into microservices, one-shot** (Mono2Micro, CARGO, MicroAgent); (C) **model + evolve a bounded-context map via split/merge, but from a hand-written model** (Context Mapper). jim fuses A+B+C's best parts while **inverting** the code-moving assumption.

**Tier 1**
- **Context Mapper (+ Service Cutter + MDSL)** — the only tool sharing jim's *propose + split/merge + human-in-loop-map* shape (refactorings AR-2/AR-3 split, AR-6/AR-7 merge; MDSL contract generation). **But: the Service Cutter proposal engine has been DEACTIVATED since v6.10.0 (Nov 2023)**; it proposes from a *hand-written CML model*, not real code; its reverse-engineering discovery is a **Spring-Boot-only prototype**. *jim ahead:* real multi-language import grounding, labeled coverage, the rename identity primitive, code-grounded edge re-derivation with call-site evidence, greenfield-vs-repartition auto-detect, never-moves-code, and a *live* proposal. *Context Mapper ahead:* a mature graph-clustering optimizer (16 coupling criteria + Markov/label-propagation), a formal DSL/IDE, academic pedigree.

**Tier 2 (propose from real deps — but to move code, one-shot)**
- **Mono2Micro** (IBM; static + **runtime traces** + hierarchical clustering; Java-only), **CARGO** (flow-sensitive system-dependency-graph label propagation; explicitly avoids distributed monoliths — closest to jim's "derive sound cross-boundary edges from the real graph"), **MicroAgent** (2026 multi-agent LLM decomposition — proves the LLM-multi-agent approach is live). All target monolith → microservice migration: **code-moving, one-shot, no evolution verbs.** jim **inverts their core assumption** (never moves code; routes moves to spec → plan → build as tracked issues).
- **CodeScene** — closest to jim's `health` verb (change-coupling trends over architectural components) — but from **git history (temporal)** vs jim's **static imports (structural)**, and purely observational (no propose/rename/split/merge). A complementary signal: co-change catches coupling static imports miss (jim's operator-wired `deps_command_<name>` extractors are its static answer to the same blind spot).

**Tier 3 (enforce a hand-declared partition):** Nx (tags + depConstraints; Conformance boundary rule is Enterprise), Turborepo Boundaries (experimental, 2.4.2), Bazel visibility, **import-linter** (Python contracts v2.7 — its *Independence* contract is a hand-declared version of what jim auto-derives), dependency-cruiser/madge/skott, and DSM tools (Sonargraph/NDepend/Lattix, Structure101-now-Sonar). Plus AI codemap generators (context-cascade, update-codemaps) that *describe* structure for context economy but never propose or evolve.

**Novelty verdict:** the `/jim:partition` combination is **unoccupied.** No tool combines: propose from the *real multi-language dep graph + operator extractors with **labeled coverage*** (the "a falsely-sparse graph looks clean while lying" honesty mechanic has **no analogue** — every other tool silently reports whatever its single scanner sees); vertical-first doctrine baked in; **evolve a living map** via rename (identity primitive: ripple enumeration + identity/code-surface/historical classification + invariant-ID stability) and **split with cross-group edge re-derivation from real imports + call-site evidence** (the single most differentiated mechanic — nothing else re-derives the new cross-boundary contracts when a boundary moves); greenfield-vs-repartition auto-detect; human-gated; and **never moves application code**. *Field ahead on:* algorithmic cut-suggestion (Context Mapper / Mono2Micro / CARGO have real clustering optimizers; jim's proposal is doctrine-driven grouping, not an optimization search — a future enhancement) and richer coupling signals (runtime traces, git co-change).

### F. The pipeline ledger — the SDLC flight recorder
*Look for: an AI-SDD pipeline instrumenting its own process with a durable, committed, grep-parseable, trust-boundaried event log.*

**Headline:** No prior art matches the *combination*. Every individual property has an established cousin, but nothing found combines **self-instrumented SDLC meta-process + committed-in-repo + content-free-by-discipline + untrusted-log-read-via-fixed-validated-key + no-standing-verdict.**

**Tier 1 (instrument an AI pipeline's own process)**
- **Liza** (`liza-mas/liza`, active 2026, Go) — the closest single analogue and the **inverse** of jim on nearly every axis. `.liza/log.yaml` records a timestamped activity history (claimed → checkpoint → submitted → approved → merged) with verdicts and commit refs — **but** it lives in a runtime dir (**not committed to git**), is **YAML** (not grep-text), is **content-full** (records affected file scope), validates on the **write** side (state-machine enforcement, not a read-side trust boundary), and instruments the **task lifecycle**, not the SDLC *meta-stages* with durations/interruptions/re-runs.
- **AI-agent "flight recorders"** (Agent Blackbox, IAXT, Honeycomb Agent Timeline) — own the literal phrase, but at the wrong altitude/polarity: **runtime execution telemetry** (commands, tool I/O, screenshots), **external** dashboards, **content-maximal** — the exact inverse of jim's SDLC-stage, in-repo, content-free ledger.

**Tier 2 (adjacent)**
- **Engineering-metrics / DORA platforms** — LinearB, **Swarmia** (now detects Claude Code-assisted PRs; read-only MCP export), Haystack, CodeScene, **Sleuth** (closest to event-log thinking — push-based deploy events), DX, Faros. **All are process-external SaaS that reconstruct metrics by git-mining/connector ingestion after the fact.** jim inverts this: the process narrates itself from inside, committed. (They are far ahead on analytics/rollups/visualization, which jim's raw grep-material ledger has none of.)
- **SLSA / in-toto / Rekor** — signed provenance binding artifact → workflow run + commit, in an append-only transparency log (shifting opt-in → default for public repos through 2025-2026). Cousin on append-only + provenance + validated SHAs, but crypto-signed, external, about build artifacts. jim's build-boundary SHAs echo the "this artifact from this commit" idea at a lighter, in-repo altitude.

**Tier 3 (conceptual cousins jim draws on):** **event sourcing** (append-only + derived read-model ≈ jim's trusted read-back channel — but event sourcing *trusts* its own store; jim treats its log as *untrusted* on read); **ADR decision logs** and **CHANGELOG** (append-only, never-rewrite-history — but human prose, content-full); **OWASP logging guidance** — "use compile-time constants as format strings to prevent log injection" is the genuine **spiritual ancestor** of jim's fixed, code-literal key set; and the **tamper-evident logging** literature (hash chains) — the *detection* school jim deliberately does **not** join.

**Novelty verdict:** a committed, self-instrumented, content-free, trust-boundaried SDLC event ledger for an AI pipeline is, **as a whole, unique** in the 2026 landscape. Two elements have no located precedent at all: the **containment-not-detection read-trust model** (a tampered ledger surfaces at most a bounded, well-formed value — applied to a process's log about *itself*), and the **"no standing verdict"** philosophy (deliberately refusing a persisted "verified ✓" that would rot into misplaced trust — the opposite of the entire audit-log field's persist-everything default). *jim behind on:* cryptographic tamper-evidence (an actor with commit rights can rewrite ledger history undetectably — SLSA/Rekor detect that; jim's threat model is narrower by design), analytics/visualization/rollups, and cost/latency/model-version capture (content-freedom forgoes it). **Closest competitor to watch:** Liza, converging on auditable AI-pipeline state from the opposite (runtime, YAML, content-full) direction.

---

## Part 4 — The original seven lanes: carried forward

The 2026-07-17 per-skill study guide (brainstorm / spec / research / plan / build / sec / meta), its Study Anchors, and its Prior-Source Currency Audit **stand unchanged** — one week is not enough to move 122k-star repos, and no re-verification was warranted. One substantive correction and a few carry-forwards:

- **Correction (review lane):** addyosmani `code-review-and-quality` is demoted from "near-complete jim:review blueprint" to "severity/change-sizing reference" (see Lane D). This also updates the prior doc's Peer Feedback (a), which is now **resolved** — the review skill shipped.
- **Resolved candidates:** both prior-doc Peer-Feedback candidates — a `/jim:review` skill and a post-ship spec-lifecycle model — are **shipped** (review; the blueprint system).
- **Still open (NOT closed by blueprint work), carried forward verbatim in spirit:**
  - **Meta / skill-authoring craft** — description = *when*-to-use only (jim still mandates "what + when," the inverted emphasis); RED/GREEN/REFACTOR for skills; anti-rationalization tables; named failure-mode taxonomy. *Cheapest high-leverage win; because jim is a skills project it lifts every skill at once — including the six new ones.*
  - **jim:research (thinnest lane)** — enforced tool-use / empty-result justification; primary-sources cite-every-claim. **Not** a scored confidence gate (a deliberate no-go per `004-researcher/research.md`).
  - **jim:spec** — an EARS / WHEN-THEN testable-AC grammar option (still free-prose). *Newly relevant:* testable ACs would sharpen jim:review's per-AC investigators, which now consume those criteria directly.
  - **jim:brainstorm** — a hard pre-implementation gate; one-question-per-message.

---

## Part 5 — Where jim is now uniquely ahead

The prior doc's "where jim is ahead" list (named Socratic Probes, conditional LINDDUN, `reviewed_phases`, STOP-on-every-failure, bash-tested scripts, candidate-issue capture) still holds. The blueprint work adds a **second, structural** tier of differentiation — capabilities that are novel *as composites* even though their ingredients have incumbents:

1. **A living architectural spec with a fold-back loop** — no tool keeps a present-tense, per-group spec that build/review *learnings* update while intent stays authoritative (OpenSpec + spec-kit split the two halves).
2. **A two-face contract graph at design time** — hand-authored intent × code-discovered usage, reconciled into a drift-proof join with a unified finding taxonomy and pre-decision blast radius, upstream of where every contract-testing tool (Pact) and dependency tool (Nx/knip) operates.
3. **A hybrid conformance ladder** — the mechanical floor is commoditized, but the criticality-gated *read-only* judge, the five-outcome honesty taxonomy, and especially the **retirement mode** (reverse-direction rule justification) have no shipping precedent.
4. **Spec-conformance review** with ledger-range scoping + per-AC investigators + omission-hunting + a recorded drift trajectory — a combination no reviewer in the field assembles.
5. **A partition you can *evolve*** — propose from the real dep graph with labeled coverage, then rename/split/merge with cross-boundary edge re-derivation, never moving code — inverting the entire monolith-to-microservice literature's assumption.
6. **A content-free, in-repo, trust-boundaried SDLC flight recorder** — containment-not-detection, no-standing-verdict; unique as a whole.

The through-line: **the ecosystem is visibly converging on jim's theses** — Thoughtworks' Assess-ring "architecture drift reduction with LLMs," the Evolutionary-Architecture book naming "AI fitness functions" as future work, SonarQube and spec-kit shipping drift/convergence in mid-2026, Liza building auditable AI-pipeline state. That convergence *validates the direction*; jim's edge is that it has already *assembled* these into one integrated, human-in-the-loop pipeline.

## Part 6 — Where jim is honestly exposed

Recording these so we don't inherit our own optimism:

- **Determinism / cost.** Every incumbent in the conformance, contract, and dependency lanes is deterministic and free-per-run; jim's requires-discovery and classification lean on LLM judgment. This is the axis reviewers will attack, and it is real. The mechanical floor and the fixed-key ledger channel are the right answers *where they reach*; be candid about where judgment is load-bearing.
- **Commoditizing floor.** SonarQube 2026.4's now-GA, free architecture management strengthened jim's deterministic competition. Do not claim novelty on the mechanical floor.
- **Owned phrases.** Pact BDCT ("requires ⊆ provides") and Riftmap ("AI blast radius") will be cited as prior art. jim's honest claim is the *composite and the venue*, not the primitives.
- **No cryptographic tamper-evidence** in the ledger (by design — narrower threat model than SLSA/Rekor).
- **No algorithmic cut-suggestion or dynamic coupling signal** in partition (Context Mapper / Mono2Micro / CodeScene have them).

None of these are refutations — they are the precise boundaries of jim's claims, and stating them is what makes the novelty claims credible.

## Part 7 — Patterns worth stealing (new, from this refresh)

Beyond the prior doc's ten, this sweep surfaced concrete, values-aligned borrow candidates:

1. **OpenSpec `ADDED/MODIFIED/REMOVED` delta grammar** — a clean, reviewable diff format for the blueprint's targeted section updates.
2. **spec-kit `/converge`'s `unrequested` gap class** — scope-creep / over-build detection jim:review does not explicitly surface; and its **4-pillar 0-100 quality score** as a crisp mechanical companion to the alignment verdict.
3. **dev-process-toolkit's convergence-escalation** — "if round 2 repeats the same issue classes, stop and escalate to a human" — a loop-safety guard for jim's investigator/judge fan-outs.
4. **The official code-review plugin's "HIGH SIGNAL only / if not certain, don't flag"** discipline, and **anthropics security-review's per-finding confidence-≥8 gate** — signal-quality mechanisms for review investigators and verify judges.
5. **Context Mapper's DDD relationship vocabulary** (Open Host Service / Published Language / ACL / Conformist) — a richer language for Provides-face guarantees than the current thin model.
6. **Structurizr's systems/containers/components metamodel** — a rigorous relationship model for the `BLUEPRINT.md` map tier.
7. **Algorithmic cut-suggestion** (Context Mapper's coupling-criteria clustering; CARGO's flow-sensitive label propagation) — a future enhancement to jim:partition's doctrine-driven proposal.

Each must be re-shaped to jim's human-in-loop, transparent posture before adoption — the same filter the prior doc applied.

## Part 8 — Adoption tensions & non-goals (unchanged, revisited)

The prior doc's "don't jump off the bridge" list stands: **no** unattended multi-phase autonomous runners, **no** silently-proceeding scored gates, **no** deploy/CI/ops surface. Two blueprint-era reinforcements:

- **The verify judge and review investigators fix nothing** — deliberately read-only, unlike the Thoughtworks LLM-remediation technique and most CC review plugins. This is a locked posture, not a missing feature.
- **The ledger detects nothing cryptographically** — it *contains* blast radius rather than proving tamper-evidence, consistent with "transparency over automation" (a persisted "verified ✓" would be the black box jim's non-goals forbid).

## Part 9 — VISION.md alignment

`VISION.md`'s Competitive Landscape table (previously refreshed 2026-07-17) predated the blueprint work and was understated. It was **refreshed via `/jim:vision` on 2026-07-24** to close that gap — scoped strictly to the Competitive Landscape section and its Differentiation paragraph. What landed:

- **New "widened frame" row** — *Architecture-conformance, contract & delivery-telemetry tools* (ArchUnit, SonarQube Architecture Management, Pact/BDCT, Context Mapper, Nx boundaries, Liza, DORA platforms): mature and deterministic, but each solves one slice in isolation, none integrated into a spec→build lifecycle. This records the widened frame — that jim's new surfaces compete with engineering disciplines outside the SDD-skills ecosystem.
- **Spec-driven-frameworks row reframed** — Cons now note the absence of a living current-state spec with a build→review fold-back loop, a cross-group contract graph, and a code-conformance engine (even the mid-2026 `/converge` / reconcile additions only append build tasks against ephemeral per-feature artifacts).
- **Skill-collections row** — Cons now note that their review/verification skills aren't tied to a living spec or a contract surface.
- **Differentiation paragraph rewritten around two pillars** — the integrated, human-in-the-loop path, and the new second pillar: institutional memory is now *executable* (a living, present-tense blueprint whose provides/requires faces reconcile into a verified contract graph, folded back from every build and review).

*(Per project convention, VISION.md is edited only through `/jim:vision` — the refresh above was made through the skill, not by hand. This survey aligns with VISION.md's Roadmap Phase 2 (Research & Refinement) and now feeds directly into its Competitive Landscape.)*

## Part 10 — Fetch notes & audit trail

Six parallel research agents, all verifying *current* (2026-07-24) status via WebSearch + WebFetch against primary sources. **No 429 / rate-limit errors occurred in any lane.** Three non-blocking fetch anomalies, none leaving a material gap (per the WebFetch guardrail, none was worked around with an alternate tool to fetch the same content):

- **`npmjs.com/package/knip` → HTTP 403** (contract-graph lane). Not retried; knip's status was taken from its own site (knip.dev). Only the exact npm-pinned version is unconfirmed — immaterial to the analysis.
- **`github.com/github/spec-kit/blob/main/.claude/commands/security-review.md` → 404** (review lane) — a wrong-path probe; the needed `converge.md` was fetched successfully via the `templates/` path. No data lost.
- **`skills.sh/wshobson/agents/code-review-excellence` → truncated** (review lane) — severity vocabulary confirmed; the PR-risk-score / checkpoint-gate specifics could not be re-verified and are **carried over from the prior doc, unrefreshed**.

**Direct-verified star/version figures this session:** OpenSpec 62.4k★, spec-kit 123.6k★, ArchUnit v1.4.2 (2026-04-18), ArchUnitTS v2.3.3, Spring Modulith 1.4 GA (2026-03-27), SonarQube Architecture Management GA in 2026.4 (2026-05-20), Context Mapper DSL v6.12.0, import-linter v2.7, Turborepo Boundaries in 2.4.2. **Treated as soft (search-snippet or vendor-blog only):** superpowers/GSD/BMAD star counts; Riftmap and CodeGraph/GitNexus adoption stats (promotional); Kiro "drift detection" capability (review-claimed, absent from official docs). Star counts elsewhere are inherited from the prior survey and not re-verified.

---

## Takeaways

*One-screen recap — evidence is in the parts above.*

**The one-liner.** A week ago the survey's headline was *"jim's biggest wins are structural gaps it hasn't built yet."* Those gaps are built. jim now carries a **living, verifiable, contract-checked architectural specification across the entire build → review → fold-back loop** — and the real competition for those surfaces isn't other SDD skills, it's mature engineering disciplines (architecture conformance, DDD context mapping, contract testing, SDLC telemetry) that ship as *separate, deterministic, un-integrated* tools.

**What's genuinely novel** (as composites — every ingredient has an incumbent): the intent-authoritative fold-back loop; the two-face design-time contract graph with a unified finding taxonomy; the criticality-gated read-only judge + the five-outcome honesty taxonomy + **retirement mode**; per-AC + omission-hunting + verdict-trajectory review; an *evolvable* partition that never moves code; and a content-free, containment-not-detection SDLC ledger.

**What to claim, and not.** Claim the **composites and the venue** (design-time, in-repo, integrated, human-in-the-loop). Do **not** claim reconcile / join / blast-radius / mechanical-floor as inventions — Pact BDCT, Riftmap, and SonarQube 2026.4 will each be cited. The credibility of the novelty claims depends on stating the boundaries honestly (Part 6).

**The convergence signal.** Thoughtworks (Assess ring), the Evolutionary-Architecture canon ("AI fitness functions" as future work), SonarQube and spec-kit (drift/convergence shipped mid-2026), and Liza (auditable AI-pipeline state) are all moving toward jim's theses. The ecosystem is validating the direction; jim's edge is that it has already *integrated* these into one transparent, human-gated pipeline — and its compounding institutional memory just became executable.

**Highest-leverage remaining work** (unchanged by the blueprint ship): the **meta / skill-authoring craft** win (description = when-only; RED/GREEN/REFACTOR for skills) — cheapest, and it now lifts fourteen-plus skills at once — and an **EARS / WHEN-THEN testable-AC option** for jim:spec, newly valuable because jim:review's per-AC investigators consume those criteria directly.
