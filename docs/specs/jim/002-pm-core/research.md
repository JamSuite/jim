---
spec: docs/specs/jim/002-pm-core/spec.md
type: feature
---

# Research: @jim:pm Agent + /jim:spec Skill

## Anchors

These are the files that must be created or modified to implement 002-pm-core.

| # | File | Action | Why |
|---|------|--------|-----|
| **1** | `agents/pm.md` | **Update** (currently 1-line placeholder) | Agent definition: frontmatter (name, description, skills, tools, model) + self-contained body with role, process, constraints. Currently empty — needs full build. |
| **2** | `skills/spec/SKILL.md` | **Create** | Primary skill — the interview-driven spec creation workflow. Does not exist yet. |
| **3** | `skills/spec/assets/spec-template.md` | **Create** | Output template for `spec.md` covering feature/bug/refactor types. Referenced by the skill during generation. |
| **4** | `skills/spec/references/spec-types.md` | **Create** | Type guidance: required sections per type, anti-patterns, status lifecycle. Keeps SKILL.md lean. |

### Secondary anchors (read, not modified)

| File | Role |
|------|------|
| `WORKFLOW.md` | Defines the SDLC, command reference, artifact paths, rules of engagement. The PM agent body must reference key paths from here since agents don't inherit context. |
| `VISION.md` / `ARCHITECTURE.md` (project root) | Locked constraints the skill reads at invocation. Currently empty placeholders — skill must handle absence gracefully. |
| `docs/specs/jim/001-meta/` | Completed spec group. Pattern reference for spec directory structure, frontmatter, and research/plan co-location. |
| `docs/prior-art/V1SDLC/V1-SPEC_TEMPLATE.md` | V1 spec template. The new `spec-template.md` evolves this — adds `origin:` frontmatter, type-conditional sections, traceability fields. |
| `agents/meta.md` | Existing agent built from 001-meta. Pattern reference for agent structure: frontmatter with examples, second-person body, ~800 token budget. `agents/meta.md:1-65` |
| `skills/meta-skill/SKILL.md` | Existing skill built from 001-meta. Pattern reference for skill structure: frontmatter, gate pattern, validation checklist, differential updates. `skills/meta-skill/SKILL.md:1-107` |

---

## References

| # | Source | Type | URL / Path |
|---|--------|------|------------|
| 1 | Claude Code Skills docs | Official | `https://code.claude.com/docs/en/skills` *(live; evolved since cited — custom commands have merged into skills, and the page now cites the `agentskills.io` open standard, 2026-07-17)* |
| 2 | Claude Code Sub-agents docs | Official | `https://code.claude.com/docs/en/sub-agents` |
| 3 | deanpeters/Product-Manager-Skills | Prior art repo | `https://github.com/deanpeters/Product-Manager-Skills` |
| 4 | automazeio/ccpm | Prior art repo | `https://github.com/automazeio/ccpm` |
| 5 | open-gsd/gsd-core (formerly gsd-build/get-shit-done) | Prior art repo | `https://github.com/open-gsd/gsd-core` |
| 6 | V1 PM agent | Local prior art | `docs/prior-art/V1SDLC/v1-agent-pm.md` |
| 7 | V1 PM skill | Local prior art | `docs/prior-art/V1SDLC/v1-pm-skill.md` |
| 8 | V1 Spec Template | Local prior art | `docs/prior-art/V1SDLC/V1-SPEC_TEMPLATE.md` |
| 9 | PM Prior Art Study Guide | Local research | `docs/prior-art/pm/pm-prior-art-research.md` |
| 10 | 001-meta research | Local reference | `docs/specs/jim/001-meta/research.md` |

## Reference Summary

### Claude Code Platform (refs 1-2)

Skills: `description` is always in context (trigger surface); body loads on invocation. `$ARGUMENTS` substitution passes user input. `agent:` field in skill frontmatter is a jim documentation convention only — not Claude Code routing. Plugin skills namespaced as `/jim:spec`.

Agents: markdown body = entire system prompt. No Claude Code system prompt, no CLAUDE.md, no parent context inherited. `model` defaults to `inherit` (unpredictable) — must set explicitly. `skills` field preloads full skill content at startup. Agent tool enables delegation but subagents cannot nest (one level only).

### V1 PM (refs 6-8)

The v1 PM (`v1-agent-pm.md:1-70`) establishes the baseline interview pattern:
- Type detection from context (feature/bug/refactor)
- 1-2 questions at a time (not a wall)
- Recursive interview for vague statements
- Dependency check against `CLAUDE.md` and existing specs
- Differential updates: summarize changes before applying

V1 spec template (`V1-SPEC_TEMPLATE.md:1-71`) provides type-conditional sections (feature gets Problem Statement + User Stories, bug gets Defect Profile, refactor gets Refactor Rationale). The 002 spec evolves this by adding `origin:` frontmatter for traceability.

V1 PM skill (`v1-pm-skill.md:1-50`) defines grouping (noun-based), ID format (3-digit zero-padded), type-specific section requirements, status lifecycle (`draft → approved → in-progress → complete → deprecated`), and 6 anti-patterns.

### 001-meta Patterns (ref 10)

The 001-meta implementation provides the structural template for 002:
- **Agent pattern** (`agents/meta.md`): frontmatter with `<example>` blocks in description, second-person body ("You are..."), ~800 token budget, references key paths since no context is inherited, delegates to skills for detail.
- **Skill pattern** (`skills/meta-skill/SKILL.md`): frontmatter with `agent:` convention + `argument-hint`, 3-gate process (spec → research → plan), inline validation checklist, differential update instructions.
- **Key difference for 002:** The PM skill is *interactive* (multi-turn conversation), not *procedural* (locate → build → validate). The gate pattern doesn't apply — instead the skill drives an interview loop.

---

## Prior Art

| # | Source | What It Is |
|---|--------|------------|
| 1 | deanpeters/prd-development | PRD workflow skill: interview → structured PRD |
| 2 | deanpeters/positioning-workshop | Bounded interview (3-5 Qs) with numbered options → positioning statement |
| 3 | deanpeters/CLAUDE.md | Skill design philosophy: 3 skill types, anti-patterns, writing style |
| 4 | GSD discuss-phase | Gray-area analysis: domain-specific ambiguity probes, not generic questions |
| 5 | GSD gsd-planner | Locked-decisions pattern: upstream decisions are immutable constraints |
| 6 | CCPM prd-new | PRD creation with context priming from existing project docs |

## Prior Art Summary

### Gray-Area Analysis (refs 4, 1)

The strongest pattern for replacing v1's generic "ask 1-2 questions" loop. From GSD's `discuss-phase`:

1. Analyze the rough idea against known domains (scope, target user, edge cases, interaction model, data shape)
2. Identify which specific dimensions are uncertain — not "what are your requirements?" but "the scope of X is unclear because Y"
3. Present 2-3 uncertain dimensions with numbered options + "or describe your own" escape hatch
4. Let the user choose what to discuss first

The spec explicitly calls for this pattern (spec lines 56-62). Implementation should categorize unknowns by domain and present them as concrete choices, not open-ended prompts.

### Locked Decisions (refs 5, 6)

From GSD planner: once a user makes a decision (or a strategic doc establishes one), it becomes an immutable constraint. Three tiers:
- **Locked** — must implement exactly (VISION.md non-goals, ARCHITECTURE.md invariants)
- **Deferred** — must NOT appear in output (explicitly out-of-scope items)
- **Discretion** — agent chooses reasonably

The spec maps this directly (spec lines 78-82): when VISION.md or ARCHITECTURE.md exist, their contents are constraints. The PM raises conflicts conversationally but never blocks.

### Interview Structure (refs 2, 1, 3)

From deanpeters positioning-workshop: bounded interviews where each question maps to an output template slot. Key patterns:
- **3-5 questions max** per topic area before synthesizing
- **Numbered options** (3-4 per question) + escape hatch reduce cognitive load
- **Answers populate template slots** — the interview is purposeful, not open-ended
- **Inline adaptation** — downstream options reframe based on earlier answers

The spec's "1-3 questions at a time" (spec line 70) aligns. The template slot mapping means each interview phase should target specific spec sections.

### Anti-Pattern Detection (ref 3)

From deanpeters CLAUDE.md and v1 PM skill: skills should include explicit "don'ts" that prevent generic AI output. The spec lists 6 anti-patterns (spec lines 86-93): Kitchen Sink, Vague Criteria, Solution Masquerading, Empty Out of Scope, Premature Tech, Wrong Type. These should live in `references/spec-types.md` alongside type-specific guidance.

### Writing Style (ref 3)

From deanpeters CLAUDE.md: imperative form, explain the *why* behind rules, avoid ALL-CAPS MUSTs, keep lean, write conversationally (teach a smart junior PM), make output copy-paste ready. Every word earns its inclusion.

### Interview Exit Condition

The spec says "continue until spec is writable" (spec line 130) but doesn't define "writable." Rather than a numeric confidence threshold (LLMs are unreliable self-scorers), define it structurally: **the spec is writable when the PM has gathered enough information to meaningfully populate the required sections for the detected type** (e.g., Problem Statement + User Stories for a feature), having asked no more than 3-5 questions per topic area. This leverages the answer-to-slot mapping and bounded interview patterns already identified above, and gives the architect a concrete, implementable exit condition that prevents infinite interview loops.

---

## Relevant Patterns

### From existing jim codebase

| Pattern | Source | Application |
|---------|--------|-------------|
| Agent frontmatter with `<example>` blocks | `agents/meta.md:1-40` | `agents/pm.md` description must include 2-3 examples of when to use/not use |
| Second-person agent body | `agents/meta.md:42-65` | "You are the product manager for jim..." |
| `agent:` documentation convention in skill frontmatter | `skills/meta-skill/SKILL.md:1-10` | `skills/spec/SKILL.md` uses `agent: pm` |
| `$ARGUMENTS` + `argument-hint` | `skills/meta-skill/SKILL.md:9` | `/jim:spec [name-or-idea]` |
| Differential update pattern | `skills/meta-skill/SKILL.md:46-47` | Re-running `/jim:spec` on existing spec reads first, summarizes changes |
| Validation before presenting | `skills/meta-skill/SKILL.md:84-106` | Spec skill validates against anti-patterns before presenting |
| Progressive disclosure | `WORKFLOW.md:119-134` | SKILL.md ≤500 lines; template in `assets/`, type reference in `references/` |

### From prior art

| Pattern | Source | Application |
|---------|--------|-------------|
| Gray-area analysis | GSD discuss-phase | Replace v1's generic questions with domain-specific uncertainty probes |
| Locked decisions | GSD planner | VISION.md + ARCHITECTURE.md contents are constraints, not suggestions |
| Bounded interview (3-5 Qs) | deanpeters positioning-workshop | Cap questions per topic; synthesize after 3-5 |
| Answer-to-slot mapping | deanpeters positioning-workshop | Each interview phase targets specific template sections |
| Numbered options + escape hatch | deanpeters positioning-workshop | Reduce cognitive load for the user |
| Anti-pattern checklist | deanpeters CLAUDE.md, v1 PM skill | Codify in `references/spec-types.md` |
| Pre-presentation self-check | SuperClaude self_check.py | Agent silently validates draft against anti-patterns + locked constraints before presenting |

---

## Security & Performance

- **No Bash needed.** The PM agent reads files and writes markdown. Tools: Read, Write, Edit, Glob, Grep. No code execution.
- **No secrets exposure.** The spec skill reads VISION.md and ARCHITECTURE.md — no credentials, no env vars.
- **Context budget.** The PM agent body must stay under 800 tokens. The `skills` field preloads full SKILL.md content at startup, so the agent body should be lean and delegate detail to the spec skill. The spec skill itself must stay under 500 lines, with the template in `assets/` and type reference in `references/`.
- **Large spec groups.** When checking existing specs in `docs/specs/{group}/`, use Glob (not Read) to list them. Only Read individual specs if cross-spec side effects are suspected.

---

## Relevant Tests

No behavioral tests exist for jim plugin components. The 001-meta implementation established **structural validation** as the testing pattern — inline checklists in the skill that verify the artifact before presenting to the user.

For 002, structural validation should check:
- Spec template completeness (all type-conditional sections present)
- Frontmatter validity (required fields, status lifecycle values)
- Anti-pattern detection (the 6 patterns from the spec)

---

## Constraints

1. **Agent body ≤ 800 tokens.** The PM agent composes 4 skills (spec, vision, roadmap, brainstorm). Only `spec` is delivered in 002; the other 3 come in 003. The agent body must leave room for all 4 skills to be listed without needing a body rewrite.
2. **SKILL.md ≤ 500 lines.** The spec skill is complex (interview loop, type detection, gray-area analysis, mockup-first, anti-pattern detection, traceability). Template and type reference must go in `assets/` and `references/` respectively.
3. **Skills declared in 003 don't exist yet.** The `agents/pm.md` frontmatter lists `skills: [spec, vision, roadmap, brainstorm]` per the spec (line 155). Skills that don't exist yet will show in the agent's `skills` list but won't preload — this is fine; Claude Code handles missing skills gracefully.
4. **VISION.md and ARCHITECTURE.md are empty.** The spec skill must handle their absence gracefully (note conversationally, suggest creating them, proceed).
5. **`agent: pm` is documentation-only.** Not a Claude Code routing field. Routing happens via the skill's description and the agent's `skills` list.
6. **No automated blocking.** The PM never refuses to proceed. It raises concerns and defers to the human.
7. **Human approval required for status changes.** Spec stays `draft` until explicit confirmation.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **SKILL.md exceeds 500 lines** | The spec skill has many responsibilities (interview, type detection, gray-area, mockup-first, anti-patterns, traceability, differential updates). Could easily overflow. | Aggressively use `assets/` (template) and `references/` (type guide). Keep SKILL.md focused on process flow; delegate reference material. |
| **Agent body exceeds 800 tokens** | PM has the most complex role of any jim agent — collaborative interviewer, strategic alignment checker, anti-pattern detector. | Lean body: role + key paths + constraints only. All methodology lives in the skill. The `skills` field preloads spec SKILL.md content. |
| **Gray-area analysis is too vague to implement** | The spec describes the concept but not the exact mechanism. Could produce generic behavior. | Architect should define concrete dimension categories (scope, target user, edge cases, interaction model, data shape) and the analysis algorithm in the plan. |
| **Template bloat across 3 types** | Feature/bug/refactor each have unique sections. A single template with all sections and conditional markers could be confusing. | Consider separate type sections within the template, or clear `<!-- feature only -->` markers. The type reference doc should make clear which sections apply where. |
| **003-pm-strategy dependency** | `agents/pm.md` must list all 4 skills but only `spec` exists in 002. If the architect writes the agent body too tightly around `spec`, it needs rewriting in 003. | Agent body should be role-focused ("You are the PM...") not skill-focused. The `skills` field handles skill composition; the body handles identity and constraints. |
| **ID collision on concurrent generation** | Two spec-creation runs in the same group could pick the same next ID, overwriting or conflicting. | The SKILL.md must define a strict read-and-increment pattern: Glob for `docs/specs/{group}/*/`, parse existing IDs, pick max+1. This must happen immediately before file creation, not at the start of the interview. |

---

## Recommendations

### For @jim:architect

1. **Spec template design:** Use a single template file with clear type-conditional markers (`<!-- feature only -->`, `<!-- bug only -->`), not 3 separate templates. This matches the spec's requirement for "covering all three types with clear section markers" (spec line 165). Add the `origin:` frontmatter field as an optional list.

2. **SKILL.md structure:** Organize around the process flow from the spec (lines 112-140): read strategic docs → check existing specs → detect type → gray-area analysis → interview loop → generate spec → present for review. Each step is a numbered section with clear instructions.

3. **Gray-area dimensions:** Define a concrete set of dimensions the PM evaluates: scope boundaries, target user specificity, edge case coverage, interaction model, data shape, acceptance criteria testability. The PM picks the 2-3 most uncertain and presents them.

4. **Agent body strategy:** Keep the PM agent body focused on identity, key file paths, and constraints. All methodology (interview technique, anti-patterns, type detection) lives in the spec skill. The agent just says "follow the skill's instructions." This protects the 800-token budget and avoids duplication when 003 adds more skills.

5. **Differential update for specs:** When re-running `/jim:spec` on an existing spec, the skill should: (a) Read the existing spec, (b) Present a summary of proposed changes organized by section, (c) Ask whether to update in place or create a new increment, (d) Use Edit not Write. This mirrors the pattern in `skills/meta-skill/SKILL.md:46-47`.

6. **`spec-types.md` scope:** This reference doc should contain: per-type required sections, per-type interview focus, the 6 anti-patterns with examples, and the status lifecycle. Target ~150-200 lines. This keeps the SKILL.md lean.

7. **Interview exit condition:** Define "writable" structurally in the SKILL.md process flow, not as a numeric confidence score. The spec is writable when the PM can meaningfully populate the required template sections for the detected type, having asked no more than 3-5 questions per topic area. This uses the answer-to-slot mapping pattern — each interview phase targets specific spec sections, and when those slots are filled, the interview ends. This prevents the infinite question loop risk without relying on unreliable LLM self-assessment.

8. **Pre-presentation self-check:** Add an explicit step in the SKILL.md process flow between "Generate spec.md" and "STOP → present to user." The PM silently validates the draft against: (a) the 6 anti-patterns, (b) locked constraints from VISION.md/ARCHITECTURE.md, (c) type-section completeness. If the self-check fails, the PM auto-corrects the draft before presenting. This is not a human gate — it's internal quality control.
