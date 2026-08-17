---
name: spec-check
description: >
  Audit a draft spec.md against the Socratic Definition of Done — classify
  every AC into one of three tiers, run the four Socratic Probes (Razor,
  Delegation, Story-Link, Constraint-Sourcing), and return structured audit
  outcomes the caller can apply. Use when the user invokes /jim:spec-check
  against a spec.md path, or when /jim:spec invokes the audit at Step 9 via
  Skill(jim:spec-check). Do not use for spec creation (/jim:spec), planning
  (/jim:plan), or implementation (/jim:build).
agent: pm
argument-hint: "<path to spec.md>"
allowed-tools: Read, Edit
---

# /jim:spec-check

Audit a draft spec against the Socratic Definition of Done.

*(The `agent: pm` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Argument Routing

Use `$ARGUMENTS` to determine the target spec path.

| Input | Behavior |
|-------|----------|
| Empty | Ask: "Which spec should I audit? Provide the path to spec.md or its directory." |
| Path ending in `spec.md` | Use as the target. |
| Directory path | Look for `spec.md` inside; if missing, stop and report. |

`$ARGUMENTS` does **not** auto-forward across skill-to-skill invocation. When `/jim:spec` calls `Skill(jim:spec-check)`, it passes the resolved spec.md path as the Skill tool's `args` parameter, and that becomes this skill's `$ARGUMENTS`.

## Process

### 1. Read the target spec

Read the resolved `$ARGUMENTS` path. Capture `type:` (feature, bug, refactor), `title`, `id`, `group`, and the full body of the spec.

### 2. Internalize the inlined DoD methodology

The DoD methodology is inlined into this SKILL.md per design decision (single consumer; avoids per-invocation permission prompts on plugin-relative reference reads). Read the **Definition of Done methodology** section below before classifying — it defines the Three-Tier Classifier, the four Socratic Probes, the Allowed Source list, the success-criteria gates, the type-aware Razor calibration, the Bounded-Retry mechanism, and the Status Assignment table you will return.

### 3. Classify every AC

For each acceptance criterion in the target spec, assign Tier 1 / Tier 2 / Tier 3 per the classifier. Note the rationale (which probe drove the call).

### 4. Run the four Socratic Probes

Per the **Definition of Done methodology** section below, run each probe against every AC:

- **Razor Probe** — apply the spec-kit Razor with type calibration. For `type: feature` / `type: bug`, the technology-agnostic swap test applies. For `type: refactor`, the swap test is replaced by Rationale-Traceability against `Refactor Rationale → Desired State` (spec 011 is the cited exemplar).
- **Delegation Probe** — would an expert architect reasonably disagree with this AC's framing?
- **Story-Link Probe** — every AC traces to a User Story. Mandatory ACs ("Regression test covers the reported scenario", "Existing tests pass without modification") are exempt.
- **Constraint-Sourcing Probe** — every External Constraint cites a source from the Allowed Source list.

### 5. Bifurcate Tier-3 findings

For each Tier-3 AC:

1. Level up the AC to the underlying user need.
2. Move the technical proposal to the spec's `## Research & Architecture Handoff` section as a new Implementation Insight, with deflection reason (Razor / Delegation / Story-Link / Constraint-Sourcing).
3. Use Edit to mutate the spec in place; preserve every section the user did not implicitly authorize you to change.

If the spec has no `## Research & Architecture Handoff` section and a Bifurcate is required, insert one between `## Out of Scope` and `## Open Questions`, matching the template shape.

### 6. Verify User Story Connextra form

Each User Story must name a specific role, an observable action, and a real-world benefit ("As a {role}, I {action}, so that {benefit}"). Flag non-Connextra stories conversationally — do not auto-rewrite them; the caller surfaces the flag to the user.

### 7. Return structured audit outcomes

Emit a deflection summary the caller can surface to the user:

- **Items moved to Handoff** — each with probe + reason.
- **Items kept as External Constraints** — each with cited source.
- **Orphan ACs flagged but kept** — mandatory ACs exempt.
- **Connextra-failing stories flagged** — text of the offending story.
- **Status** — `clean` or `residual` per the Status Assignment table.

The caller (either `/jim:spec` Step 9 or the user invoking this skill standalone) is responsible for bounded retry (cap 3) and final presentation. Do not narrate the audit — return outcomes structured for the caller's consumption.

## Definition of Done methodology

Inlined here as a single-consumer methodology to avoid per-invocation permission prompts on plugin-relative reference reads. Every draft spec passes this audit before presentation; residual issues after the bounded-retry cap surface conversationally at the caller's Step 10.

The DoD's overall organization mirrors GitHub spec-kit's *Specification Quality Checklist* — *Content Quality / Requirement Completeness / Feature Readiness* — cited here as structural prior art (non-verbatim attribution).

### The Three-Tier Classifier

| Tier | Name                   | Test                                                                                                  | Disposition                                  |
| :--- | :--------------------- | :---------------------------------------------------------------------------------------------------- | :------------------------------------------- |
| 1    | Functional Requirement | Passes The Razor — user-observable, implementation-independent. Traces to a User Story.               | Stay in spec ACs.                            |
| 2    | External Constraint    | Fails The Razor but cites a source from the Allowed Source list.                                      | Stay in spec ACs with source attribution.    |
| 3    | Implementation Detail  | Fails The Razor and has no sourced category, OR is a decision the architect could reasonably disagree with. | Move to `## Research & Architecture Handoff`. |

### The Razor (Technology-Agnostic Test)

> *Verbatim from GitHub spec-kit `templates/commands/specify.md`:*
> "Focus on WHAT users need and WHY. Avoid HOW to implement (no tech stack, APIs, code structure)."

Operationalized as a category-level swap test: *if the underlying technology were replaced entirely (CLI ↔ Voice UI, Bash ↔ Rust), would this requirement still be mandatory?*

- **YES + source cited** → Tier 2 (External Constraint).
- **YES + no source** → Tier 3 in disguise → Handoff.
- **NO** → Tier 3 (Implementation Detail) → Handoff.

**Type calibration.** For `type: refactor` specs, the Razor's technology-agnostic swap test is replaced by a *Rationale-Traceability* test: does the AC trace to a `Refactor Rationale → Desired State` entry, and is it desired-state shape (passes) rather than migration procedure (routes to Handoff)? ACs naming technical artifacts without a Rationale anchor are flagged regardless of type. See `docs/specs/sdlc/008-directive-vocabulary/spec.md` as the exemplar of a refactor spec whose load-bearing ACs the Razor must accept. For `type: feature` and `type: bug`, the swap test above applies unchanged.

### The Four Socratic Probes

#### 1. The Razor Probe

**Prompt:** Apply The Razor (with type calibration above) to every AC.

**Pass/Fail rubric:**

- Pass → Tier 1.
- Fail + cited source → Tier 2.
- Fail + no source → Tier 3 → Bifurcate.

#### 2. The Delegation Probe

**Prompt:** For each AC, ask: "Could an expert architect, given this user need, reasonably disagree with this AC's framing?"

**Pass/Fail rubric:**

- No reasonable disagreement → AC stays.
- Reasonable disagreement → Tier 3 → Bifurcate (architect chooses during planning).

#### 3. The Story-Link Probe

**Prompt:** For each AC, identify the User Story it serves. Mandatory ACs ("Regression test covers the reported scenario", "Existing tests pass without modification") are exempt.

**Pass/Fail rubric:**

- AC traces to a User Story → pass.
- AC has no parent story and is not mandatory → orphan; flag conversationally.
- User Story has no AC → underspecified; flag conversationally.

#### 4. The Constraint-Sourcing Probe

**Prompt:** For every AC tagged External Constraint (Tier 2), verify the cited source belongs to the Allowed Source list.

**Pass/Fail rubric:**

- Source matches a listed category → pass; AC stays as External Constraint with attribution.
- No source or source outside the list → reclassify Tier 3 → Bifurcate.

### Allowed Source Categories

A closed list. Constraints that cannot cite one of these are Implementation Details in disguise and route to Handoff.

1. **External API / Protocol** — name the API (e.g., "Stripe webhook signature verification per their docs").
2. **Regulation / Compliance** — name the regulation (e.g., "GDPR Article 17 — Right to Erasure").
3. **Architecture Decision or Documented Project Convention** — cite `ARCHITECTURE.md` section, `CONVENTIONS.md`, style guide, or `HOWTO_*` doc.
   - **Good (passes):** *"Output adheres to the bash-script conventions in `CLAUDE.md` → Bash scripts."* — constraint sourced to a project convention.
   - **Bad (routes to Handoff):** *"Refactor `skills/spec/SKILL.md` to comply with the bash-script conventions."* — this is implementation procedure, not a constraint; Bifurcate.
4. **Upstream Spec** — link to the approved spec (e.g., "spec 014's S3 probe result").
5. **Interoperability / Wire-format** — point to the format spec (e.g., "OpenTelemetry trace headers W3C spec").
6. **Hardware / Environment** — name the platform constraint (e.g., "WSL2 file-system case-insensitivity").

### Success-Criteria Gates

> *Verbatim from GitHub spec-kit:* "Measurable / Technology-agnostic / User-focused / Verifiable."

Every AC must pass all four gates. A failure on any one gate triggers the relevant probe (Razor for technology-agnostic / user-focused; Constraint-Sourcing for verifiable when the AC depends on an external source; Story-Link for user-focused when the AC has no parent story).

### Bounded-Retry Mechanism

Run the four probes against every AC. If a probe fails on any AC, apply Bifurcate (level up, move detail to Handoff) or correct inline. Re-run the probes against the mutated spec. Cap at **3 iterations** (matching spec-kit's `checklists/requirements.md` precedent); residual failures after the cap surface at the caller's Step 10 with the `residual` status.

The caller is responsible for orchestrating the retry — this skill returns audit outcomes once per invocation. The caller decides whether to apply outcomes and re-invoke.

### Status Assignment

| Status | Meaning |
| :--- | :--- |
| `clean` | All probes pass; no residual issues. |
| `residual` | Cap reached with N issues outstanding; surfaced conversationally at the caller's Step 10. |

## Validation Checklist

Before returning, verify:

- [ ] Every AC has been classified into exactly one tier.
- [ ] Every Tier-3 finding has been Bifurcated (Handoff entry added, AC reframed).
- [ ] Every External Constraint cites a source from the Allowed Source list.
- [ ] Connextra check has run on every User Story.
- [ ] Type-calibration was applied per the target spec's `type:` frontmatter.
- [ ] Audit outcomes returned in the structured shape (moved, retained, orphan, connextra, status).
