# Agent Skills Plugin Interoperability Report (May 2026)

## Executive Summary

The plugin format you're using — `.claude-plugin/plugin.json` + `agents/*.md` + `skills/{name}/SKILL.md` + bash scripts — is the **Claude Code plugin spec**, which wraps the broader **Agent Skills standard** that Anthropic open-sourced in December 2025. The standard itself (just the `skills/` portion + `SKILL.md` format) has had the fastest cross-vendor adoption event in AI tooling history: 32+ tools by March 2026.

**The Portability Rule:** the `skills/` folder travels everywhere; `plugin.json` and `agents/*.md` are Claude Code–specific and must be repackaged or stripped for other tools.

**The cross-agent path convention:** most non-Claude tools also crawl `.agents/skills/` (project) and `~/.agents/skills/` (user) as a vendor-neutral discovery path. Symlink `skills/ → .agents/skills/` at the repo root and you cover most distribution targets in one move.

---

## 1. Tool Compatibility Matrix

| Tool | Status | Skills Path | `plugin.json`? | `agents/*.md`? |
|---|---|---|---|---|
| Claude Code | FULL | `~/.claude/plugins/`, `.claude/skills/` | ✅ | ✅ |
| Codex CLI | FULL | `~/.codex/skills/`, `.agents/skills/` | ❌ (Codex manifest) | ⚠️ (use `openai.yaml`) |
| Cursor | FULL (project-only) | `.cursor/skills/`, `.agents/skills/` | ❌ | ❌ |
| Windsurf | FULL | `.windsurf/skills/`, `~/.windsurf/skills/` | ❌ | ❌ |
| Gemini CLI | FULL (skills only) | `.gemini/skills/`, `~/.gemini/skills/` | ❌ | ❌ |
| Cline | FULL | `.cline/skills/`, `~/.cline/skills/` | ❌ | ❌ |
| Roo Code | FULL (mode-aware) | `.roo/skills/`, `.roo/skills-{mode}/` | ❌ | ❌ |
| Junie / JetBrains Air | FULL | `.junie/skills/`, `~/.junie/skills/` | ❌ | ❌ |
| Aider | NONE | (workaround: `CONVENTIONS.md`) | ❌ | ❌ |

---

### Claude Code
* **Status: FULL (Native).** The reference implementation. Full plugin spec (`plugin.json`, `agents/`, `skills/`, `hooks/`, `.mcp.json`, `.lsp.json`) supported. Docs: [code.claude.com/docs/en/plugins](https://code.claude.com/docs/en/plugins).
* **Limitation:** Skill descriptions capped at ~2% of context window — verbose ones get silently dropped. Bash gated by `allowed-tools` frontmatter and the sandbox permission model. Claude.ai-uploaded skills don't sync to Claude Code and vice versa.
* **How to load:** (1) Drop folder in `~/.claude/plugins/` and run `/plugin install`; (2) `/plugin marketplace add owner/repo` then install; (3) `claude --plugin-dir ./my-plugin` for development.
* **Invocation Method:** Both. Slash command `/plugin-name:skill-name` (namespaced) or autonomous model invocation via description match.
* **Internal Invocation:** No formal cross-skill `import`. Skills reference each other in prose; Claude reads the referenced `/skill-name` and activates it. The `agent: <name>` frontmatter routes a skill into a subagent defined in `agents/`. The `context: fork` mode runs a skill in a fresh subagent that can in turn invoke other skills.
* **Modifications needed:** None.
* **Marketplace:** Official: [github.com/anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official). Submission: [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit).

### Codex CLI (OpenAI)
* **Status: FULL.** Native Agent Skills + a full Plugins distribution layer. Docs: [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills).
* **Limitation:** Initial skill list capped at ~8000 chars / 2% context; excess silently dropped. Claude's `agents/*.md` doesn't map directly — Codex uses `agents/openai.yaml` for UI metadata, invocation policy, and tool dependency declarations (not subagent personas). Bash runs in the Codex sandbox (macOS / Linux / native Windows).
* **How to load:** Drop `skills/` content into `~/.codex/skills/`, `.codex/skills/`, or `.agents/skills/` (walked from CWD up to repo root). Full plugins: `codex marketplace add <git-url>`.
* **Invocation Method:** Both. Implicit (description match) or explicit `$skill-name` / `/skills` picker.
* **Internal Invocation:** Prose reference. Codex doesn't merge identically named skills; both surface in the picker.
* **Modifications needed:** Optional `agents/openai.yaml` per skill for richer Codex-app integration. Claude-specific frontmatter (`context: fork`, `agent:`) is silently ignored.
* **Marketplace:** [developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins) and [github.com/openai/skills](https://github.com/openai/skills).

### Cursor
* **Status: FULL (project-only).** Native skills support shipped in Cursor 2.4. Docs: [cursor.com/docs/skills](https://cursor.com/docs/skills).
* **Limitation:** **No global/user-level skills directory** — the only major tool with this restriction. Hooks within skills require nightly-channel features. Bash respects Cursor's auto-run + sandbox permission model.
* **How to load:** `mkdir -p .cursor/skills && cp -r your-plugin/skills/* .cursor/skills/`, then reload the workspace. Cursor also reads `.agents/skills/`.
* **Invocation Method:** Both. Implicit or explicit via `/` slash menu.
* **Internal Invocation:** Prose reference.
* **Modifications needed:** Drop `plugin.json`. Move always-on `agents/*.md` content into `.cursorrules`. Commit `.cursor/skills/` to the repo for team distribution (no global path exists).
* **Marketplace:** [cursor.com/marketplace](https://cursor.com/marketplace).

### Windsurf (Cascade)
* **Status: FULL.** Cascade gained native SKILL.md loading in March 2026. Docs: [docs.windsurf.com/windsurf/cascade/skills](https://docs.windsurf.com/windsurf/cascade/skills).
* **Limitation:** Bash gated by Cascade's Web Fetch / shell tool consent flow. Enterprise teams can pre-deploy skills via MDM-managed configs. The legacy `.windsurf/skills.json` URL-pinning manifest still exists alongside SKILL.md folders.
* **How to load:** Copy `skills/*` to `.windsurf/skills/` (workspace) or `~/.windsurf/skills/` (user). `.agents/skills/` and `~/.agents/skills/` also discovered.
* **Invocation Method:** Both — implicit, or explicit `@skill-name` in Cascade.
* **Internal Invocation:** Prose; supporting files (e.g., `rollback-procedure.md`) loaded only when the skill body references them.
* **Modifications needed:** Drop `plugin.json` and `agents/*.md`. Persona content can move into Windsurf's "Memories & Rules" or directory-scoped `AGENTS.md`.
* **Marketplace:** [skills.sh](https://skills.sh) (cross-tool registry); no first-party Windsurf marketplace.

### Gemini CLI
* **Status: FULL (skills only).** Native discovery, the internal `activate_skill` tool, and `/skills` command suite. Docs: [geminicli.com/docs/cli/skills](https://geminicli.com/docs/cli/skills).
* **Limitation:** Workspace skills only load if the folder is **trusted** (`/trust` required). Discovery is one directory deep — `.gemini/skills/<skill>/SKILL.md` works, deeper nesting is ignored. **YAML frontmatter must be the absolute first content** (even a leading H1 causes silent skip). Bash runs via `run_shell_command` with consent prompt every activation.
* **How to load:** Copy into `~/.gemini/skills/`, `.gemini/skills/`, or `.agents/skills/` (cross-agent alias takes precedence within a tier). Or package as a Gemini extension: `gemini extensions install <git-url> --consent`. For loose folders: `/skills link <path>`.
* **Invocation Method:** Implicit only — description matching triggers the internal `activate_skill` tool. No skill-level slash mention.
* **Internal Invocation:** Gemini's `activate_skill` is a real structured tool — but cross-skill chaining still happens through prose references, not a dedicated import primitive. Bundled scripts execute via `run_shell_command` when the skill body says so.
* **Modifications needed:** Drop `plugin.json` (harmless but unused). Convert `agents/*.md` into either skills or a top-level `GEMINI.md` (no subagent format). Verify YAML frontmatter is the file's very first content. Optional: add `gemini-extension.json` for extension distribution.
* **Marketplace:** [skills.sh](https://skills.sh), Gemini Extensions registry, [github.com/google-gemini/gemini-skills](https://github.com/google-gemini/gemini-skills).

### Cline
* **Status: FULL.** Native Agent Skills compatibility shipped in Cline 3.48.0 (January 2026). Docs: [docs.cline.bot/customization/skills](https://docs.cline.bot/customization/skills).
* **Limitation:** SKILL.md should stay under 5K tokens (Cline reads sequentially — front-load common cases). Bash runs through Cline's standard tool-approval flow. UI-level enable/disable toggle per skill. Global skills override project skills of the same name.
* **How to load:** Copy `skills/*` into `.cline/skills/` (project) or `~/.cline/skills/` (global). Auto-detected. Also via UI: scale icon → Skills tab → "New skill…".
* **Invocation Method:** Implicit only — description matching.
* **Internal Invocation:** Prose reference. Cline's `read_file` fetches referenced docs on demand.
* **Modifications needed:** Drop `plugin.json` and `agents/*.md`. Convert agent personas into separate skills with carefully tuned descriptions.
* **Marketplace:** None first-party; pulls from the broader skills ecosystem.

### Roo Code
* **Status: FULL (mode-aware).** Distinct from Cline despite the shared VS Code lineage. Docs: [docs.roocode.com/features/skills](https://docs.roocode.com/features/skills).
* **Limitation:** Skills are instruction packages only — they don't register new executable tools (Roo distinguishes this from slash commands). `.roo/` paths take precedence over generic `.agents/` paths.
* **How to load:** In priority order: `.roo/skills-{mode}/<skill>/SKILL.md` (project, mode-specific) → `.roo/skills/` (project, all modes) → `~/.roo/skills/` (global) → `.agents/skills/` → `~/.agents/skills/`. Symlinks supported.
* **Invocation Method:** Implicit, scoped to the active mode (Code, Architect, Orchestrator, etc.).
* **Internal Invocation:** Prose reference. Mode targeting via `skills-{mode}/` directory naming is the unique Roo feature.
* **Modifications needed:** Drop `plugin.json` and `agents/*.md`. Decide if any skills should be mode-scoped. Map `agents/*.md` content to existing Roo modes rather than recreating subagents.
* **Marketplace:** Cross-agent registries (skills.sh, Agensi, GitHub).

### Junie / JetBrains Air
* **Status: FULL.** Junie added Agent Skills in March 2026 — works in JetBrains IDEs and Junie CLI. Air dispatches to Junie/Codex/Claude Agent/Gemini CLI via the Agent Client Protocol (ACP), so skill availability in Air depends on which agent it routes to. Docs: [junie.jetbrains.com/docs/agent-skills.html](https://junie.jetbrains.com/docs/agent-skills.html).
* **Limitation:** Strict YAML — malformed frontmatter is silently skipped. Bash runs through Junie's tool-approval flow with optional Docker/worktree sandboxing.
* **How to load:** Copy `skills/*` into `.junie/skills/` (project) or `~/.junie/skills/` (user). Junie CLI offers one-click migration from Claude Code/Codex skill directories.
* **Invocation Method:** Both. Implicit, or explicit ("Use the testing skill to write tests for this module").
* **Internal Invocation:** Prose reference. Junie supports a hierarchical pattern: top-level SKILL.md links to sub-documents (e.g., `checklists/kotlin.md`) loaded only when needed.
* **Modifications needed:** Drop `plugin.json`. Translate `agents/*.md` into Junie subagents (Junie-specific format) or fold into skills. Validate YAML strictly.
* **Marketplace:** None first-party yet; standards-compliant sources accepted.

### Aider
* **Status: NONE (native).** As of May 2026, no Agent Skills support. Aider is a terminal git-aware pair-programmer — closest equivalents are `.aider.conf.yml` and `CONVENTIONS.md`.
* **Limitation:** No autonomous shell execution (Aider edits files, runs lint/test hooks, commits — but cannot run arbitrary bash like Claude Code or Codex). No skill discovery, no description-based routing, no subagents.
* **How to load (workaround only):**
  1. **Flatten:** Concatenate SKILL.md bodies into a single `CONVENTIONS.md` and load via `aider --read CONVENTIONS.md` or `.aider.conf.yml`. Loses progressive disclosure entirely.
  2. **MCP bridge:** Expose skills via `skill-to-mcp` or `skillport-mcp` and connect through community MCP shims for Aider.
* **Invocation Method:** N/A natively.
* **Internal Invocation:** Not supported.
* **Modifications needed:** Substantial: concatenate, strip YAML, remove bash invocations (or re-implement as `auto-test`/`auto-lint` hooks in `.aider.conf.yml`).
* **Marketplace:** None.

---

## 2. Conversion, Bridge & Orchestration Tools

| Tool Name | Project Link | Popularity | Key Features |
|---|---|---|---|
| **skills CLI** | [skills.sh](https://skills.sh) | Universal | The "npm" of skills. Auto-detects 50+ installed agents and routes skills to the correct system paths. 89K+ skills indexed. |
| **SkillPort** | [github.com/gotalab/skillport](https://github.com/gotalab/skillport) | Critical | Dual-Mode. CLI for shell agents (Claude Code, Codex) + MCP server (`skillport-mcp`) for IDEs. Search-first, load-on-demand pattern. |
| **Agent Skill Loader** | [github.com/back1ply/agent-skill-loader](https://github.com/back1ply/agent-skill-loader) | High | Prompt Injection. Exposes skills as MCP prompts (native slash commands) and as tools simultaneously. Live `listChanged` notifications when skills are added. |
| **superpowers-mcp** | [github.com/erophames/superpowers-mcp](https://github.com/erophames/superpowers-mcp) | Specialized | Triple Exposure. Wraps skills as MCP Tools, Prompts, AND Resources simultaneously. Cleanest reference implementation for all three exposure modes. |
| **MCPorter** | [github.com/arghhhhh/mcp-skills-bridge](https://github.com/arghhhhh/mcp-skills-bridge) | Mid-tier | Inverse Routing. Uses SKILL.md as a routing layer over multiple existing MCP servers via the `mcporter call <server>.<tool>` CLI. |
| **skill-to-mcp** | [github.com/biocontext-ai/skill-to-mcp](https://github.com/biocontext-ai/skill-to-mcp) | Stable | Reliable MCP wrapper exposing SKILL.md as JSON-RPC resources. PyPI: `skill_to_mcp`. Stdio + HTTP transports, Docker image. |
| **OpenSkills** | [github.com/numman-ali/openskills](https://github.com/numman-ali/openskills) | Stable | Fallback Generator. Universal installer (npm) that auto-generates AGENTS.md for tools without skill discovery (Aider, etc.). |
| **agent-skills-manager** | [github.com/umutbozdag/agent-skills-manager](https://github.com/umutbozdag/agent-skills-manager) | Niche | GUI Dashboard. Bulk toggle/sync/move skills across 11 IDEs (Cursor, Claude, Windsurf, Copilot, Codex, Cline, Aider, Continue, Roo Code, Augment, Agents). |
| **MCP Toolbox `skills-generate`** | [Google Cloud blog post](https://medium.com/google-cloud/bring-your-database-tools-to-the-agent-skill-ecosystem-dfff0fee08cb) | Specialized | Reverse Direction. Converts existing MCP toolsets *into* SKILL.md packages with Node.js wrappers. v0.27.0+ of MCP Toolbox for Databases. |

### Adjacent Tools (Worth Knowing, Not Skill Bridges)

* **Context (Neuledge)** — [github.com/neuledge/context](https://github.com/neuledge/context) — MCP documentation-lookup server. Indexes 100+ library docs (Next.js, React, Prisma, Django, Spring Boot) into local SQLite+FTS5 packages. **NOT a skills bridge** — but useful as a complement: skills tell the agent *how* to do something; Context tells it *what the current API looks like*. Local-first, Apache-2.0, MCP-compatible across Claude Code, Cursor, Codex, Windsurf, VS Code, Zed, Goose, OpenCode.

### Deprecated / Retired

* **claude-skills-mcp** ([K-Dense-AI/claude-skills-mcp](https://github.com/K-Dense-AI/claude-skills-mcp)) — Vector-search-based skill-discovery MCP server. **Officially retired in 2026**, with the maintainers citing native skill adoption across Cursor, Windsurf, Claude Code, and Copilot as having eliminated the need for general-purpose MCP bridges. Useful as a signal that the bridge category is consolidating around niche use cases (Aider, MCP-only IDEs, novel exposure modes) rather than expanding.
---

## 3. Cross-Platform Plugin Examples

* **huggingface/skills** — [github.com/huggingface/skills](https://github.com/huggingface/skills) — ML/AI workflow skills (Hub ops, TRL training, eval, Gradio, papers). The canonical multi-target bundle: ships `.claude-plugin/marketplace.json` + `gemini-extension.json` + `.cursor-plugin/plugin.json` + AGENTS.md fallback in one repo. **Tools:** Claude Code, Codex, Gemini CLI, Cursor (and AGENTS.md fallback for everything else).

* **VoltAgent/awesome-agent-skills** — [github.com/VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) — Curated catalog of 1,000+ skills from official dev teams (Flutter, OpenAI, Hugging Face, Trail of Bits) and community. **Tools:** Claude Code, Codex, Gemini CLI, Cursor explicitly; many also tested on Windsurf/Cline/Roo via `.agents/skills/`.

* **openai/skills** — [github.com/openai/skills](https://github.com/openai/skills) — OpenAI's curated catalog: Cloudflare deploy, Playwright web games, docx, GitHub PR/CI, image gen, Jupyter, Linear, Netlify deploy. **Tools:** Codex (primary), but plain SKILL.md works in Claude Code, Gemini CLI, Cursor, Windsurf.

* **anthropics/skills** — [github.com/anthropics/skills](https://github.com/anthropics/skills) — Anthropic's reference implementation (pptx, xlsx, docx, pdf, MCP server generation, skill-creator). **Tools:** Claude Code (native), Claude.ai (zip upload), Codex (`$skill-installer`), Gemini CLI (`gemini extensions install`), Cursor (manual copy).

---

## 4. The 2026 Portability Recipe

1. **Source of truth:** Keep your Claude Code structure intact (`.claude-plugin/plugin.json` + `agents/` + `skills/`). It works as-is in Claude Code, OpenCode/OpenClaw, Codex (with optional `agents/openai.yaml`), and Junie.

2. **The Symlink Hack:** Add `.agents/skills/ → skills/` at the repo root. This single move covers Gemini CLI, Windsurf, Roo Code, Cursor, and most community-shim tools. *On Windows, use directory junctions (`mklink /J`) or duplicate the directory; symlinks require Developer Mode and don't always survive `git clone`.*

3. **Pin or vendor:** The `.agents/skills/` convention has no native versioning. For team or production use, either pin marketplace plugins to specific commit SHAs, or vendor skills directly into your repo rather than symlinking external sources. Skills can change behavior between commits silently.

4. **Auto-generate a fallback catalog** for tools without skill discovery (Aider, older agents). `openskills sync` and `skillport doc` automate this. Name the output something distinct (e.g., `AGENTS_SKILLS.md`) to avoid collision with Codex-style project-instruction `AGENTS.md` files.

5. **Tool-specific manifests live alongside, not instead of:** `gemini-extension.json`, `.cursor-plugin/plugin.json`, `.claude-plugin/marketplace.json` can all sit at the repo root simultaneously. See `huggingface/skills` for the canonical layout.

6. **Non-interactive bash, no TTY assumed:** Sandboxed IDEs prompt for consent on every shell call — interactive `y/n` prompts will hang. Use `--yes`, env-var flags, or `<<< 'y'` heredocs. Also avoid scripts that depend on `isatty()`, terminal colors, or interactive `read` — most sandboxes run without a real TTY. Test under `bash -c '<script>' < /dev/null` to catch this.

7. **Env vars: shared dotfile first, per-tool config second.** The portable answer is a project-root `.env` or `.env.skills` file that every script sources explicitly: `source "$(git rev-parse --show-toplevel)/.env.skills" 2>/dev/null || true`. Per-tool config layers (`~/.codex/config.toml`, Gemini extension config, Windsurf's "Trust" model, Claude Code's plugin `.env`) are the fallback when shared dotfiles aren't viable. Don't assume `process.env.X` set in one tool propagates to another.

8. **Don't trust the word "agent" across tools.** `agents/*.md` in Claude Code is a forking subagent with its own context window. The same word means different things in Codex (UI persona via `openai.yaml`), Junie (workflow specialist), Cursor (no equivalent — use `.cursorrules` instead), Windsurf (Memories & Rules), and Gemini (no equivalent — fold into `GEMINI.md`). Test each agent migration by hand; there is no automated equivalent.

9. **Persona logic moves; instructions stay.** `agents/*.md` is the only part that doesn't travel. `SKILL.md` itself rarely needs changes between targets — but verify YAML frontmatter is the very first content (Gemini silently skips files with leading H1s) and that directory names match the `name:` field exactly.

10. **For MCP-only clients or Aider:** wrap with `skillport-mcp`, `skill-to-mcp`, or `agent-skill-loader`. **Honest tradeoff:** MCP wrapping converts an instruction-loading pattern into a function-calling pattern. You lose progressive disclosure, auto-activation by description match, and native `/skill-name` invocation. The agent sees a tool to call rather than a workflow to follow — and for complex multi-step skills, often calls it once, gets instructions, then drifts from them. Keep skills native wherever the target tool supports them.