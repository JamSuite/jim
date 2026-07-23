---
spec: "standalone"
status: Active
date: "2026-05-04"
---

# Research: 2026 UI Design-to-Code Feasibility for Jim

Evaluates whether jim should add a `jim:design`, `jim:ui`, or `jim:wireframe` skill, and which external tools the skill should orchestrate. Local archaeology is brief — jim is greenfield for UI work.

## Anchors

Jim has no existing UI/design surface. Skill anatomy below is the convention any new design skill must follow.

| File | Why it's an anchor |
|------|--------------------|
| `skills/research/SKILL.md` (L1–end) | Closest analog — a knowledge-producing skill with `assets/` (template) and `references/` (DoD). New `skills/design/SKILL.md` should mirror this layout. |
| `skills/conf/scripts/jimconf.sh` (L1–end) | If a `DESIGN.md` path needs configurability, add a `design_path` key here following the existing six-key pattern. |
| `agents/pm.md`, `agents/architect.md` | A design skill has no obvious agent owner — PM (intent capture) or Architect (system spec). Decision belongs in a follow-on spec, not this research. |
| `ARCHITECTURE.md` (L9–52, L209–262) | Defines the skill/agent/scripting conventions any new skill must obey (≤500 lines, agent binding is doc convention, jimconf integration via `!`-injection). |
| `docs/specs/jim/` (no UI specs exist) | Greenfield audit trail: `glob skills/**/*ui* skills/**/*design* skills/**/*wireframe*` → 0 results. |

## Local Patterns

- **Skill anatomy** — `skills/{name}/SKILL.md` + optional `assets/` (templates) + `references/` (methodology). Frontmatter requires `name`, `description`, `agent`, `argument-hint`. SKILL.md ≤500 lines (progressive disclosure).
- **Scripting layer** — Markdown-first; deterministic logic lives in `skills/conf/scripts/jimconf.sh` and is `!`-injected. No JS/TS runtime; Bun/Node tools cannot ship as part of jim.
- **Test convention** — `tests/run.sh` (plain bash). LLM-interpreted skill prompts have no automated tests; only deterministic scripts do. **Test template:** `tests/run.sh` itself — heredoc fixtures, per-test `mktemp` sandbox, zero deps. A design skill that produces only markdown would have no test surface.
- **Differential update** — every artifact-producing skill reads existing artifact before writing. A `jim:design` skill must follow this for `DESIGN.md`.

## Prior Art

Seven entries — tiered:

### Tier 1 — Study Closely

**Anthropic Claude Design** (research preview, launched 2026-04-17, powered by Opus 4.7) — [claude.ai/design](https://claude.ai/design) | [news post](https://www.anthropic.com/news/claude-design-anthropic-labs)

| File / Surface | What It Is | Why It Matters |
|---|---|---|
| One-click "Export anywhere" → Handoff Bundle | Machine-readable component spec + design tokens + layout hierarchy + assets | This is the exit point jim should target. A `jim:design` skill that produces a bundle-compatible artifact rides Anthropic's roadmap rather than competing with it. |
| Pricing | Claude Pro/Max/Team/Enterprise only | Hard gate — jim users without paid plans can't use this leg. |

**Anthropic `frontend-design` skill** — [`anthropics/skills`](https://github.com/anthropics/skills) (367.6K installs per skills.sh)

| File / Surface | What It Is | Why It Matters |
|---|---|---|
| `skills/frontend-design/SKILL.md` | "Anti-slop" component generation — distinctive typography, anti-generic layouts | Closest official prior art for the *style discipline* a `jim:design` skill should encode. |
| Install: `/plugin marketplace add anthropics/skills` (native) or `npx skills add anthropics/skills` (skills.sh) | Two install paths, same artifact | Jim should recommend, not bundle — installation is the user's choice. |

### Tier 2 — Study for Specific Patterns

**GStack** (Garry Tan) — [`garrytan/gstack`](https://github.com/garrytan/gstack), MIT, requires Bun v1.0+

| File / Surface | What It Is | Why It Matters |
|---|---|---|
| `/design-shotgun`, `/design-review`, `/plan-design-review`, `/design-html` | 4 designer roles rating designs 0–10, generating variants, detecting "AI slop" | Pattern: design-as-review-loop, not one-shot generation. Worth borrowing for jim. |
| `/qa` + `/browse` | Real Chromium browser — executes flows, fixes bugs with atomic commits, auto-generates regression tests | Closest prior art for visual-regression discipline. Bun dependency is a non-starter for jim's bash-only model. |
| Install: `git clone … ~/.claude/skills/gstack && ./setup` | Bypasses marketplace | Demonstrates that skills can ship outside the official channel. |

**Addy Osmani Agent Kit** — [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills), 27.9k stars, MIT

| File / Surface | What It Is | Why It Matters |
|---|---|---|
| `skills/frontend-ui-engineering/SKILL.md` | WCAG 2.1 AA, design systems, responsive, state management | The "Common Rationalizations" table is the killer pattern — it lists agent excuses ("It's a prototype", "AI aesthetic is fine") with verbatim counter-arguments. Jim should adopt this structure for any quality-gate skill. |
| Install: `/plugin marketplace add addyosmani/agent-skills` | Standard | — |

### Tier 3 — Reference Only

**21st.dev Magic MCP** — [`21st-dev/magic-mcp`](https://github.com/21st-dev/magic-mcp), beta. `/ui` command generates React/TS components with multi-variation picker. Draws from 21st.dev's curated component registry. Recommend, don't bundle.

**Google Stitch + `davideast/stitch-mcp`** — Stitch is Google Labs' AI design canvas (March 2026 update added Vibe Design / Voice Canvas / infinite canvas, powered by Gemini). Stitch MCP pipes per-screen designs into Claude Code. Pairs with DESIGN.md (system) ↔ Stitch (per-screen). Cross-vendor — useful as evidence that DESIGN.md is becoming a de-facto handoff contract.

**skills.sh marketplace** — [skills.sh](https://skills.sh), `npx skills add <owner/repo>`. Registry of UI/UX skills includes `frontend-design` (anthropics), `web-design-guidelines` (vercel-labs, 295.4K installs), `theme-factory` (anthropics, 36.2K), `design-taste-frontend` (leonxlnx). Install counts > formal verification — caveat emptor.

## Libraries

No new libraries proposed. Jim is markdown + bash; design tooling is recommended-not-bundled. `jimconf.toml` may gain a `design_path` key (default `DESIGN.md` at project root) — six existing keys → seven, no sprawl.

## Security & Performance

- **MCP server trust** — Stitch MCP and 21st.dev Magic MCP are external services. If jim recommends them, the SKILL.md should warn users to add domain allowlists in `.claude/settings.local.json` and to review the MCP server before granting it tool access.
- **Plugin/marketplace supply chain** — `npx skills add <owner/repo>` and `/plugin marketplace add <owner/repo>` execute community code in the user's Claude Code session. A `jim:design` skill should recommend pinning to specific repos and not auto-install.
- **Vendor lock** — Claude Design's handoff bundle format is Anthropic-proprietary today; a `jim:design` skill that produces a `DESIGN.md` (open spec) plus *optionally* a bundle stays portable.
- **Performance** — None of the recommended tools run inside jim's process; all are out-of-process via Claude Code or MCP. No latency or memory impact on jim itself.

## Recommendations

### Comparison Matrix — Three Frameworks

| Dimension | Anthropic Official (`frontend-design` + Claude Design) | GStack | Agent Kit |
|---|---|---|---|
| Scope | Generation + web-canvas handoff | Full SDLC (23 skills) incl. design + QA | Quality workflows (20 skills) incl. frontend |
| Install | `/plugin marketplace add anthropics/skills` | `git clone … && ./setup` (Bun req.) | `/plugin marketplace add addyosmani/agent-skills` |
| Design surface | "Anti-slop" component generation | 4 designer roles + variant shotgun | One `frontend-ui-engineering` skill |
| QA surface | None (relies on Claude Code) | Real Chromium via `/qa` | Verify phase, code-level |
| License / lock-in | Anthropic-only handoff bundle | MIT, Bun runtime | MIT, agent-agnostic |
| Fit with jim | Highest (officially-supported handoff) | Pattern donor (review-loop, /qa) | Pattern donor (rationalization counter-args) |

### V1 Setup Guide — "Minimalist but Professional"

Recommend users install **3 skills + 1 MCP** alongside jim:

1. **`anthropics/skills` → frontend-design** — anti-slop component discipline (`/plugin marketplace add anthropics/skills`)
2. **`addyosmani/agent-skills` → frontend-ui-engineering** — WCAG/perf rationalization counter-args (`/plugin marketplace add addyosmani/agent-skills`)
3. **`vercel-labs/web-design-guidelines`** — design-system enforcement, complements frontend-design (`npx skills add vercel-labs/web-design-guidelines` via skills.sh)
4. **Stitch MCP** (optional, for visual-canvas users) — `davideast/stitch-mcp`

Skip GStack unless the user wants Bun and full-stack opinionation. Skip 21st.dev Magic until it leaves beta.

### Implementation Strategy — DESIGN.md as Glue

A single `jim:design` skill is enough. Don't ship `jim:ui` or `jim:wireframe` — they would duplicate the externally-sourced tools above.

Proposed `jim:design` responsibilities:
- **Bootstrap `DESIGN.md`** at the project root using a template that follows the Google Labs design.md spec (colors, typography, component rules) — closes the gap that frontend-design and Stitch both assume exists.
- **Validate** that `/jim:spec` for any UI feature references `DESIGN.md` and any visual constraints.
- **Recommend** (not install) the V1 setup above when no design skill is detected.
- **Augment `/jim:build`** with an optional design-QA hook (cribbed from GStack's `/qa` pattern, but bash-only — no Chromium dependency in jim itself; recommend the user install GStack if they want real-browser QA).

### Alignment

- **VISION.md** — Jim is "agentic SDLC" with spec→plan→build. A `jim:design` skill that produces `DESIGN.md` (an artifact, like spec.md) fits the artifact-producing pattern. It does **not** drift toward "vibe coding" or "virtual team" non-goals because it produces a contract, not a finished UI.
- **ARCHITECTURE.md** — `skills/design/SKILL.md` follows the existing skill convention. Adding `design_path` to `jimconf.sh` follows the existing six-key pattern. No new runtime dependencies.
- **Divergence:** None. UI design is unmentioned in current Phase 1/2/3 of the roadmap — this would be net-new scope, not a violation.

## Peer Feedback

**For PM (`@jim:pm`):** Net-new scope flag — UI design is not in VISION.md or ROADMAP.md today. Before scoping a `jim:design` spec, consider whether design support belongs in jim's north star or stays out-of-scope (let users compose Anthropic/Vercel/etc. skills directly). If yes, the spec should explicitly resolve: (a) one skill (`jim:design`) vs three (`jim:design` + `jim:ui` + `jim:wireframe`) — research recommends one; (b) which agent owns it (PM for intent, Architect for spec, or new persona); (c) whether jim ships a `DESIGN.md` template or only validates that one exists.
