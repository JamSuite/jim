---
spec: docs/specs/sdlc/003-pm-strategy/spec.md
type: feature
---

# Research: PM Strategic Skills — /jim:vision, /jim:roadmap, /jim:brainstorm

## Anchors

These are the files that must be created to implement 003-pm-strategy.

| # | File | Action | Why |
|---|------|--------|-----|
| **1** | `skills/vision/SKILL.md` | **Create** | `/jim:vision` skill — interview-driven VISION.md creation. Does not exist yet. |
| **2** | `skills/vision/assets/vision-template.md` | **Create** | Output template for VISION.md with all 7 sections. Does not exist yet. |
| **3** | `skills/roadmap/SKILL.md` | **Create** | `/jim:roadmap` skill — roadmap creation with Now/Next/Later buckets. Does not exist yet. |
| **4** | `skills/roadmap/assets/roadmap-template.md` | **Create** | Output template for ROADMAP.md with buckets, version anchors, goal-oriented framework. Does not exist yet. |
| **5** | `skills/brainstorm/SKILL.md` | **Create** | `/jim:brainstorm` skill — freeform ideation capture. Does not exist yet. |

### Secondary anchors (read, not modified)

| File | Role |
|------|------|
| `agents/pm.md` | The PM agent (from 002-pm-core) already declares `skills: [spec, vision, roadmap, brainstorm]` in its frontmatter. No modification needed — these skills will be picked up automatically when created. Currently a 1-line placeholder awaiting 002 build. |
| `VISION.md` | Empty placeholder at project root. The vision skill will write to this path. |
| `ROADMAP.md` | Empty placeholder at project root. The roadmap skill will write to this path. |
| `ARCHITECTURE.md` | Empty placeholder. Vision skill reads this for context if it exists. |
| `WORKFLOW.md` | Defines artifact locations, command reference, rules of engagement. Skills reference key paths from here. |
| `skills/spec/SKILL.md` | The spec skill (from 002-pm-core). Pattern reference for skill structure: frontmatter, process flow, validation, differential updates. Does not exist yet (awaiting 002 build). |
| `skills/meta-skill/SKILL.md` | Existing skill from 001-meta. Pattern reference for skill structure. `skills/meta-skill/SKILL.md:1-107` |
| `agents/meta.md` | Existing agent from 001-meta. Pattern reference for agent structure. `agents/meta.md:1-65` |
| `docs/prior-art/pm/pm-prior-art-research.md` | Detailed prior art study covering deanpeters, GSD, CCPM, SuperClaude. Primary reference for patterns. |

---

## References

| # | Source | Type | URL / Path |
|---|--------|------|------------|
| 1 | Claude Code Skills docs | Official | `https://code.claude.com/docs/en/skills` *(live; evolved since cited — custom commands have merged into skills, and the page now cites the `agentskills.io` open standard, 2026-07-17)* |
| 2 | Claude Code Sub-agents docs | Official | `https://code.claude.com/docs/en/sub-agents` |
| 3 | deanpeters/Product-Manager-Skills | Prior art repo | `https://github.com/deanpeters/Product-Manager-Skills` |
| 4 | open-gsd/gsd-core (formerly gsd-build/get-shit-done) | Prior art repo | `https://github.com/open-gsd/gsd-core` |
| 5 | 002-pm-core spec | Local spec | `docs/specs/sdlc/002-pm-core/spec.md` |
| 6 | 002-pm-core research | Local research | `docs/specs/sdlc/002-pm-core/research.md` |
| 7 | 002-pm-core plan | Local plan | `docs/specs/sdlc/002-pm-core/plan.md` |
| 8 | PM Prior Art Study Guide | Local research | `docs/prior-art/pm/pm-prior-art-research.md` |
| 9 | V1 PM agent | Local prior art | `docs/prior-art/V1SDLC/v1-agent-pm.md` |
| 10 | V1 PM skill | Local prior art | `docs/prior-art/V1SDLC/v1-pm-skill.md` |
| 11 | 001-meta research | Local reference | `docs/specs/sdlc/001-meta/research.md` |

## Reference Summary

### Claude Code Platform (refs 1-2)

Skills: `description` is always in context (trigger surface); body loads on invocation. `$ARGUMENTS` substitution passes user input. `agent:` field in skill frontmatter is a jim documentation convention only — not Claude Code routing. Plugin skills namespaced as `/jim:vision`, `/jim:roadmap`, `/jim:brainstorm`.

Agents: The PM agent's `skills` field preloads full skill content at startup. When 003 skills are created, they will automatically be preloaded into `@jim:pm` because `agents/pm.md` already lists them in `skills: [spec, vision, roadmap, brainstorm]`. No agent modification needed.

Key constraint: SKILL.md ≤ 500 lines. Templates go in `assets/`. Agent body ≤ 800 tokens — already allocated by 002-pm-core.

### 002-pm-core Patterns (refs 5-7)

The 002-pm-core plan establishes patterns that 003 skills must follow:

- **Skill frontmatter:** `name`, `description` (with triggering conditions), `agent: pm`, `argument-hint`
- **Process flow structure:** numbered steps in imperative form
- **Differential updates:** read existing artifact → summarize changes → ask before applying → use Edit not Write
- **Validation before presenting:** silent self-check against constraints, auto-correct, then STOP
- **Strategic doc handling:** read VISION.md/ARCHITECTURE.md as locked constraints; note absence gracefully
- **Writing style:** imperative, explain why, no personality soup, no instruction shadowing

The PM agent body (from 002 plan `docs/specs/sdlc/002-pm-core/plan.md:279-303`) delegates all methodology to skills. It says "Follow the active skill's instructions." This means each 003 skill must be self-contained — the agent body provides identity and paths, skills provide process.

### V1 PM (refs 9-10)

The v1 PM agent established baseline patterns for vision/roadmap that 003 evolves:

- **Interview pattern:** 1-2 questions at a time, recursive drill-down on vague statements
- **Differential updates:** summarize changes before applying
- **Dependency check:** read existing docs before modifying

V1 had no dedicated vision, roadmap, or brainstorm skills — these were handled ad-hoc by the PM agent. 003 formalizes them as structured skills with templates and clear process flows.

---

## Prior Art

| # | Source | What It Is |
|---|--------|------------|
| 1 | deanpeters positioning-workshop | Interactive skill: adaptive questions → Geoffrey Moore positioning statement |
| 2 | deanpeters roadmap-planning | Epics → prioritization (RICE/ICE/Kano) → sequencing workflow |
| 3 | deanpeters opportunity-solution-tree | Teresa Torres' OST framework for mapping opportunities to solutions |
| 4 | deanpeters CLAUDE.md | Skill design philosophy: 3 skill types, anti-patterns, writing style |
| 5 | GSD new-project | Creates PROJECT.md with vision, goals, constraints |
| 6 | GSD discuss-phase | Gray-area analysis: domain-specific ambiguity probes |
| 7 | GSD .planning/ structure | PROJECT.md + ROADMAP.md + REQUIREMENTS.md + STATE.md |
| 8 | CCPM context priming | Loading project state before a work session |
| 9 | Pimzino spec-steering-setup | Three steering documents: product.md, tech.md, structure.md |

## Prior Art Summary

### Vision Skill Patterns (refs 1, 5, 9)

**deanpeters positioning-workshop** is the closest prior art for `/jim:vision`. Key patterns:
- **Workshop facilitation protocol** — 3 entry modes: (1) Guided (one question at a time, default), (2) Context dump (user pastes known context, skip redundant questions), (3) Best guess (infer missing details, label assumptions explicitly). The vision skill should support all three.
- **5 adaptive questions with numbered options** — walks through Geoffrey Moore positioning framework: Target Customer → Underserved Need → Product Category → Key Benefit → Competitive Differentiation. Each question offers 3-5 numbered options adapted from prior answers, plus "Other (specify)" escape hatch.
- **Answers populate template slots** — each question maps to a specific output section (answer-to-slot mapping). The output template has named sections and placeholder syntax.
- **Anti-pattern triplets** — each skill defines anti-patterns as failure/consequence/fix: "For everyone" targeting (invisible positioning), feature-based needs (jumps to solution), vague categories ("software"), feature-based differentiation (copiable). The vision skill should define similar anti-patterns for self-check.
- **Validation:** "Read it aloud to 5 target customers. Do they recognize themselves?"
- **Key framing:** "Not a brainstorming session — it's structured discovery." This distinguishes `/jim:vision` from `/jim:brainstorm`.

The 003 spec's vision template has 7 sections (Problem Statement, Solution Statement, Target Audience, Competitive Landscape, Product North Star, Roadmap Trajectory, Non-Goals). The positioning-workshop pattern of walking through each section conversationally with bounded questions maps directly.

**GSD new-project** creates a PROJECT.md via structured interrogation before any planning begins. Uses a gate-based flow: questions → research → requirements → roadmap. Key: the vision document is produced from structured questioning, not freeform writing. GSD's PROJECT.md is always loaded as context for all subsequent commands. Jim achieves the same by having `/jim:spec` read VISION.md as a locked constraint.

**Pimzino** splits steering into 3 documents (product.md, tech.md, structure.md). Jim uses 2 (VISION.md, ARCHITECTURE.md). The spec explicitly scoped ARCHITECTURE.md to `@jim:architect`, so the vision skill focuses purely on product direction. No third document needed.

### Roadmap Skill Patterns (refs 2, 7)

**deanpeters roadmap-planning** is a workflow type (not interactive) — it orchestrates 5 phases: Gather Inputs → Define Initiatives → Prioritize → Sequence → Communicate. Key distinction: the 003 spec explicitly excludes prioritization frameworks (spec line 157: "the roadmap skill helps organize and sequence, but does not impose a scoring framework"). Carry forward: the sequencing UX, linking roadmap items to specs, and the anti-patterns:
- Feature-driven roadmap (no outcomes) — listing features without strategic context
- Roadmap as commitment — treated as waterfall contract, can't pivot
- No dependencies mapped — sequencing ignores technical interdependencies
- Solo PM roadmap — created in isolation
- The framing of roadmap as "strategic communication tool, not a feature list"

**GSD .planning/ROADMAP.md** uses phase-based structure with status tracking. Key patterns:
- Phases have clear status values (not started / in progress / complete)
- Phases link to requirement IDs with coverage validation
- Fixed phase boundaries — discussion cannot expand scope, only clarify within it. New ideas are deferred, not rejected.
- Roadmap stays concise — detailed scope lives in requirements, not the roadmap

The 003 spec's Now/Next/Later buckets with version anchors is simpler than GSD's phase model. This is intentional — the spec says "short, concise list that's easy to read" (spec line 83). The architect should resist adding phase metadata complexity.

### Brainstorm Skill Patterns (refs 3, 6)

**deanpeters opportunity-solution-tree** offers structured ideation using Teresa Torres' framework. Two-phase process: (1) Generate tree — extract desired outcome, identify 3 opportunities, generate 3 solutions per opportunity (3×3 = 9 total); (2) Select POC — score solutions via feasibility/impact/market-fit matrix (1-5 each, max 15), define experiment. Anti-patterns: opportunities disguised as solutions ("we need a mobile app" converges prematurely), skipping divergence (must generate minimum 3 per opportunity), vague outcomes, no experiments, analysis paralysis.

The 003 spec explicitly avoids templates for brainstorm ("No template. The PM captures ideas in whatever structure emerges naturally" — spec line 91). The OST framework is not appropriate for brainstorm — the PM should act as an active listener and synthesizer, not inject frameworks that risk steering the user. If the user wants structured ideation, that belongs in `/jim:spec` territory.

**GSD discuss-phase** uses gray-area analysis with domain-specific categories based on what's being built:
- Something users **see** → layout, density, interactions, states
- Something users **call** → responses, errors, auth, versioning
- Something users **run** → output format, flags, modes
- Something users **read** → structure, tone, depth
- Something being **organized** → criteria, grouping, naming

The system generates 3-4 phase-specific gray areas, then uses 4-question deep-dive loops per area (check satisfaction, repeat if needed). Critical scope guardrail: new ideas during discussion are captured for later, not acted on.

Key distinction from spec: brainstorm is explicitly low-pressure. The PM "listens, asks light clarifying questions, captures the thinking" (spec line 95). It does NOT conduct a full PM interview or gray-area analysis. The routing suggestion at the end ("should this be a spec?") is an offer, not a push.

### Writing Style (ref 4)

From deanpeters CLAUDE.md: imperative form, explain the why, avoid ALL-CAPS MUSTs, keep lean, write conversationally, make output copy-paste ready. Same guidance applied in 002-pm-core — carry forward consistently.

### Differential Updates (refs 5, 7, 8)

All three strategic skills need differential update behavior. The pattern from 002-pm-core plan:
1. Read existing artifact
2. Summarize proposed changes by section
3. Ask whether to update in place or start fresh
4. Use Edit not Write

For VISION.md and ROADMAP.md, "start fresh" means overwrite (single-file artifacts, not numbered like specs). For brainstorms, "start fresh" means creating a new file with a new date.

### Context Priming (ref 8)

CCPM's context priming pattern — loading project state before a work session — applies to all three skills:
- `/jim:vision` reads ARCHITECTURE.md (if it exists) to avoid contradicting technical decisions
- `/jim:roadmap` reads VISION.md (if it exists) for strategic alignment, and Globs `docs/specs/` to auto-link deliverables
- `/jim:brainstorm` reads VISION.md and ROADMAP.md to offer contextual routing at session end

---

## Relevant Patterns

### From existing jim codebase

| Pattern | Source | Application |
|---------|--------|-------------|
| Skill frontmatter with `agent: pm` | `skills/meta-skill/SKILL.md:1-10` | All three skills use `agent: pm` |
| `$ARGUMENTS` + `argument-hint` | `skills/meta-skill/SKILL.md:9` | `/jim:vision`, `/jim:roadmap` don't need arguments; `/jim:brainstorm [topic]` benefits from `argument-hint` |
| Differential update pattern | 002-pm-core plan, Task 3 step 11 | All three skills: read existing → summarize → ask → Edit |
| Validation before presenting | `skills/meta-skill/SKILL.md:84-106` | Vision and roadmap skills validate output before presenting |
| Progressive disclosure | `WORKFLOW.md:119-134` | SKILL.md ≤ 500 lines; templates in `assets/` |
| Lean agent body delegates to skills | 002-pm-core plan, Design Decision #4 | No agent body changes needed — skills are self-contained |

---

## Security & Performance

- **No Bash needed.** All three skills read files and write markdown. Tools: Read, Write, Edit, Glob, Grep. No code execution.
- **No secrets exposure.** Skills read/write strategic markdown files only.
- **Context budget.** Each SKILL.md ≤ 500 lines. Vision and roadmap templates in `assets/`. Brainstorm has no template.
- **Auto-link performance.** When `/jim:roadmap` Globs `docs/specs/` to find linkable specs, use Glob (not Read) to list them. Only Read individual specs if linking is needed.

---

## Relevant Tests

No behavioral tests exist for jim plugin components. Structural validation is the testing pattern (from 001-meta). For 003, structural validation should check:

- Vision template completeness (all 7 sections present)
- Roadmap template structure (Now/Next/Later buckets, Last Updated marker, goal-oriented framework)
- Brainstorm filename convention (`docs/brainstorms/{YYYYMMDD}-{topic}.md`)

---

## Constraints

1. **No agent modification.** `agents/pm.md` already lists all 4 skills in its frontmatter (from 002-pm-core). 003 only creates skill files — the agent picks them up automatically via the `skills` field.
2. **SKILL.md ≤ 500 lines per skill.** Vision has the most content (7-section interview). Template must go in `assets/`.
3. **002-pm-core may not be built yet.** The PM agent and spec skill are defined in 002 but may not exist at build time. 003 skills should be independent — they don't depend on the spec skill being present.
4. **VISION.md and ARCHITECTURE.md are empty placeholders.** The vision skill will write VISION.md for the first time. The roadmap skill must handle absent VISION.md gracefully.
5. **`docs/brainstorms/` directory doesn't exist.** The brainstorm skill must create it on first use.
6. **No automated blocking.** Same as 002: PM never refuses to proceed. Raises concerns, defers to human.
7. **Human approval required.** Strategic documents are finalized only when the user confirms.
8. **Brainstorm has no template.** The spec is explicit: "No template. The PM captures ideas in whatever structure emerges naturally from the conversation" (spec line 91). The skill must resist imposing structure.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Vision skill interview too long** | 7 sections × 3-5 questions = potentially 20+ questions before producing output. User fatigue. | Section-by-section approach with early synthesis. The PM can draft sections with reasonable defaults and ask the user to refine, rather than interviewing every detail. Not every section needs deep questioning — Problem Statement and Non-Goals are critical; Roadmap Trajectory can be light. |
| **Vision vs. Architecture boundary confusion** | Users may try to put technical decisions in VISION.md. The vision skill doesn't own ARCHITECTURE.md but needs to know the boundary. | Vision skill should redirect technical specifics: "That sounds like an architecture decision — want to run `/jim:arch` after this?" Clear framing in the skill: "VISION.md covers product direction; ARCHITECTURE.md covers technical decisions." |
| **Roadmap scope creep into backlog** | Users may try to put detailed feature descriptions in the roadmap. The spec warns against this (line 83). | Roadmap skill should actively push back: "This is getting detailed — want to create a spec for this with `/jim:spec`?" Keep the template concise. |
| **Brainstorm too unstructured** | Without a template, brainstorm output varies wildly. Downstream routing to `/jim:spec` may require significant reformulation. | Acceptable tradeoff per the spec. The brainstorm skill's end-of-session routing ("should this be a spec?") bridges the gap. The PM will need to re-interview when converting brainstorm → spec. |
| **Circular dependency: vision reads architecture, architecture reads vision** | Both VISION.md and ARCHITECTURE.md are empty. If the user creates vision first, it can't reference architecture. If architecture first, it can't reference vision. | Not a real problem — each skill handles missing docs gracefully. The spec says "notes absence and suggests creating them, but proceeds." The first document created simply has no upstream constraint to check against. |
| **Roadmap auto-linking to specs may be noisy** | In a large project with many spec groups, Globbing `docs/specs/` could produce too many matches. | Use Glob only — don't Read every spec. Present linked specs as suggestions, not requirements. The user decides which links to keep. |

---

## Recommendations

### For @jim:architect

1. **Vision skill interview strategy:** Don't interview all 7 sections equally. The skill should identify which sections the user has strong opinions on (typically Problem Statement, Target Audience, Non-Goals) and draft the remaining sections with reasonable defaults for the user to refine. This avoids the 20-question fatigue risk. Use the answer-to-slot mapping pattern — each section is a "slot" and the interview ends when slots are filled.

2. **Vision template design:** Keep the template lean. Each section should have a 1-2 sentence description of what goes there, not extensive guidance. The guidance lives in the SKILL.md process flow. The template is a structural skeleton, not a tutorial.

3. **Roadmap template with flexible detail levels:** The spec defines two detail levels — goal-oriented (Objective/Deliverables/Success Metrics) for mature phases, and simple lists for tactical items. The template should show both formats with clear markers for when to use each. Include the "Last Updated" date at the top.

4. **Roadmap auto-linking:** The skill should Glob `docs/specs/` and present found specs as linkable candidates when the user mentions a deliverable that might have a spec. Don't auto-populate links — offer them.

5. **Brainstorm skill: minimal process, maximum capture.** The skill's process should be: (a) create file with date-topic name, (b) listen and capture, (c) at end, offer routing. Three steps. No validation checklist beyond "file was written." The PM's natural conversational ability handles the rest.

6. **Brainstorm routing at session end:** The skill should detect natural endings ("I think that's it", "thanks", topic exhaustion) and offer: "Want me to route any of these ideas into the formal workflow? I can create a spec (`/jim:spec`), update the vision (`/jim:vision`), or add to the roadmap (`/jim:roadmap`)." This is an offer, not a requirement.

7. **Shared differential update pattern:** All three skills follow the same pattern: check if artifact exists → read → summarize changes → ask → Edit. Consider defining this as a shared process section in each skill rather than extracting to a reference doc (since each skill has slightly different context — vision checks ARCHITECTURE.md, roadmap checks VISION.md, brainstorm creates new files).

8. **Skill independence from 002:** Each skill should be implementable without the spec skill being present. They share the same agent but don't reference each other's internals. The only cross-references should be routing suggestions ("want to run `/jim:spec`?").

9. **Pre-presentation self-check for vision and roadmap.** Before presenting a drafted VISION.md or ROADMAP.md to the user, the skill must silently score its own draft against the defined anti-patterns (e.g., checking if the roadmap is just a feature list, if the vision contains invisible targeting like "for everyone," or if technical implementation details leaked into the vision). Auto-correct violations before presenting. This mirrors the self-check pattern established in 002-pm-core for `/jim:spec`.
