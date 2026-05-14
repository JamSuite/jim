---
spec: standalone
status: Active
date: 2026-05-12
---

# Research: jim:prompt Skill Architecture

## Anchors

- `skills/meta-skill/SKILL.md`: Reference for jim-internal "meta" skills that create or modify plugin components.
- `agents/meta.md`: The likely persona for executing prompt generation, already managing PM/Architect/Researcher delegation.
- `ARCHITECTURE.md`: Sections on "Plugin Conventions" and "Logic-Flow Conventions" (line 279+) which define how jim skills are invoked and how they use `!`-injection.
- `docs/brainstorms/20260512-jim-howtos.md`: Mentions "skill invocation conventions" and "LLM prompting strategies" as key candidates for modularization.

## Local Patterns

- **Pushy Descriptions**: `skills/meta-skill/SKILL.md` uses descriptive frontmatter to ensure correct triggering.
- **Imperative Instructions**: Standard jim pattern of numbered steps starting with action verbs (Read, Check, Tell).
- **Substitution Sigils**: Using `<lower>` for LLM-filled placeholders in code blocks and `!`bash for load-time resolution (ARCHITECTURE.md:352).
- **Anti-Personality**: No "I am here to help" filler; direct, second-person voice (Architecture: Anti-Patterns).

## Prior Art

### GStack (Garry Tan) — [garrytan/gstack](https://github.com/garrytan/gstack)

| File | What It Is | Why It Matters |
|------|------------|----------------|
| `skills/` | 23 specialized roles (CEO, Designer, etc.) | Pattern: **Role-based orchestration**. Roles call each other's skills without repeating the internal instructions of those roles. |
| `/qa` command | Real browser walk-through | Pattern: **Feedback-loop execution**. The prompt for `/qa` focuses on the *goal* (find bugs), not the *method* (how Playwright works). |

### Addy Osmani Agent Kit — [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)

| File | What It Is | Why It Matters |
|------|------------|----------------|
| `SKILL.md` | Anti-rationalization tables | **Critical Pattern: Anti-Slop**. Lists excuses agents use to skip work (or over-explain) with hard rebuttals. |
| `using-agent-skills` | Meta-skill for routing | Pattern: **Progressive Disclosure**. The meta-skill knows when to trigger others but doesn't contain their process logic. |

### Spec-Flow — [marcusgoll/Spec-Flow](https://github.com/marcusgoll/Spec-Flow)

| File | What It Is | Why It Matters |
|------|------------|----------------|
| `Task()` | Imperative task spawning | Pattern: **Phase Isolation**. Prompts for sub-tasks are kept lean by pointing to artifacts (spec.md) on disk rather than re-summarizing them. |

## Recommendations

- **The "Command + Context - Logic" Formula**: `jim:prompt` should generate prompts that provide the **Command** (e.g., `/jim:spec`), the **Context** (specific files or IDs), but omit the **Logic** (the steps inside `SKILL.md`).
- **Adopt Anti-Rationalization**: Explicitly instruct `jim:prompt` to avoid "helpfulness bloat."
- **Meta-Skill Orchestration**: `jim:prompt` should use `jimfile.sh glob skills` to discover available commands dynamically rather than hardcoding them.
- **Leverage Disk-Based State**: Generated prompts should encourage the target skill to "Read the latest artifact" rather than having `jim:prompt` summarize that artifact in the prompt.

## Peer Feedback

- **For PM (`@jim:pm`):** This skill directly addresses a "user experience" bottleneck where Claude Code over-explains jim commands. It fits the Phase 2 (Refinement) roadmap.
- **For Architect (`@jim:architect`):** Ensure the `jim:prompt` skill body stays under the 500-line limit by delegating the specific "best practices" for each target skill to a `references/` file if the list of skills grows.
