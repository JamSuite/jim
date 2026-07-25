---
title: "Harden /jim:spec Against Implementation Creep"
type: feature
group: "sdlc"
id: "015"
status: approved
origin:
  - docs/brainstorms/20260515-jim-spec-refinement.md
  - docs/specs/sdlc/012-spec-refinement/research.md
---

# 015 Harden /jim:spec Against Implementation Creep

## Overview

Strengthen `/jim:spec` and `@jim:pm` so that draft specs consistently describe user-observable behavior, with technical suggestions captured as architect-facing context rather than smuggled into Acceptance Criteria. Four tightly-coupled changes ship together: a Socratic validation gate, an "Implementation Insight" Handoff section in the spec template, an Over-specification anti-pattern in the existing anti-pattern catalogue, and persona hardening in the PM agent that codifies the PM/architect responsibility split.

## Problem Statement

Developers using `/jim:spec` see implementation details — function shapes, file paths, library choices, technology preferences — leak into Acceptance Criteria. This forces the architect to re-derive user intent from technical prescription during planning, and contradicts jim's claim of grounding implementation in user needs (VISION.md). Currently the discipline depends on the operator manually grounding the PM agent on each invocation with a custom prompt prefix; the system should enforce the separation structurally instead of relying on the operator.

External validation: isoform.ai's *The Limits of Spec-Driven Development* identifies this exact pattern — specs that fixate on *"hows — field definitions, schemas, signatures"* rather than intent — as a recognized LLM-era SDD failure mode. The four-pillar refinement positions jim's spec discipline as defense against that failure mode.

## User Stories

- As a developer using `/jim:spec`, I receive draft specs whose Acceptance Criteria describe user-observable behavior, so that my architect can plan without re-litigating implementation choices.
- As a developer using `/jim:spec`, I see technical suggestions surfaced during interview routed to a clearly-labeled "Implementation Insight" section, so that promising ideas reach the architect without polluting the requirements.
- As a developer reviewing a draft spec, I can see which items the PM deflected to Handoff and why, so that I can correct the PM's judgment when it gets a call wrong.

## Acceptance Criteria

- [ ] Draft specs produced by `/jim:spec` describe Acceptance Criteria as user-observable behavior — no function signatures, library choices, file paths, or technology names appear as required outcomes unless (a) cited as External Constraints with a sourced category, or (b) the spec is `type: refactor` and the technical artifact names a desired-state element traceable to the `Refactor Rationale` section.
- [ ] When the user surfaces a technical suggestion during interview, the PM acknowledges the suggestion, levels it up to the underlying user need, and records the technical proposal as an Implementation Insight rather than embedding it in an AC.
- [ ] Draft specs include a `## Research & Architecture Handoff` section whenever Implementation Insights exist, with each Insight traceable to a specific AC and labelled with the reason for deflection.
- [ ] Before the PM presents a draft, every AC has been classified as Functional Requirement, External Constraint, or Implementation Detail; items classified as Implementation Detail have been moved to the Handoff section.
- [ ] Specs that include External Constraints cite a source category from the closed list (External API/Protocol, Regulation/Compliance, Architecture Decision, Upstream Spec, Interoperability, or Hardware/Environment); constraints without a sourced category are reclassified to the Handoff.
- [ ] User Stories in draft specs name a specific role, an observable action, and a real-world benefit (Connextra form); orphan ACs that do not trace to a User Story are flagged before the draft is presented.
- [ ] After presenting a draft, the PM surfaces conversationally which items were deflected to the Handoff and why — alongside the durable in-spec audit trail.
- [ ] The PM's classifications, deflections, and source-attributions are presented as recommendations the user can accept, override, or revert before the spec is finalized — the user has final authority over what stays in the spec, what moves to the Handoff, and whether a cited source is considered authoritative.
- [ ] When the PM observes that an AC, User Story, or Implementation Insight appears to extend beyond the user's original ask, it raises the concern conversationally and defers the decision to the user — scope is the user's call, not the PM's.
- [ ] The PM agent's instructions establish an explicit separation between the PM's responsibilities (user stories, ACs, requirements, UI sketches) and the architect's responsibilities (implementation choices, file structure, library selection), without the user needing to assert this manually each invocation.
- [ ] Specs continue to pass the existing six anti-patterns (Kitchen Sink, Vague Criteria, Solution Masquerading, Empty Out of Scope, Premature Tech, Wrong Type). Specs additionally pass an Over-specification check whose calibration is spec-type-aware: for `feature` and `bug` specs, ACs that name file paths, function signatures, library choices, or technology names fail unless cited as External Constraints; for `refactor` specs, ACs naming technical artifacts pass when they trace to a `Refactor Rationale → Desired State` entry, and fail when they describe migration *procedure* (which routes to Handoff).

## Out of Scope

- Retrofitting historical specs (`docs/specs/sdlc/001-014`) to the new template — they remain as-is.
- **Consumer-side integration is deferred to a follow-on spec.** This spec is scoped to the producer side (PM / `/jim:spec`); no changes to `/jim:plan`, `@jim:architect`, or any other consumer of the new Handoff section are included. Until the follow-on spec lands, the Handoff section is a write-only artifact — the architect reads it as plain markdown like any other section, with no formal resolution workflow.
- No changes to `/jim:research`, `/jim:build`, `/jim:debug`, `/jim:vision`, `/jim:roadmap`, `/jim:arch`, `@jim:researcher`, or `@jim:coder`.
- Hard blocking of `/jim:spec` on validation failure — the PM continues to use silent self-check and inline correction, not a stop-the-line gate.
- Adding bug-specific or refactor-specific Handoff logic — the Handoff section applies universally and is type-agnostic. The Over-specification probe consults spec type per AC #11; no other probe varies by type, and no changes are made to the existing Defect Profile or Refactor Rationale section templates.
- A test-runner harness for prompt content (PM agent and skill body validation remains by checklist via `@jim:meta` skills, not by bash tests).
- Importing primary-source full text from IEEE 830, ISO 29148, Volere, or Wiegers into the repository — `spec-dod.md` cites short verbatim phrases from accessible sources; paywalled standards are referenced by name with training-paraphrase wording the architect should verify before locking.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

*(This Handoff section is itself the first instance of the new template feature being introduced by this spec — included here to model the convention and to capture an architecture-level decision surfaced during the interview.)*

### Insight 1: Where the validation logic lives

- **Relates to AC:** *"Before the PM presents a draft, every AC has been classified..."* (AC #4) and the related validation ACs (#5, #6, #7).
- **Surfaced as:** Brainstorm proposed replacing the existing silent self-check inside `/jim:spec` with the new Socratic DoD invocation. During spec review the user raised the alternative of a dedicated `/jim:spec-check` skill.
- **Levelled-up requirement (already in the ACs):** The validation runs before the draft is presented and classifies every AC into the three tiers. The spec deliberately does *not* constrain *where* in the codebase that logic lives.
- **Deflection reason:** Razor — multiple valid implementations satisfy the validation ACs. Architectural choice belongs in the plan, not the spec.
- **Architect note:** Three viable options to weigh:
  - **A — Inline replacement.** Replace the existing silent self-check inside `/jim:spec` with the Socratic DoD invocation. Simplest; tightly coupled to `/jim:spec`'s lifecycle. Cannot audit hand-edited or historical specs.
  - **B — Dedicated `/jim:spec-check` skill.** A standalone skill invocable against any spec.md. Reusable for hand-edited specs, historical audits, and DoD development. Adds a new skill surface and an associated agent binding.
  - **C — Hybrid.** Standalone `/jim:spec-check` skill that `/jim:spec` invokes at validation via `Skill(jim:spec-check)`. Same logic, two entry points. Uses jim's established skill-to-skill invocation pattern (see `ARCHITECTURE.md` → Skill Invocation, validated by spec 014).
- **Routing hint:** Architect to decide.

### Insight 2: Widening the Allowed Source list

- **Relates to AC:** *"Specs that include External Constraints cite a source category from the closed list..."* (AC #5).
- **Surfaced as:** User test case during spec review — *"if I add a technical requirement and cite our coding-conventions doc as the source, should it pass the DoD?"*
- **Levelled-up requirement (already in AC #5):** Constraints must cite a source from a closed list of recognized authoritative categories.
- **Deflection reason:** Constraint-Sourcing — the brainstorm's current draft of the Allowed Source list reads "Architecture Decision (`ARCHITECTURE.md` entry)" which is narrower than the spirit intends. Project-level convention docs (e.g., `CONVENTIONS.md`, `HOWTO_RUST_LAYOUT.md`, style guides) serve the same epistemic role.
- **Architect note:** When drafting `spec-dod.md`, widen the relevant category to roughly *"Architecture Decision or Documented Project Convention"* — and include a Good/Bad example pair that distinguishes *"output adheres to convention X"* (constraint, passes DoD) from *"refactor module Y to comply"* (implementation procedure, routes to Handoff).
- **Routing hint:** Architect to incorporate into `spec-dod.md` content during plan/build.

### Insight 3: Overlap with existing `SKILL.md` behavior — Instruction Shadowing risk

- **Relates to AC:** The two newly added ACs on user-authority and scope-vs-original-ask flagging (the two ACs immediately following the deflection-summary AC).
- **Surfaced as:** During spec review, user verified that current `skills/spec/SKILL.md` already partially covers these principles — Step 6's *Anti-pattern flagging* technique handles conversational scope-creep raising (Kitchen Sink example: *"This is getting broad — should we split off the search piece?"*); Step 10's approval flow gives the user final authority. The newly added ACs explicitly elevate user-authority and scope-vs-original-ask flagging to first-class principles despite known overlap.
- **Levelled-up requirement (in ACs):** The principles must be present — *how* they're expressed (which step, which prompt) is implementation.
- **Deflection reason:** N/A — kept as ACs by user decision; flagged here so the architect can resolve the textual duplication during plan.
- **Architect note:** `ARCHITECTURE.md` → Anti-Patterns warns against **Instruction Shadowing** (repeating rules in multiple places). Three viable resolutions:
  - **A — Augment existing steps.** Add language to Step 6's anti-pattern technique and Step 10's approval prompt that surfaces the new principles explicitly. Minimal new text, no new section.
  - **B — Extract a shared "Principles" section** in `SKILL.md` or a `references/spec-principles.md` doc that both Step 6 and Step 10 reference. Cleanest separation, slight progressive-disclosure cost.
  - **C — Accept textual duplication** as load-bearing reinforcement (the principles are important enough to repeat). Simplest, breaks the Instruction Shadowing anti-pattern.
- **Routing hint:** Architect to decide; recommend A or B over C.

### Insight 4: Verbatim Tier-1 source wording available

- **Relates to AC:** *"Draft specs produced by /jim:spec describe Acceptance Criteria as user-observable behavior..."* (AC #1) and *"Specs continue to pass... Over-specification check..."* (AC #11), plus the Socratic-DoD validation ACs (#4, #5).
- **Surfaced as:** Research session located GitHub spec-kit's `templates/commands/specify.md` as the closest direct peer to `/jim:spec`, with verbatim Razor wording, success-criteria gates, and a bad-example list flagged in research as *"usable verbatim in our Over-specification anti-pattern"*.
- **Levelled-up requirement (already in ACs):** ACs require user-observable / technology-agnostic behavior; the DoD enforces this via Socratic probes; the anti-pattern flags Over-specification conversationally.
- **Deflection reason:** Razor — wording choice for `spec-dod.md` and the Over-specification anti-pattern is implementation. The spec only requires the principles those artifacts encode.
- **Architect note:** Sourced grounding from spec-kit is available for the artifact wording and structure (versus paraphrasing from training) — three verbatim quotables plus one structural reference:
  - **Razor (verbatim):** *"Focus on WHAT users need and WHY. Avoid HOW to implement (no tech stack, APIs, code structure)."*
  - **Success-criteria gates (verbatim):** *"Measurable / Technology-agnostic / User-focused / Verifiable."*
  - **Bad-example list (verbatim):** *"API response time is under 200ms" (reframe: "Users see results instantly"), "Database can handle 1000 TPS", "React components render efficiently", "Redis cache hit rate above 80%"* — directly reusable in the Over-specification anti-pattern entry.
  - **Checklist structure (structural reference, not verbatim):** Spec Kit's Specification Quality Checklist is organized under three headings — *"Content Quality / Requirement Completeness / Feature Readiness"* — structurally identical to the Socratic DoD's organization. Citable as prior art in `spec-dod.md` for the DoD's overall section layout, alongside the three verbatim quotables above.
- **Routing hint:** Architect to incorporate into `spec-dod.md` and the new `spec-types.md` Over-specification entry during plan/build. See `research.md` Tier-1 section for the full GitHub spec-kit citation.

### Insight 5: Per-type calibration of the Over-specification probe

- **Relates to AC:** AC #1 (refactor-type carve-out for user-observable behavior) and AC #11 (Over-specification probe is type-aware).
- **Surfaced as:** User raised during post-approval review that legitimately technical specs — bootstrap, infra-wiring, refactor — would be choked by a naive Over-specification probe. Spec 011 (directive-vocabulary refactor) was cited as the exemplar: its ACs name exact file paths, line numbers, and code shapes as the load-bearing deliverable, traceable to the `Refactor Rationale → Desired State` section.
- **Levelled-up requirement (already in ACs):** The probe respects spec type. For refactor specs, technical artifacts pass when they trace to a Refactor Rationale entry; the probe distinguishes desired-state shape (passes) from migration procedure (routes to Handoff). Bootstrap and infra-wiring specs are *not* a new type — the PM treats them as underspecified `feature` specs and lifts them via the existing Recursive Drill-Down technique and the orphan-AC check (AC #6).
- **Deflection reason:** Razor — *how* the probe reads the `type:` frontmatter, and *where* in `spec-dod.md` the type-branching lives (Razor probe stage vs Three-Tier Classifier stage), is implementation.
- **Architect note:** Two design hooks to weigh:
  - The Three-Tier Classifier still runs for every AC across all types — Functional Requirement / External Constraint / Implementation Detail. Type-branching belongs at the Razor probe (technology-agnostic test): for `type: refactor`, the test mutates from "is this technology-agnostic?" to "does this trace to a `Refactor Rationale → Desired State` entry, and is it desired-state shape rather than migration procedure?".
  - The Over-specification anti-pattern entry in `spec-types.md` (plan Task 2) needs a paired Good/Bad example specific to refactor specs — e.g. Good: *"`auth.rs` is split into `auth/token.rs` and `auth/session.rs`"*; Bad: *"use `git mv` to move `auth.rs` then sed-rewrite the imports"*. The first names desired state; the second prescribes procedure.
- **Routing hint:** Architect to encode in `spec-dod.md` (plan Task 1) and the Over-specification entry in `spec-types.md` (plan Task 2). No new task needed.

## Open Questions

- [ ] **Story-Link Probe placement** — Should the orphan-AC check run within the same validation pass as the Razor, Delegation, and Constraint-Sourcing probes, or as a structural completeness check earlier in the spec lifecycle (e.g., at interview exit)? Defaulting to *same pass* for design cohesion; architect to confirm.
- [ ] **Cucumber/Gherkin Imperative-vs-Declarative source** — The brainstorm cited a Cucumber documentation URL that did not contain the imperative/declarative content; a fresh primary-source URL is needed before `spec-dod.md` quotes the distinction. Architect to locate during plan.
- [ ] **Tier-2 standard wording** — `spec-dod.md` will reference IEEE 830, ISO 29148, Volere, and Wiegers via training-paraphrased wording (primary sources not accessible during research). Architect should cross-check with primary sources before locking the DoD text.
- [ ] **DoD iteration model** — Should the Socratic DoD run as a single pass with inline correction (per brainstorm Step 9 draft) or as a bounded retry loop (per spec-kit's iterate-until-clean pattern)? Defaulting to *bounded retry* per the spec-kit precedent; iteration cap is the architect's call.
