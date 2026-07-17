# Research: SDLC Researcher Agents and Skills

- **Source Spec:** [docs/specs/jim/004-researcher/research.md]
- **Status:** Complete
- **Date:** 2026-03-12

## 1. Executive Summary
This research explores state-of-the-art "Researcher" agents within the Claude Code and AI-agentic SDLC ecosystem. Unlike academic researchers, these agents focus on **codebase archaeology**, **implementation discovery**, and **technical constraint gathering**. The findings highlight a trend toward "Tiered Research" (Local vs. Web) and "Anchor Identification" as the gold standards for informing the Planning phase.

---

## ## Tier 1: Study These Closely
These frameworks share Jim's philosophy of spec-driven development and provide the most direct patterns for `v1-researcher`.

### **Repo**: [akaszubski/autonomous-dev](https://github.com/akaszubski/autonomous-dev) *(agents moved to `plugins/autonomous-dev/agents/`; default branch `master`)*
**Relevant to**: `/jim:spec`, `v1-researcher`, `v1-architect`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| [`plugins/autonomous-dev/agents/researcher-local.md`](https://github.com/akaszubski/autonomous-dev/blob/master/plugins/autonomous-dev/agents/researcher-local.md) | A specialized agent for codebase-only context gathering. | Implements a "Local-First" rule to prevent token bloat and hallucination by forcing Grep/Glob use before Web search. |
| [`plugins/autonomous-dev/agents/researcher.md`](https://github.com/akaszubski/autonomous-dev/blob/master/plugins/autonomous-dev/agents/researcher.md) *(the former `researcher-web.md` was merged into `researcher.md`)* | The web-research agent focused on external documentation and API discovery. | Perfectly maps to Jim's `WebFetch`/`WebSearch` guardrails, separating internal patterns from external knowledge. |

**Key takeaways for Jim:**
* **Model Tiering:** Uses Claude 3.5 Haiku for local research (cost-effective) and Sonnet for web-based synthesis. 
* **Alignment Command:** Includes a `/align` command that validates findings against a `PROJECT.md`, ensuring research doesn't drift from core goals.

### **Repo**: [open-gsd/gsd-core](https://github.com/open-gsd/gsd-core) *(formerly `gsd-build/get-shit-done`, archived 2026-06-26; default branch now `next`; file layout changed — see `docs/research/20260717-competitive-landscape-sdd-skills.md` for verified anchors)*
**Relevant to**: `v1-researcher`, `v1-architect`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| [`agents/gsd-phase-researcher.md`](https://github.com/open-gsd/gsd-core/tree/next/agents) *(researcher sub-agent renamed in the move; verify current path in the tree)* | A core orchestrator sub-agent for investigation. | Specifically investigates "implementation approaches" rather than just finding files, providing options for the Planner. |

**Key takeaways for Jim:**
* **Human-in-the-loop Gates:** Like Jim, GSD pauses after the Research/Plan phase for verification, preventing autonomous "runaway" implementation.
* **Atomic Research:** Focuses on researching a single "Phase" at a time, keeping the `research.md` extremely focused and under the word budget.

---

## ## Tier 2: Study for Specific Patterns
These repos offer unique tactical patterns (e.g., specific prompts or multi-platform compatibility) that can enhance `v1-researcher-skill`.

### **Repo**: [nguyenvanduocit/research-kit](https://github.com/nguyenvanduocit/research-kit)
**Relevant to**: `v1-researcher-skill`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| [`templates/methodology-template.md`](https://github.com/nguyenvanduocit/research-kit/blob/main/templates/methodology-template.md) *(templates are flat at repo root; the monolithic `research.md` is now split into methodology/analysis/synthesis templates — verified 2026-07-17)* | Phase-separated research templates. | Provides a structured "Methodology" section that defines *how* the search was conducted (e.g., source evaluation criteria). |

**Key takeaways for Jim:**
* **Principle-Based Research:** Introduces a `/principles` command (formerly cited as `/research.principles`) to set the "bar" for evidence (e.g., requiring official docs over blog posts).
* **Target Audience Focus:** Research results are tailored for the "Target Audience" (e.g., engineering leadership), which Jim can use to differentiate between Architect and Coder needs.

### **Repo**: [SuperClaude-Org/SuperClaude_Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework)
**Relevant to**: `v1-researcher`, `v1-architect`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| `personas/technical-analyst.md` **(DEAD LINK as of 2026-07-17 — the `personas/` folder was removed in the SuperClaude v4 restructure; superseded by agents under `src/superclaude/agents/`, e.g. [`deep-research.md`](https://github.com/SuperClaude-Org/SuperClaude_Framework/blob/master/src/superclaude/agents/deep-research.md). Default branch is now `master`, not `main`.)** | A "Cognitive Persona" for technical deep-dives. | Uses "Reasoning Loops" to double-check anchors and "Deep Research Mode" for citation chains. |

**Key takeaways for Jim:**
* **Orchestration Mode:** Coordinates Web search, code analysis, and documentation lookup automatically, preventing the agent from getting stuck in one tool.
* **Token-Efficiency Mode:** Explicitly reduces context consumption by 30-50%, aligning with Jim's "20-Line Rule."

---

## ## Tier 3: Reference Only
Useful for edge cases or non-core SDLC research tasks.

### **Repo**: [github/spec-kit](https://github.com/github/spec-kit)
**Relevant to**: `v1-researcher`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| [`templates/plan-template.md`](https://github.com/github/spec-kit/blob/main/templates/plan-template.md) *(renamed from `templates/plan.md`; old path 404s as of 2026-07-17)* | A technical implementation plan template. | Includes a `research` section in the plan itself, ensuring findings are never detached from the implementation roadmap. |

### **Repo**: [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
**Relevant to**: `v1-researcher`

| File | What It Is | Why It Matters for Jim |
| :--- | :--- | :--- |
| [`08-business-product/ux-researcher.md`](https://github.com/VoltAgent/awesome-claude-code-subagents/blob/main/categories/08-business-product/ux-researcher.md) | A researcher for user needs and personas. | While not for code, the "Verification Checklist" at the bottom is a masterclass in Definition of Done (DoD). |

**Key takeaways for Jim:**
* **DoD Checklists:** The strict checklist format (e.g., "Bias minimized systematically") is highly effective for ensuring the agent doesn't stop until all anchors are documented.

---

## 3. Risks & Recommendations
- **Risk:** Most frameworks suffer from "Token Sprawl" in research. Jim’s "20-Line Rule" and word budget are already state-of-the-art for keeping costs low.
- **Recommendation:** Implement a "Local vs. Web" split in the `v1-researcher` tool-use instructions. Force a `Grep`/`Glob` pass of the codebase *before* allowing `WebSearch` to prevent the agent from suggesting generic solutions over project-specific patterns.
- **Recommendation:** Adopt the "Anchor Summary" pattern from `autonomous-dev`, where the agent must explain *why* a file is an anchor (e.g., "Contains the main routing logic for this module").

### Design decision — no scored confidence gate (recorded 2026-07-17)

jim:research **deliberately does NOT adopt a scored confidence / proceed-ask-stop gate** (as seen in SuperClaude's `confidence-check`, cited in Tier 2 above). The researcher instead **routes** concerns via the `status:` field (`Needs PM Review` / `Needs Architect Review`) and the **Peer Feedback** section — *flag-and-route, not hard-stop*. This matches jim's project-wide stance: *"No confidence scores. No numeric thresholds"* (`skills/spec/SKILL.md:125`). It is also why a research run never reaches a "no-go" — by design.

The one **values-compatible sliver** of that pattern is distinct from a confidence score: autonomous-dev's **enforced tool-use** (confirm a web search actually ran before a Phase-1 claim) and **no-empty-result justification** (local search must justify "nothing found"). Those are anti-hallucination rigor, not a numeric gate, and are partially reflected in the local-first recommendation above; they remain a *possible* future enhancement. The scored gate itself is **out of scope by design.**