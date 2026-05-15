---
spec: "spec.md"
status: Active
date: "2026-05-15"
updated: "2026-05-15"
---

# Research: Requirements-Engineering Grounding for jim:spec Hardening

Primary-source wording and jim-internal conventions for the four-pillar refinement (Socratic DoD, Handoff section, anti-pattern expansion, persona hardening) drafted in the upstream brainstorm. Purpose: give the architect verbatim industry-standard language and exact anchor points so plan and template work can reuse them.

### Updates after spec scoping (2026-05-15)

Drifts: (1) SKILL.md anchor → location-neutral per Insight 1; (2) AC8/AC9 anchored at Step 6 / Step 10 per Insight 3; (3) Perforce 10 ↔ spec 6 = orthogonal axes, Insight 2 flagged. Story-link probe → spec Open Q #1. Status **Active**.

## Anchors

Files the plan will modify (existing) or create (new):

- `skills/spec/SKILL.md` — validation logic (Socratic DoD invocation). **Location per Handoff Insight 1 architect choice:** inline at existing Step 9 (L147–155) / dedicated `/jim:spec-check` skill / hybrid via Skill-tool pattern (`ARCHITECTURE.md` → Skill Invocation, validated by spec 014).
- `skills/spec/SKILL.md` Step 6 (L104–106) and Step 10 (L157–166) — **Insight 3 anchors.** Existing prose partially covers AC8 (approval) and AC9 (scope-creep flagging); architect resolves overlap here.
- `skills/spec/assets/spec-template.md` (L49–77) — Insert `## Research & Architecture Handoff` between Out-of-Scope and Open Questions; structured as "Implementation Insight" entries.
- `skills/spec/references/spec-types.md` (L60–110) — Append "Over-specification" as a 7th anti-pattern, matching the existing six-pattern shape.
- `skills/spec/references/spec-dod.md` (**new**) — Mirror `skills/research/references/research-dod.md`; encode the three Socratic Probes, the Three-Tier Classifier, and the Allowed Source list.
- `agents/pm.md` (L52–75) — Add `## Engineering Standards` section between Core Principles and Process; codifies the field-tested prompt prefix.

Reference shape for the new DoD:
- `skills/research/references/research-dod.md` (L1–53) — Checklist-style gate with phase-specific checks and status-assignment table. `spec-dod.md` should mirror this shape so it reads as a sibling.

## Local Patterns

- **DoD reference files live in `skills/{name}/references/{name}-dod.md`.** Only `research-dod.md` exists today; `spec-dod.md` takes the matching slot.
- **Anti-pattern entries in `spec-types.md`** follow a fixed shape: numbered heading, **What it looks like**, **Example**, **Remedy** subsections (see L62–110). The new Over-specification entry mirrors this.
- **SKILL.md step-9 rewrites stay in prose, not sentinel-directive syntax.** Step 9 is a procedural instruction, not a path gate, so the `SET name = !\`…\` / IF name != "NOT_FOUND" THEN` vocabulary (`ARCHITECTURE.md` → Logic-Flow Conventions) does not apply.
- **Progressive disclosure:** SKILL.md must stay ≤500 lines (`ARCHITECTURE.md` → Progressive Disclosure). Methodology goes in `references/spec-dod.md`, not inline.
- **Validation by checklist, not by bash test.** Agent and skill prompt content has no executable test harness — `meta-skill` and `meta-agent` validation checklists are the enforcement surface.

## Prior Art

### Tier 1 — Verbatim sources fetched this session

**Abstracta — *Functional and Non-Functional Requirements*** ([source](https://abstracta.us/blog/software-testing/functional-and-non-functional-requirements/))

> "Functional requirements describe the actions a system must execute. They answer: *'What must the system do to fulfill business goals?'*"
> "Non-functional requirements (NFRs) describe how the system performs under pressure — its reliability, scalability, and resilience."
> "Functional requirements describe *what* the system does" vs "Non-functional requirements describe *how* the system performs."

**Use:** anchors the **Functional Requirement (Tier 1)** definition in `spec-dod.md`'s three-tier classifier. The What/How phrasing is the cleanest one-sentence framing for the PM's silent self-check.

**Perforce — *10 Types of Non-Functional Requirements*** ([source](https://www.perforce.com/blog/alm/what-are-non-functional-requirements-examples))

> "Non-functional requirements specify criteria that evaluate how a system performs a function, rather than the function itself."

NFR categories: 1. Security · 2. Capacity · 3. Compatibility · 4. Reliability/Availability · 5. Maintainability/Manageability · 6. Scalability · 7. Usability · 8. Performance · 9. Compliance · 10. Environmental.

**Use — vs spec AC5's 6 source categories.** AC5's closed list (External API/Protocol, Regulation/Compliance, Architecture Decision, Upstream Spec, Interoperability, Hardware/Environment) is *brainstorm-derived* on a different axis than Perforce's: **Perforce = NFR *types* (subject matter); spec = *source categories* (provenance).** In `spec-dod.md`: spec's 6 = provenance gate; Perforce's 10 = illustrative vocabulary for Good/Bad examples. Compose, not merge.

**Handoff Insight 2 — widening "Architecture Decision".** Spec defers to architect whether to widen to *"Architecture Decision or Documented Project Convention"* (covering `CONVENTIONS.md`, style guides, `HOWTO_*` docs). No industry wording grounds the distinction — Volere's *constraint with cited source* is the closest anchor but does not enumerate document types. **Flag for architect during plan.**

**isoform.ai — *The Limits of Spec-Driven Development*** ([source](https://isoform.ai/blog/the-limits-of-spec-driven-development))

> "Reality changes faster than specs do."
> "Specs can't explain why it works that way. And the 'why' carries the real context."
> "SDD tools today are optimized for parsing specs, not interpreting intent."

Article identifies that current SDD tooling fixates on *"hows — field definitions, schemas, signatures"* rather than intent.

**Use:** contemporary external validation of jim's thesis. Cite in the spec's Problem Statement / Motivation to position the four-pillar hardening as defending against a recognized LLM-era SDD failure mode — not jim's idiosyncratic concern.

**addyosmani — *agent-skills/spec-driven-development*** ([source](https://github.com/addyosmani/agent-skills/blob/main/skills/spec-driven-development/SKILL.md))

Single-skill four-phase gated workflow (Specify → Plan → Tasks → Implement); spec carries Tech Stack + Code Style + Boundaries. Enforces What/How separation through **phase gating + human review**, not content separation. Notable techniques: **reframe-vague-to-testable** ("Make the dashboard faster" → "LCP < 2.5s on 4G"); **surface-assumptions-immediately** (list 3-5 silent assumptions, ask user to correct). Their "Boundaries" Always/Ask-First/Never is a *runtime permission system for the implementing agent* — **not** an AC classifier — orthogonal to our three-tier; **do not conflate in `spec-dod.md`**. Surface-assumptions is a follow-on candidate (see Open items); out of 015.

**Haberlah — *How to write PRDs for AI Coding Agents*** ([source](https://medium.com/@haberlah/how-to-write-prds-for-ai-coding-agents-d60d72efb797); WebFetch returned metered-summary preview — re-verify before quoting)

Argues for sequential phasing (Specify → Plan → Tasks → Implement), **mandatory research before spec** (LLM knowledge cutoffs), positive *and* negative boundary statements, AGENTS.md as emerging standard. **Use:** corroborates phase-gating. **Strategic divergence:** treats research as mandatory; jim's `/jim:research` is optional. Out of 015 — BACKLOG.

**GitHub spec-kit — `templates/commands/specify.md`** ([source](https://github.com/github/spec-kit/blob/main/templates/commands/specify.md); verbatim via user paste — WebFetch returned summaries and one prompt-injected response)

Closest direct peer to `/jim:spec`. Verbatim Razor: *"Focus on WHAT users need and WHY. Avoid HOW to implement (no tech stack, APIs, code structure)."* Success-criteria gates: **"Measurable / Technology-agnostic / User-focused / Verifiable"** — quotable in `spec-dod.md`. **Bad-example list usable verbatim in our Over-specification anti-pattern:** *"API response time is under 200ms" (reframe: "Users see results instantly"), "Database can handle 1000 TPS", "React components render efficiently", "Redis cache hit rate above 80%"*. Validation: per-spec `checklists/requirements.md`, 16 items across Content Quality / Requirement Completeness / Feature Readiness, **iterates up to 3 times**. Clarifications: **max 3 markers**, priority *"scope > security/privacy > UX > technical details"*. Philosophy: *"Make informed guesses, document assumptions"* — defaults aggressively rather than drilling.

**Use:** strongest Tier-1 anchor for Razor + Over-specification examples + validation shape. Architect decisions: (1) DoD iteration model — single-pass vs. bounded retry; (2) "informed guesses + Assumptions" stance opposes Recursive Drill-Down — follow-on.

### Tier 2 — Established standards (training-cited; verify before locking spec-dod.md)

| Source | Concept | Wording (paraphrased from training) |
|--------|---------|------------------------------------|
| Wiegers & Beatty, *Software Requirements* (3rd ed.) | Functional Requirement + Testability standard | "What the developer must build to enable users to accomplish their tasks." Testability: if you cannot verify it from observable behavior alone, it is an implementation detail. |
| IEEE 830 (superseded by 29148) | Verifiability + Implementation-Independence | Requirements must be *verifiable* and *implementation-independent*. |
| ISO/IEC/IEEE 29148:2018 | Implementation-Independent Requirements | Formal term replacing IEEE 830's language; each requirement must be "implementation-free" and "verifiable." |
| Volere Spec Process (Robertson & Robertson) | Constraint Definition | A Constraint is a non-negotiable boundary on the solution; differs from an implementation detail only by having a *cited source* (regulation, external contract, prior architectural decision). |
| Cucumber/Gherkin BDD community (Mabey, Wynne, et al.) | Imperative vs Declarative scenarios | Imperative scenarios narrate UI/implementation steps ("click this button"). Declarative scenarios describe user intent ("submit the form"). Declarative passes the Razor; imperative does not. |
| Bill Wake, "INVEST in Good Stories" (2003) | INVEST acronym | Stories should be **I**ndependent, **N**egotiable, **V**aluable, **E**stimable, **S**mall, **T**estable. |
| Connextra (2001) | Story template | "As a *[role]*, I *[want]* *[goal]*, so that *[benefit]*." The *benefit* clause is load-bearing — generic or technical filler indicates a false story. |
| Hayakawa, *Language in Thought and Action* | Abstraction Ladder | Concrete-to-abstract progression. Methodology for "Level Up": given a concrete technical proposal, ask *"what does this enable?"* until reaching a functional requirement. |

**Action for architect:** Cross-check the Tier 2 wording against primary sources (Wiegers book, ISO 29148 published text, Volere template at `volere.co.uk`) before promoting phrasings into `spec-dod.md`. Primary sources were not accessible from this research session.

## Security & Performance

- **No code paths changed.** Refinement targets agent prompts and skill methodology references. No runtime code, no user-input handling, no I/O.
- **Token cost (minor):** The Socratic DoD adds a reference-read pass at SKILL.md step 9 plus an inline interrogation. Estimate +5–10% on current `/jim:spec` token budget per invocation. Acceptable for jim's interactive use.
- **Behavioral risk:** Over-deferral to Handoff could produce thin specs. Mitigation already in design — the Over-specification anti-pattern in `spec-types.md` flags during the *interview* (Step 6), before the DoD (Step 9) ever runs, so most issues surface earlier and conversationally.

## Recommendations

### Alignment

Aligns with **VISION.md** — strengthens the spec phase, which the vision claims jim grounds in user intent ("documenting the 'how' and 'why' of the code"). Aligns with **ARCHITECTURE.md** → Plugin Conventions (the `references/{name}-dod.md` pattern is established by `research-dod.md`; spec-dod.md slots in cleanly). No locked-constraint divergence.

### Suggested bundle

**One spec covering all four pillars.** They are tightly coupled — the Socratic Probes reference the Handoff section; the Handoff structure depends on the Three-Tier Classifier; the anti-pattern flags the same failure the DoD validates; the prompt prefix is the runtime expression of the same model. Splitting risks partial implementations that do not compose.

### Suggested implementation order (for the plan)

1. **Persona hardening first** — bake the field-tested prompt prefix into `agents/pm.md` (`## Engineering Standards` section). Lowest risk, immediate value, no infrastructure dependency.
2. **Over-specification anti-pattern in `spec-types.md`** — adds the conversational flag (Step 6) without DoD infrastructure.
3. **Handoff template in `spec-template.md`** — defines the artifact the DoD will reference.
4. **Validation logic implementation (location per Handoff Insight 1)** — `spec-dod.md` plus the Socratic-DoD invocation, wired in at whichever location (Step 9 inline / dedicated `/jim:spec-check` skill / hybrid) the architect chooses during plan. Resolve Handoff Insight 3's Instruction Shadowing in the same pass (augment Step 6/Step 10, extract shared principles, or accept duplication).

### Principle ACs added during spec interview (AC8, AC9)

- **AC8 (user authority):** PM classifications/deflections/source-attributions are user-overridable.
- **AC9 (scope-vs-original-ask):** PM raises scope drift conversationally; defers to user.

**jim-internal principle additions** — no fresh external grounding (adjacent training concepts: human-in-the-loop advisory classifications; agile PO scope authority; Wiegers on customer-owned requirements). User judged them load-bearing as first-class ACs despite partial overlap with Step 6 / Step 10 — Handoff Insight 3 covers resolution.

### Open items for the spec phase

- Cucumber/Gherkin Imperative-vs-Declarative needs a fresh primary-source URL (brainstorm's was wrong-page). Architect verify from cucumber.io before locking `spec-dod.md`. *(Spec Open Q #2.)*
- **DoD iteration model (architect, 015 scope):** brainstorm Step 9 draft says *"Fix any gaps inline"* — single-pass. Spec-kit iterates **up to 3 times** to auto-resolve checklist failures. Architect picks consciously during plan; affects Socratic DoD prompt shape.
- **Follow-ons (not 015 scope):** (a) addyosmani's *surface-assumptions* technique — drill-down asks, assumption-surfacing names silent assumptions; (b) spec-kit's *make-informed-guesses* philosophy (aggressive defaults + Assumptions section, opposite stance to Recursive Drill-Down); (c) Haberlah's *mandatory* research before spec. All plausible SKILL.md Step 6 / `@jim:pm` candidates; flag for follow-on spec.
