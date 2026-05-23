# Brainstorm: Hardening jim:spec to prevent Implementation Creep

*2026-05-15*

## Context

The `jim:spec` skill works well, but we're seeing recurring **Implementation Creep**: technical design details (bash scripts, file paths, specific function shapes) leak into Acceptance Criteria. This creates friction for the Architect and violates the principle that a Spec defines the **What and Why**, not the **How**.

Reinforced by `feedback-spec-hygiene` (in user memory):
> Specs should describe user-observable behavior; implementation choices (IPC shapes, function signatures, error codes) belong in the plan. The test: would a different valid implementation still satisfy this AC? If yes, it belongs in the spec. If the AC is tied to one specific function shape, it's an implementation detail.

## Goal

Refine the `@jim:pm` agent and `/jim:spec` skill to maintain a strict product/user focus.

## Proposed Solution Pillars

1. **Spec Definition of Done (DoD)** — `skills/spec/references/spec-dod.md` (modeled after `research-dod.md`). Mandatory validation gate that flags "Black Box" violations and premature technical prescriptions.
2. **The "Safety Valve" (Handoff Section)** — `## Research & Architecture Handoff` in `spec-template.md`. Lets the PM park implementation ideas surfaced during interview *without* polluting ACs.
3. **Anti-Pattern Expansion** — Update `spec-types.md` to include "Design Leakage" and "Prescriptive ACs" as high-priority anti-patterns with Good/Bad examples.
4. **Persona Hardening** — Teach `@jim:pm` a "Pivoting" technique: acknowledge technical suggestions but route them to the Handoff section.

## Open Questions

- What specific "Design Leakage" patterns should the DoD look for?
- How do we structure the "Handoff" section so the Architect finds it useful without it becoming a "Ghost Plan"?
- How should the SKILL.md "Silent self-check" change to effectively use this new DoD?
- Can we create a "Product/User focus" checklist for the PM to use during the interview?

---

## Industry Grounding (load-bearing sources)

The "What vs. How" line we're trying to enforce is not novel — it's the bedrock of requirements engineering for 30+ years. Pinning to canonical sources so future contributors can audit our terminology against the field, and so the language we adopt aligns with what experienced developers already know.

| # | Source | Concept | Relevance to jim |
|---|--------|---------|------------------|
| 1 | **Wiegers & Beatty, *Software Requirements* (3rd ed.)** | Functional Requirement = "what the developer must build to enable users to accomplish their tasks." Warns against design constraints masquerading as requirements. **Testability standard: if you can't test it without looking at source code, it's an implementation detail.** *(Book reference; not URL-verified this session.)* | Foundation for the "Black Box" AC check. |
| 2 | **Abstracta, "Functional and Non-Functional Requirements"** ([source](https://abstracta.us/blog/software-testing/functional-and-non-functional-requirements/)) | Functional reqs answer *"What must the system do to fulfill business goals?"* NFRs describe *"how the system performs."* Categories: Availability, Security, Performance, Recovery, Compliance, Usability. | Confirms the **What vs How** boundary in modern industry vocabulary. |
| 3 | **Perforce, "10 Types of Non-Functional Requirements"** ([source](https://www.perforce.com/blog/alm/what-are-non-functional-requirements-examples)) | *"Non-functional requirements specify criteria that evaluate how a system performs a function, rather than the function itself."* Ten NFR categories: Security, Capacity, Compatibility, Reliability/Availability, Maintainability/Manageability, Scalability, Usability, Performance, Compliance, Environmental. | Grounds the **External Constraint** tier with industry-standard NFR taxonomy. *Compatibility* + *Compliance* are the categories that house ISO8601-style wire-format constraints. |
| 4 | **isoform.ai, "The Limits of Spec-Driven Development"** ([source](https://isoform.ai/blog/the-limits-of-spec-driven-development)) | Contemporary critique of LLM-era SDD: *"Reality changes faster than specs do."* SDD tooling today is *"optimized for parsing specs, not interpreting intent."* Specs that fixate on *"hows — field definitions, schemas, signatures"* miss the load-bearing intent. | **Directly validates jim's thesis.** Argues over-specification *is* the SDD failure mode jim's hardening prevents — worth citing in the eventual spec's Motivation. |
| 5 | **Hayakawa, *Language in Thought and Action* — Abstraction Ladder** | Methodology for moving from concrete (*"I want a Bash script"*) to abstract (*"I want a dependency-free automation"*). *(Book reference; not URL-verified this session.)* | Methodology for the PM's "Level Up" / Pivoting technique. |

**Established standards backing the razor** *(authoritative wording from training; primary sources paywalled — verify before locking the spec):*
- **IEEE 830** (Recommended Practice for SRS) — requirements must be *verifiable* and *implementation-independent*.
- **ISO/IEC/IEEE 29148** — formal term: **"implementation-independent requirements."**
- **Volere Requirements Specification Process** (Robertsons) — *"A Constraint is just an Implementation Detail with a Source."*

The last bullet is load-bearing: it tells us how the DoD distinguishes a legitimate constraint from leakage. **A constraint must cite its source** (external API contract, regulation, ARCHITECTURE.md entry, prior spec). No source → it's an implementation detail.

**Removed during this session (broken or wrong-page URLs):**
- ~~JAF Consulting, "Perils of Over-specification"~~ — original URL returned HTTP 404.
- ~~Perforce, "Functional vs. Non-Functional Requirements" (old URL)~~ — original URL returned HTTP 404. Replaced by the current Perforce blog above (#3).
- ~~Cucumber.io step-organization page (cited for Imperative vs. Declarative)~~ — URL loaded but covered step organization only, not the imperative/declarative distinction. The concept remains load-bearing — the architect should re-source it from a current Cucumber/BDD page (e.g., the Gherkin Reference or the BDD anti-patterns guide).

> *Aside: the formal-standards sources (IEEE 830, ISO 29148, Volere) are still good seeds for a follow-on deeper research session if the architect needs primary-source wording for `spec-dod.md`.*

---

## Locked: The Razor and the Three-Tier Model

### The Razor (Technology-Agnostic Test)

> **"If I changed the underlying technology or implementation entirely (e.g., swapped a CLI for a Voice UI, or Bash for Rust), would this requirement still be valid?"**
>
> - **YES** → It is an **abstraction** (a true requirement). Keep in spec.
> - **NO** → It is an **implementation** (over-specification). Move to Handoff.
> - **EXCEPTION** → It is a **Constraint** if it is a non-negotiable boundary *with a documented source* (external API, regulation, ARCHITECTURE.md entry, prior spec).

This is sharper than the earlier "different valid implementation" formulation because it forces a *category-level* swap (CLI → Voice UI), which catches subtler over-specification.

### The Three Tiers (the spine of the new DoD)

Every spec statement must classify as one of:

1. **Functional Requirement** — essential for the user to reach their goal. Passes the razor.
2. **External Constraint** — essential for the system to survive its environment (interoperability, security, compliance). Fails the razor but **cites a source**.
3. **Implementation Detail** — an internal choice that could be swapped without breaking #1 or #2. **Move to Handoff.**

This three-tier model becomes the spine of `spec-dod.md`: every AC, every Out-of-Scope item, every constraint statement gets classified. Tier 3 statements are auto-flagged as violations.

### Reframe: "Design Leakage" → "Over-specification"

"Design Leakage" implies binary (leaked / didn't). The real failure mode is **over-specification**: the AC may be *true*, but it's *more specific than the user need requires*. Industry term is "implementation-dependent requirement" (ISO/IEC/IEEE 29148). Adopting that vocabulary aligns jim with what experienced engineers already know.

---

## Field-Tested Workaround: The Prompt Prefix

Before any DoD lands, Adrian has been manually grounding the PM with prompt prefixes like:

> *"Remember, you are jim:pm. You are responsible for user stories, acceptance criteria, requirements, UI wireframe, etc. NOT IMPLEMENTATION DETAILS. If you have questions or ideas/suggestions about implementation, please make sure to highlight those and delegate them to jim:architect and/or jim:researcher to study and make the correct choice."*

This **works** in practice. Implication: the **minimum viable persona hardening** is to bake this language into `agents/pm.md` (Core Principles or Constraints section) — no DoD required to capture immediate value.

The DoD becomes additive rigor on top, not a prerequisite.

---

## DoD Style: Socratic, Not Anti-Pattern Checklist

Important reframe: the new `spec-dod.md` should **not** be a pattern-matching checklist ("no DB schemas, no API endpoints"). That style only catches violations we've already seen — it'll always miss the next novel one.

Instead, the DoD is **Socratic**: a structured interrogation the spec must survive. Each lens asks an open question; the spec passes by *answering*, not by *avoiding flagged phrases*.

### Proposed Socratic Lenses

1. **User Story Quality** — *What makes a good user story?*
   - Industry standard: **INVEST** (Independent, Negotiable, Valuable, Estimable, Small, Testable).
   - Connextra form ("As a [role], I [want] [goal], so that [benefit]") — every clause grounded?
   - Test: is `benefit` a real outcome the user cares about, or technical filler?

2. **Requirement Quality** — *What makes a good requirement?*
   - ISO/IEC/IEEE 29148 standard: **verifiable, unambiguous, atomic, implementation-independent.**
   - Apply the Razor: would a different valid implementation still satisfy this AC?
   - Wiegers testability standard: can you verify this without looking at source code?

3. **Implementation Creep Detection** — *Is anything here a decision the Architect should make?*
   - Run each AC through the three-tier classifier.
   - Tier 3 (Implementation Detail) → reroute to Handoff section, addressed to `@jim:architect`.

4. **Research Delegation Detection** — *Is anything here a question that needs investigation before a decision?*
   - Statements that assume a fact (e.g., "library X supports Y") → flag for `@jim:researcher`.
   - Distinguish "we know this is true" from "we're hoping this is true."

5. **Constraint Sourcing** — *Does every constraint cite its source?*
   - Volere standard: a constraint is an implementation detail with a source.
   - No source → reclassify as Implementation Detail → move to Handoff.

### Why Socratic Beats Checklist

- **Generalizes:** A new failure mode in 2027 still fails Lens 2 even if we never named it.
- **Teaches discipline:** The PM doesn't memorize forbidden phrases; it learns to interrogate.
- **Aligns with industry:** Mirrors how requirements peer-review actually works in mature engineering orgs.
- **Anti-patterns in `spec-types.md` keep their job:** they're for *in-interview conversational flagging* (step 6), not for *final validation* (step 9). Two different instruments, two different phases.

---

## The Three Socratic Probes (the "teeth")

The DoD interrogates the spec through three probes. Each probe is run against every AC; failure routes the AC to Handoff or escalates.

### 1. The Razor Probe
> *"If I replaced the current tech stack with a completely different one, would this AC still be mandatory? If yes, what is the external source that makes it so?"*

- YES + source cited → keep.
- YES + no source → Implementation Detail wearing a Constraint costume → Handoff.
- NO → over-specification → Handoff.

### 2. The Delegation Probe
> *"Does this AC describe a choice that an expert Architect could reasonably disagree with? If so, why am I making it here instead of delegating it?"*

The architect-disagreement test is sharper than "is this technical?" because it surfaces decisions disguised as facts. "Use ISO8601" looks like a constraint until you ask whether the architect could plausibly say "ISO8601 is wrong here, use Unix epoch." If yes → it's a decision, not a fact → Handoff.

### 3. The Story-Requirement Link Probe
> *"Does this requirement directly enable one of the User Stories? If it's orphaned, is it a hidden implementation detail?"*

Bidirectional check: every AC traces to a story, every story has ≥1 AC. Orphan ACs are almost always either:
- A hidden implementation detail (the most common case), or
- A missing user story (rare — add the story if it's a real need).

This probe is already foreshadowed in `feedback-spec-hygiene`: *"Cross-check every AC against the User Stories: if no user story justifies it, either add the story or drop the AC."* The DoD formalizes it.

**Mandatory ACs are exempted** (e.g., "Regression test covers the reported scenario" for bugs, "Existing tests pass without modification" for refactors). These trace to the spec *type*, not to a story.

---

## The Active Pivot Method (Persona Hardening)

The PM agent gets a concrete 3-step procedure for handling technical content surfaced during interview — not just a "passive reminder" to suppress it.

### The Level-Up Method

1. **Intercept** — Identify a technical suggestion (from user or self).
2. **Ladder Up** — Ask *"What goal does this technology enable?"* until you reach a functional requirement.
3. **Bifurcate** —
   - **Requirement** → write into the AC (technology-agnostic form).
   - **Technology** → write into Handoff as an **"Implementation Insight"**.

### Worked Example

- **Intercept:** User says *"add a bash script that reads `pending_ingest`."*
- **Ladder Up:** *"What does the script let you do?"* → *"Process queued items without manual SQL."* → *"Automate ingestion of pending items."*
- **Bifurcate:**
  - **AC (spec):** *"Queued ingestion items are processed without manual intervention."*
  - **Implementation Insight (Handoff):** *"User suggested a bash script reading `pending_ingest`. May be the simplest path — architect to evaluate vs. Rust subprocess or alternatives."*

### Why This Solves the "Ghost Plan" Problem

Every Handoff entry is **traceable back to an AC**. It's not floating tech ideas — it's context the architect gets *about a deliberately under-specified AC*. This is the structural property that prevents the Handoff from becoming a shadow plan: it has no standalone agenda, only annotations on requirements.

---

## What Just Got Locked

| Question | Resolution |
|----------|------------|
| The Razor | Technology-Agnostic Test (CLI ↔ Voice UI, Bash ↔ Rust swap) |
| Classification model | Three tiers: Functional / External Constraint / Implementation Detail |
| Constraint validity rule | Volere: every constraint cites its source |
| DoD style | Socratic probes (Razor, Delegation, Story-Link), not anti-pattern matching |
| Anti-pattern role | Stays in `spec-types.md` for in-interview conversational flagging — *not* used in final validation |
| Persona hardening minimum | Bake the field-tested prompt prefix into `agents/pm.md` |
| Persona hardening method | The 3-step Level-Up Method (Intercept → Ladder Up → Bifurcate) |
| Handoff section shape | Per-AC "Implementation Insight" entries, each traceable to a requirement |
| Vocabulary alignment | Adopt RE-standard terms: implementation-independent, INVEST, ISO 29148, Volere |

## Closing Decisions (formerly Still Soft)

### 1. Prompt-Prefix Location in `agents/pm.md`

**Resolution:** Add a new section `## Engineering Standards`.

- Not "Core Principles" (too broad).
- Not "Constraints" (frames it as a restriction on the agent's tools).
- "Engineering Standards" frames it as a **professional commitment the PM makes to the Architect**. Sets tone of the relationship as Handoff, not Directive.

### 2. Add "Over-specification" Anti-Pattern to `spec-types.md`

**Resolution:** Yes. Two-layer defense:

- **Step 6 (interview loop)** uses the anti-pattern for conversational in-flight flagging — easier to ask the user *"Why do you need Bash?"* in real-time.
- **Step 9 (Socratic DoD)** acts as the final gate to catch anything the interview missed.

### 3. SKILL.md Step 9 — Socratic Self-Check (proposed text)

```markdown
### 9. Socratic self-check

Before presenting, read `references/spec-dod.md` and perform a Socratic audit
of the draft. Run every AC and Constraint through the three-tier classifier
(Functional / External Constraint / Implementation Detail).

1. Apply The Razor Probe and The Delegation Probe to every AC.
2. Apply The Constraint Sourcing probe to every technical boundary.
3. If a Tier 3 (Implementation Detail) is found, Bifurcate: Level-up the AC
   to an abstraction and move the detail to the Handoff section.
4. Fix any gaps inline before proceeding. Do not tell the user about the
   self-check — just present a clean, abstract draft.
```

*Note:* The Story-Link Probe (orphan AC detection) isn't named in this draft. Worth confirming during plan whether it lives at step 9 (alongside the other probes) or as a structural check earlier in the validation flow.

---

## Brainstorm Closed — Ready for Handoff

The four pillars now have concrete resolutions backed by industry standards (IEEE 830, ISO 29148, Volere, INVEST, Gherkin BDD, Hayakawa). Remaining work is design-and-write, not brainstorm.

**Suggested next steps:**
1. `/jim:research` — formal RE literature grounding (Wiegers, IEEE 830, ISO 29148, Volere, Gherkin) to produce precise wording for `spec-dod.md`.
2. `/jim:spec` — scope the four-pillar refinement work as a structured spec (link this brainstorm as `origin:`).
3. `/jim:plan` then `/jim:build` once the spec is approved.

---

## Good User Story — Definition & Probes

**Standard:** Connextra format + INVEST. Load-bearing clause is the **benefit** — "so that X" is where most stories fail by carrying technical filler.

### Definition

> A good user story names a **specific role**, an **observable action** that role takes, and a **real-world benefit** that role gains — independent of how the system is built.

### Socratic Probes (per story)

| Probe | Question | Failure signal |
|-------|----------|----------------|
| **Role Probe** | Is the role a specific user type, or generic "user"? | "As a user" → vague |
| **Action Probe** | Is the action externally observable? | "system stores X" → internal mechanism |
| **Benefit Probe** | Would this benefit show up in a non-technical conversation with the user? | "so that the system has logging" → technical filler, not real benefit |
| **Removal Test** | If we delete this story, what user outcome is lost? | "Nothing tangible" → story is fake |
| **INVEST scan** | Independent, Negotiable, Valuable, Estimable, Small, Testable | Compound stories ("I can A and B") fail Atomic |

---

## Good Requirement (AC) — Definition & Probes

**Standard:** ISO/IEC/IEEE 29148 — *verifiable, unambiguous, atomic, implementation-independent*.

### Definition

> A good acceptance criterion describes **externally observable behavior** that any reasonable implementation could satisfy, stated precisely enough that two readers would agree on whether the system passes.

### Socratic Probes (per AC)

| Probe | Question | Failure signal |
|-------|----------|----------------|
| **Measurability** | Is there a pass/fail criterion observable from outside? | "works well," "feels fast" → existing Vague Criteria anti-pattern |
| **Atomicity** | Does this AC bundle multiple requirements? | "X and also Y" → split |
| **Implementation-Independence** | (The Razor.) Would a tech-swap leave this valid? | Names a function/file/library/protocol → over-specified |
| **Ambiguity** | Could two readers test this differently and both be right? | "appropriate," "reasonable" → underspecified |
| **Story-Link** | Which User Story does this AC enable? | Orphan → suspect implementation detail |

---

## Allowed Sources for Technical Constraints

A constraint without a source is an implementation detail in costume (Volere). The DoD needs a **closed list of legitimate source categories** — outside this list, the constraint is reclassified to Handoff.

### Allowed Source Categories

1. **External API / Protocol contract** — name the API (e.g., "ISO8601 required by Stripe API v2").
2. **Regulation / Compliance** — name the regulation (e.g., "GDPR Article 17 right-to-erasure").
3. **Architecture decision** — cite the `ARCHITECTURE.md` section.
4. **Upstream spec** — link to the approved spec that mandates it.
5. **Interoperability / Wire-format compatibility** — point to the existing format spec or contract.
6. **Hardware / Environment** — name the platform constraint (e.g., "air-gapped Linux deployment per ops policy").

### Not Allowed (auto-deflected to Handoff)

- "Agent preference" / "feels right" / "is simpler"
- Implicit team conventions without an ARCHITECTURE.md entry
- Style preferences without a documented source
- "We've always done it this way" (historical inertia)

This list goes in `spec-dod.md` as a literal table the PM cross-checks against.

---

## Auditable DoD: Showing Why Things Moved

If the DoD is fully silent (current step 9 pattern), the user can't see why an AC went to Handoff vs. stayed in spec. Two complementary audit channels:

### 1. Durable Audit Trail (lives in the spec)

Every Handoff entry records its **deflection reason** — which probe failed and how. This is permanent context for the architect (and for future refactors of the spec).

### 2. Conversational Validation Report (shown at present)

When the PM presents the draft, it includes a short note alongside it — *only* listing what was deflected and why. Not the full interrogation, just the outcomes:

> *"During validation, I moved 3 items to Handoff:*
> - *'Use bash for the script' — failed Constraint Sourcing (no allowed source cited)*
> - *'Reject inputs with X-category error' — failed Razor Probe (function-shape decision)*
> - *'Return within 200ms' — kept; sourced to ARCHITECTURE.md latency budget."*

This makes the silent self-check **semi-visible** — the user gets oversight without being buried in interrogation transcripts.

---

## Refined Handoff Template: The "Implementation Insight" Bucket

The Handoff section is **not a trash can**. It is a positive artifact for the architect: structured context about deliberately under-specified ACs. Treat as **starting points to evaluate**, not directives.

### Template

```markdown
## Research & Architecture Handoff

*Implementation insights surfaced during interview. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point
to evaluate, not a directive.*

### Insight {N}: {short title}

- **Relates to AC:** "{paraphrased AC}" (AC #{N})
- **Surfaced as:** {what the user/agent originally proposed}
- **Levelled-up requirement (in AC):** {how it became spec-level}
- **Deflection reason:** {Razor / Delegation / Story-Link / Constraint-Sourcing}
- **Architect note:** {open consideration, alternatives worth weighing, risks}
- **Routing hint:** [Architect to decide | Researcher to investigate | Candidate constraint pending sourcing]
```

### Why This Shape

- **Every entry traces to an AC** → no Ghost Plan (the Handoff has no standalone agenda).
- **Deflection reason is recorded** → audit trail (see above).
- **Routing hint** → architect knows whether this is a design choice they own, a research question to delegate, or a constraint that just needs a source to be promoted back into the spec.
- **"Surfaced as" + "Levelled-up requirement"** → preserves the Hayakawa Ladder context so the architect understands both the user's original intuition *and* the abstraction the PM extracted from it.

### What Goes Here

- Technical proposals from the user that levelled-up into ACs (Bifurcate output).
- Statements that failed a Socratic probe and got deflected.
- "Candidate constraints" — proposed constraints without a sourced category (architect can promote back to spec by sourcing them).
- Open questions about implementation that aren't research-worthy enough for a `/jim:research` session but the architect should weigh.

### What Does NOT Go Here

- Actual exclusions ("we will not build X") → those belong in `## Out of Scope`.
- Research-grade open questions → those go to a `/jim:research` artifact.
- Resolved decisions → those go in the plan, not the spec's Handoff.

