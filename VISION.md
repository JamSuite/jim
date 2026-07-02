# Jim — Vision

## Problem Statement

Developers rely on disciplined engineering to ship maintainable software. Because AI agents skip the formal SDLC, they bypass the specs and plans that document architectural intent. This creates knowledge silos and expensive rework, eroding trust in the implementation as projects and teams scale.

* **The Ideal:** Developers want to maintain architectural integrity and ship reliable, maintainable software through a disciplined engineering process.
* **The Reality / Friction:** AI agents do not follow a formal SDLC. By operating without integrated specs, plans, and testing protocols, they fail to document architectural intent and often produce logic that requires expensive rework.
* **The Consequence:** This creates knowledge silos where critical project context remains trapped in the developer's head. As teams and codebases scale, the lack of predictable quality erodes trust in the implementation and forces you to manually enforce the discipline the AI ignores.

## Solution Statement

Jim provides an agentic SDLC workflow for Claude Code via `/jim:spec`, `/jim:plan`, and `/jim:build` skills. This collaboration grounds every task in research, spec-driven planning, and test-first implementation to maintain architectural consistency. By documenting the "how" and "why" of the code as it's built, Jim increases software quality, team confidence, and your overall understanding of the system.

* **The Mechanism:** A Claude Code plugin that adds specialized SDLC skills: `/jim:spec`, `/jim:plan`, and `/jim:build`.
* **The Workflow:** An agentic process grounded in research, spec-driven planning, and test-first implementation.
* **The Resolution:** Maintains architectural consistency and increases quality, confidence, and the team's understanding of the codebase.

## Target Audience

* **Primary:** Developers using Claude Code who want a structured, repeatable workflow for non-trivial work — features, bug fixes, and refactors that span multiple files or require coordination.
* **Team context:** Small development teams working on tightly-coupled codebases, especially when developers own specific functional areas.
* **Mindset:** Early adopters and cutting-edge practitioners willing to try new tools and methodologies for AI-assisted development. Comfortable with TDD and spec-driven development. Want AI to follow their discipline, not bypass it.
* **Not for:**
    - Developers who want fully autonomous, hands-off AI coding
    - One-off scripts or throwaway prototypes where the overhead isn't worth it
    - Teams that need a project management system (Jira, Linear, etc.)

## Competitive Landscape

| Approach | Pros | Cons |
|----------|------|------|
| **Raw Claude Code (no plugin)** | Zero overhead, maximum flexibility | No structure; quality depends entirely on prompt discipline; no institutional memory |
| **Custom CLAUDE.md prompts** | Simple; no dependencies | Fragile; no separation of concerns between agents; hard to share across projects |
| **SuperClaude** | Rich prompt engineering for Claude Code; personality and capability modes | Prompt-based, not workflow-based; no spec→plan→build lifecycle; no agile feedback loop |
| **V1SDLC (Jim's predecessor)** | Proved the spec→research→plan→build model works | Manual phase transitions; no plugin distribution; limited agile feedback |
| **GSD and similar frameworks** | Structured development with decision tracking | State files add workflow bloat; not native to Claude Code's agent/skill model |

**Differentiation:** Jim is a convention-over-configuration agentic SDLC native to Claude Code, with specialized agents that maintain domain context and living documents that support agile iteration. The historical record of specs, research, and plans compounds as institutional memory.

**Trade-offs:** Overhead for trivial changes; currently Claude Code-only (cross-agent support is a future goal).

## Product North Star

**Success signals:**
- Developers report that Jim makes their AI-assisted workflow more effective and enjoyable — word-of-mouth is the strongest signal
- A growing community forms around Jim, with contributors improving skills, agents, and the workflow itself
- Teams adopt Jim across multiple projects and functional areas, building on shared conventions
- The spec/research/plan archive becomes a go-to reference for onboarding and decision history

## Roadmap Trajectory

**Phase 1 — Core SDLC (current):** Spec, Plan, Build, Research, and strategic commands (Vision, Architecture, Roadmap). Self-hosting: Jim builds Jim.

**Phase 2 — Research and Refinement:** Improve research collaboration, incorporate feedback from initial users, refine the workflow based on real-world usage.

**Phase 3 — Configuration and Integration:** Configuration support (custom paths, templates, agent augmentation). Integration with other frameworks (Codex, Gemini CLI, other coding agents).

## Non-Goals

- **Not a virtual team.** Jim is an agentic framework, designed for human → agent collaboration. It is not a substitute for real human's work or their roles. 
- **Not a project management tool.** Jim does not replace Jira, Linear, or any ticketing system, and does not manage team workflows. Issue capture is in scope — but only as a *discovery artifact* surfaced during the jim workflow and saved for later analysis, not as a team-coordination primitive.
- **Not for hands-off vibe coding.** Jim requires human-in-the-loop approval at every phase gate. If you want fully autonomous code generation, Jim is the wrong tool.
- **Not a black box.** Jim should never spawn agents and skills in ways the user can't follow. Transparency over automation.
- **Not a change management system.** Jim tracks development artifacts (specs, plans, research), not organizational change processes.
