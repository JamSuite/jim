---
spec: docs/specs/sdlc/001-meta/spec.md
type: prior-art
status: Needs Architect Review
date: 2026-05-05
---

# Research: @jim:meta, /jim:meta-skill, /jim:meta-agent

No codebase to research — this is a greenfield plugin component. Instead, this document surveys prior art references and extracts what to carry forward into our implementation.

---

## Sources

1. **Claude Code Skills documentation** — `https://code.claude.com/docs/en/skills` (official)
2. **Claude Code Sub-agents documentation** — `https://code.claude.com/docs/en/sub-agents` (official)
3. **Anthropic skill-creator** — `https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md` (full SKILL.md pasted in conversation)
4. **aitmpl.com agent development** — `https://www.aitmpl.com/component/skill/development/agent-development` (fetched during PM interview)
5. **meta-architect-skill** — `~/.claude/skills/meta-architect-skill/SKILL.md` (existing in this environment)

---

## Claude Code Documentation Summary

### 1. Skills (`code.claude.com/docs/en/skills`)

**Where skills live:**

| Location | Path | Applies to |
|----------|------|------------|
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin is enabled |

Plugin skills are namespaced: `/jim:skill-name`. They cannot conflict with other levels.

**Frontmatter fields (all optional except by convention):**

| Field | Required | Notes |
|-------|----------|-------|
| `name` | No | Defaults to directory name. Lowercase, hyphens, max 64 chars. |
| `description` | Recommended | Primary trigger mechanism. Omitting uses first paragraph. |
| `argument-hint` | No | Shown in autocomplete, e.g. `[issue-number]` |
| `disable-model-invocation` | No | `true` = only user can invoke (manual `/name` only) |
| `user-invocable` | No | `false` = only Claude can invoke (hides from `/` menu) |
| `allowed-tools` | No | Tools Claude can use without approval when skill is active |
| `model` | No | Override model for this skill |
| `context` | No | `fork` = run in isolated subagent |
| `agent` | No | Which subagent type to use when `context: fork` is set |
| `hooks` | No | Lifecycle hooks scoped to this skill |

**Key mechanics:**
- Skill `description` is always in context (so Claude knows what's available). Full SKILL.md body loads only when invoked.
- `$ARGUMENTS` substitution — replaced with what user typed after `/skill-name`
- `${CLAUDE_SKILL_DIR}` — path to the skill's directory (useful for referencing bundled scripts)
- `context: fork` + `agent:` runs the skill in an isolated subagent context — the skill content becomes the task prompt
- `allowed-tools` grants the listed tools without per-use approval when the skill is active

**Progressive disclosure (official):**
```
skill-name/
├── SKILL.md           # Required. Keep under 500 lines.
├── assets/            # Templates, files used in output
├── references/        # Long-form docs loaded as needed
└── scripts/           # Executable scripts (run, not loaded)
```

**Invocation control:**
| Frontmatter | User can invoke | Claude can invoke |
|-------------|----------------|-------------------|
| (default) | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user-invocable: false` | No | Yes |

---

### 2. Sub-agents (`code.claude.com/docs/en/sub-agents`)

**Where agents live:**

| Location | Scope | Priority |
|----------|-------|----------|
| `--agents` CLI flag | Current session | 1 (highest) |
| `.claude/agents/` | Current project | 2 |
| `~/.claude/agents/` | All projects | 3 |
| `<plugin>/agents/` | Where plugin enabled | 4 (lowest) |

When the same name exists at multiple levels, higher priority wins. Project agents override plugin agents.

**Frontmatter fields:**

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Unique identifier, lowercase + hyphens |
| `description` | Yes | When Claude should delegate to this agent |
| `tools` | No | Allowlist. Inherits all if omitted. |
| `disallowedTools` | No | Denylist. Removed from inherited/specified. |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit`. **Defaults to `inherit`.** |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | No | Max agentic turns before stopping |
| `skills` | No | Skills to preload into agent context at startup (full content injected) |
| `mcpServers` | No | MCP servers available to this agent |
| `hooks` | No | Lifecycle hooks scoped to this agent |
| `memory` | No | Persistent memory: `user`, `project`, or `local` |
| `background` | No | `true` = always run as background task |
| `isolation` | No | `worktree` = run in isolated git worktree |

**Key mechanics:**
- Markdown body becomes the **system prompt** — agents receive only this plus basic env details (working dir, etc.). They do NOT inherit the full Claude Code system prompt.
- `model` **defaults to `inherit`** (not `sonnet`). Explicitly set `model: sonnet` or `model: opus` if you want a specific model.
- `skills` field preloads full skill content at startup. Agents do NOT inherit skills from the parent conversation — must list explicitly.
- `memory` gives the agent a persistent directory (`MEMORY.md` + topic files) that survives across sessions.
- **Agent tool for subagent delegation:** Agents can spawn other agents programmatically by including `Agent` in their `tools` field. Use `Agent(name1, name2)` to restrict which subagents can be spawned. Subagents start with fresh context (only the prompt passed via the Agent tool, not the parent's conversation). **Key constraint:** subagents cannot nest — only one level of delegation is supported (parent → child, not parent → child → grandchild).

**⚠ Important for jim:**
The `agent:` field in jim skill frontmatter (e.g. `agent: meta`) is **NOT a native Claude Code skill field**. In official docs, `agent:` only exists in skills when used with `context: fork`. Jim uses it as a **documentation convention** — it records which agent runs the skill, but Claude Code does not use it for routing. Routing happens because the skill's instructions direct Claude to the right agent.

---

## Prior Art Survey

### Agent Skills Open Standard (agentskills.io)

**What it is:** An open standard for AI skills, originally developed by Anthropic and released December 2025. Now adopted by 30+ tools: Claude Code, GitHub Copilot, Gemini CLI, Cursor, Windsurf, OpenAI Codex CLI, Roo Code, JetBrains Junie, and others.

**This is the baseline Claude Code builds on top of.**

**Canonical SKILL.md spec (minimum viable):**

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | 1–64 chars, lowercase + hyphens, **must match directory name exactly** |
| `description` | Yes | 1–1024 chars. Must answer both *what it does* AND *when to use it* |
| `license` | No | License name or bundled file reference |
| `compatibility` | No | Max 500 chars; environment requirements |
| `metadata` | No | Arbitrary key-value map (author, version, etc.) |
| `allowed-tools` | No | Space-delimited; experimental |

**Validation CLI:** `skills-ref validate ./my-skill` (`github.com/agentskills/agentskills`)

**Implication for jim:** Jim's skill format is a superset of this standard (Claude Code adds more fields). The `name`-matches-directory constraint is enforced at the open standard level — jim's validator must check this.

---

### Claude Code Internal Prompts (Piebald-AI/claude-code-system-prompts)

**What it is:** A GitHub repo containing Claude Code's own internal system prompts, including sub-agent prompts (Plan, Explore, Task), skill creation logic, and CLAUDE.md handling. Reference-grade source for understanding exactly how Claude Code orchestrates agents and skills internally.

**Key reference:** `github.com/Piebald-AI/claude-code-system-prompts` — useful if we need to understand edge cases in how Claude Code loads/routes skills and agents.

---

### Community Skill Collections

| Resource | What it contains |
|----------|-----------------|
| `github.com/VoltAgent/awesome-agent-skills` | 500+ skills compatible with Claude Code, Copilot, Gemini CLI, Cursor |
| `github.com/hesreallyhim/awesome-claude-code` | Curated index: skills, hooks, agents, plugins, CLAUDE.md templates |
| `github.com/rahulvrane/awesome-claude-agents` | Claude Code subagent collection |
| `skillsmp.com` | Cross-platform skills marketplace |

**Implication for jim:** The jim-produced skills and agents should be compatible with the open standard so they could theoretically be published to these collections.

---

### CrewAI — Agent Role Definition Pattern

**What it is:** Most prominent multi-agent framework. Defines agents with three required fields:

```yaml
agent_name:
  role: >
    Agent's professional title and domain
  goal: >
    Specific objective guiding decisions
  backstory: >
    Background context shaping personality/reasoning
```

**Borrowable insight:** When writing agent `description` fields, covering all three axes — what the agent IS (role), what it's optimizing for (goal), and the context it reasons from (backstory) — produces better routing than flat task descriptions. Jim agent descriptions should aim for this depth.

---

### meta-agent (DannyMac180/meta-agent)

**What it is:** Interview-driven agent creator. Guided questions → JSON schema spec → validate → generate agent. The closest existing tool to what `@jim:meta` does.

**Pattern:** Capture intent through structured interview → generate from spec → validate before output. This is exactly jim's spec → plan → build → validate flow. Validates our approach.

---

### Patterns Worth Borrowing (Summary)

| Pattern | Source | Application to jim |
|---------|--------|--------------------|
| `name` must match directory name | agentskills.io (open standard) | Required validation check in both skills |
| `description` must answer what + when | agentskills.io | Validation: check description has triggering conditions |
| Two required fields: name + description | agentskills.io | Minimum viable frontmatter |
| role/goal/backstory triad for descriptions | CrewAI | Guide for writing richer agent descriptions |
| Validate before output | ROMA, skill-creator, meta-agent | ✓ Already in our spec |
| Interview → spec → generate | meta-agent | ✓ Jim's full workflow |

---

## Prior Art Review

### 1. Anthropic Skill Creator

A complete skill-building pipeline: intent capture → write SKILL.md → run test evals → browser-based review → iterate → description optimization → package.

**Key ideas:**

**Skill anatomy:**
```
skill-name/
├── SKILL.md              ← required
└── Bundled Resources/
    ├── scripts/          ← executable code, runs without loading into context
    ├── references/       ← docs loaded into context as needed
    └── assets/           ← templates, icons, files used in output
```

**Progressive disclosure (3 levels):**
1. Metadata (name + description) — always in context, ~100 words
2. SKILL.md body — in context when skill triggers, ≤500 lines
3. Bundled resources — loaded as needed, unlimited

**Description is the primary trigger mechanism:**
- Must state *when* to use, not just *what* it does
- Should be "pushy" — explicitly name the contexts that should trigger it
- Bad: `"How to build a dashboard."` → Good: `"How to build a dashboard. Use whenever the user mentions dashboards, data visualization, or wants to display company data, even if they don't explicitly ask for a 'dashboard.'"`

**Writing style:**
- Imperative form in instructions
- Explain the **why** behind rules, not just the rule itself — LLMs respond better to reasoning than to rigid MUSTs
- Avoid ALL-CAPS MUSTs where a clear rationale would work better
- Keep it lean — remove things not pulling their weight
- Use theory of mind: transmit understanding, not just directives

**Domain organization pattern:**
```
cloud-deploy/
├── SKILL.md              ← workflow + selection logic
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md          ← Claude reads only the relevant one
```

**What we're NOT adopting from skill-creator (out of scope for v1):**
- Eval loop (subagents running with/without skill, benchmarking)
- Browser-based eval viewer
- Description optimization scripts (`run_loop.py`)
- Packaging (`.skill` files)
- Python scripts infrastructure

---

### 2. aitmpl.com Agent Development

Structured standards for agent component creation.

**Identifier rules:**
- 3–50 characters, lowercase with hyphens only
- Must start and end with alphanumeric characters

**Description requirements:**
- Must include triggering conditions
- Must include `<example>` blocks showing concrete usage
- Each example must have: user request, assistant response, commentary explaining appropriateness

**Frontmatter fields:** name, description, model, tools, version

**System prompt standards:**
- Second-person voice: `"You are..."`
- Required sections: core responsibilities, analysis process, quality standards, output format, edge case handling

**Least privilege:** agents receive only the tools they actually need

---

### 3. meta-architect-skill (existing in earlier predecessor to jim)

The base standards for `.claude/` ecosystem components. Already well-defined — jim should align with these, not contradict them.

**What it enforces:**

| Check | Threshold |
|-------|-----------|
| Frontmatter | name, description, tools, model — all required |
| Token budget | agents <800 tokens, skills <500 lines |
| Naming | kebab-case; `name` field must match filename exactly |
| Tool permissions | Only tools actually used |
| Command voice | Imperative, not "please try to" |

**Anti-patterns:**
- Personality Soup: "I am an AI assistant here to help"
- Permission Creep: Write/Bash for read-only agents
- Instruction Shadowing: repeating rules already in CLAUDE.md
- Duplicate Logic: same instructions in 3+ agents → extract to shared skill
- Missing Frontmatter: every component needs it for discoverability

---

## Synthesis: What to Carry Forward

These are the items from prior art that add value beyond what jim's existing WORKFLOW.md already specifies.

### For SKILL.md standards

| Item | Source | Why it matters |
|------|--------|---------------|
| Description must include triggering conditions | Skill-creator, aitmpl | Description is the *only* thing Claude sees when deciding whether to invoke a skill. Vague descriptions cause undertriggering. |
| Description should be "pushy" — name the contexts explicitly | Skill-creator | Prevents undertriggering, which is the most common failure mode. |
| Imperative form in instructions | Skill-creator | Consistent, direct, easier to follow. |
| Explain the *why*, not just the *what* | Skill-creator | LLMs use reasoning; understanding intent produces better results than rigid rules. |
| `references/` files >300 lines need a ToC | Skill-creator | Progressive disclosure — help Claude find what it needs without loading everything. |
| Domain variants go in `references/` subdirectory | Skill-creator | Keeps SKILL.md lean; Claude loads only the relevant variant. |

### From Claude Code official docs

| Item | Source | Why it matters |
|------|--------|---------------|
| Agent `model` defaults to `inherit`, not `sonnet` | Official docs | Must explicitly set `model: sonnet` in agent frontmatter — don't assume it defaults. |
| Plugin agents have lowest priority (4) | Official docs | Project `.claude/agents/` overrides plugin agents of the same name. |
| Agent markdown body = full system prompt | Official docs | Agents receive ONLY this + basic env. No Claude Code system prompt inheritance. Must be self-contained. |
| Skill `description` always in context; body loads on invocation | Official docs | Description is the trigger surface. Body is the execution surface. Keep both tight. |
| Jim's `agent:` field in skill frontmatter is documentation-only | Official docs | Not a native Claude Code routing mechanism. Works as a convention/metadata only. |
| `$ARGUMENTS` substitution in skills | Official docs | Enables `/jim:meta-skill my-skill-name` to pass the name directly to the skill. |
| `skills` field in agents preloads full content at startup | Official docs | Alternative to relying on skill auto-triggering — guarantees the skill is in context. |
| `Agent` tool enables programmatic subagent delegation | Official docs | Agents with `Agent` in `tools` can spawn other agents. Use `Agent(pm, architect)` to scope. Subagents cannot nest (one level only). |

### For Agent standards

| Item | Source | Why it matters |
|------|--------|---------------|
| Second-person voice: "You are..." | aitmpl | Consistent persona framing across all jim agents. |
| Required sections: responsibilities, process, quality standards, output format, edge case handling | aitmpl | Ensures agents are complete — not just "what you do" but "how you do it" and "what done looks like." |
| `<example>` blocks in descriptions | aitmpl | Makes triggering deterministic; shows Claude exactly when to activate the agent. |
| Explain the *why* behind constraints | Skill-creator | Same as skills — reasoning beats directives. |

### Validation checklist for @jim:meta

When `@jim:meta` validates a produced artifact, it should check:

**Skills:**
- [ ] Frontmatter present: name, description, agent
- [ ] `name` matches directory name (kebab-case)
- [ ] SKILL.md ≤ 500 lines
- [ ] `agent:` references a valid jim agent
- [ ] Description includes triggering conditions (not just what, but when)
- [ ] assets/ and/or references/ created if overflow
- [ ] references/ files >300 lines have a ToC
- [ ] Instructions use imperative form
- [ ] No anti-patterns (personality soup, permission creep, instruction shadowing, duplicate logic)

**Agents:**
- [ ] Frontmatter present: name, description, skills (if applicable), tools, model
- [ ] `name` matches filename (kebab-case)
- [ ] Body ≤ 800 tokens
- [ ] Second-person voice ("You are...")
- [ ] Has sections: responsibilities, process, quality standards/constraints, output format
- [ ] Description includes triggering conditions + at least one example
- [ ] Tools list follows least privilege
- [ ] No anti-patterns

---

## Scripting Layer in jim plugin components

*Added 2026-05-05 as a differential update — origin: `docs/brainstorms/20260505-bash-scripts-in-meta.md`.*

When 001-meta was written, jim had no `scripts/` directory anywhere — skills were pure prompts. That changed with specs 007 (`meta-test`), 008 (`jimconf`), and 009 (`jimfile`), which introduced bash scripts under `skills/{name}/scripts/`. This section documents the cross-platform evidence justifying bash as the canonical scripting language, the runtime-assumption findings behind the choice, and the decision rule for offloading work from a prompt to a script.

### Per-platform support matrix

How major coding-agent platforms handle bash scripts in plugin/skill packages, as of 2026:

| Platform | Skills/plugins surface | Bash in `scripts/` | Other runtimes | Source |
|---|---|---|---|---|
| **Claude Code** (Anthropic) | `<plugin>/skills/<name>/SKILL.md` + `scripts/` | ✅ native — Claude reads SKILL.md and runs scripts via bash | Python, JS (via `compatibility:` declaration) | `code.claude.com/docs/en/skills` |
| **Codex CLI** (OpenAI) | Adopts SKILL.md open standard; `scripts/` optional in skill dir | ✅ via the open-standard `scripts/` dir | Underspecified — Codex docs defer to agent implementation; "Prefer instructions over scripts unless deterministic" | `developers.openai.com/codex/skills` |
| **Gemini CLI** (Google) | TOML custom commands; extensions bundle commands/MCP/skills/hooks | ✅ via `!{...}` shell injection in TOML body | bash on Linux/macOS, PowerShell on Windows | `geminicli.com/docs/cli/custom-commands` |
| **Cursor** (Cursor 2.5 plugins) | `.cursor/commands/` (Markdown) + plugin marketplace bundling skills/hooks/rules | ✅ — hooks are documented as "custom scripts that let you observe and control agent behavior" | VS Code extension ecosystem (separate surface) | `cursor.com/blog/marketplace` |
| **Aider** | In-chat `/`-commands + CLI composability | ✅ — designed to be wrapped in shell scripts via `aider --message` | — (no native `skills/` dir; agent skills consumption is via shell composition) | `aider.chat/docs/scripting.html` |

### Why bash is the genuine LCD

Three converging signals from the open standard and the platforms that implement it:

1. **The spec treats bash as the unstated default.** The Agent Skills Open Standard (`agentskills.io/specification`) lists `scripts/` as optional and notes: *"Supported languages depend on the agent implementation. Common options include Python, Bash, and JavaScript."* Anything beyond bash must be declared explicitly via the optional `compatibility:` frontmatter field (e.g. `compatibility: Requires Python 3.14+ and uv`). The spec adds: *"Most skills do not need the compatibility field"* — which positions bash as the baseline that requires no declaration.

2. **Bash is the meta-runtime that launches everything else.** From the open-standard runtime model: *"When a Skill is triggered, Claude uses bash to read SKILL.md from the filesystem... If those instructions reference other files, Claude reads those files too using additional bash commands. When instructions mention executable scripts, Claude runs them via bash."* Even Python and JS scripts in `scripts/` are invoked *via* bash (e.g. `python3 scripts/process.py`). So bash is present in every supported environment by construction; everything else is opt-in.

3. **Cross-platform reality converges on bash.** All five platforms surveyed support bash in some form. Gemini CLI is the only one that distinguishes platforms — `bash` on Linux/macOS, `powershell.exe` on Windows — but bash remains the Unix baseline. Cursor's hooks are documented as "custom scripts" without restriction. Codex CLI adopts the SKILL.md spec verbatim. Aider composes with shell scripts as a first-class extensibility model.

### The Python-in-devcontainer mystery — resolved

The brainstorm flagged a side-question (§A2): how do Anthropic's Python-based skills (e.g., `pdf-processing`, `skill-creator`) work in devcontainers without Python? Answer: **they don't, by default.** Per [anthropics/claude-code#21613](https://github.com/anthropics/claude-code/issues/21613) and Anthropic's own [`devcontainer-features`](https://github.com/anthropics/devcontainer-features), the official Claude Code devcontainer is Node.js 20 only — no Python virtualenv, `pip install` fails on `externally-managed-environment`. To run Python skills, users must add the Python devcontainer feature explicitly.

This is the practical evidence behind the `compatibility:` field being opt-in: skills that need Python *must* declare the requirement because it's not assumed. Bash needs no such declaration because it *is* assumed — the agent uses it to invoke SKILL.md and every script in the first place.

**Implication for jim:** picking bash for the scripting layer was the correct call. Adopting Python or JS as jim's canonical scripting language would have made jim skills fail in any environment that didn't pre-install the runtime — including Anthropic's own default devcontainer.

### Decision rule — bash script vs. prompt

Heuristic for skill authors deciding where logic should live:

| Use a bash script when… | Use a prompt when… |
|---|---|
| The task is **deterministic** (same input → same output, no judgment). | The task requires **judgment, synthesis, or rationale** (interview, design tradeoff, validation reasoning). |
| The cost in tokens or latency through the LLM would be 10–1000× higher than a script. | Tokens/latency are dominated by the LLM's reasoning, not the mechanical step. |
| The result is **verifiable** by exit code or string compare. | The result is qualitative ("is this spec well-scoped?"). |
| The operation can fail loudly and recoverably (exit 1, empty string). | The operation needs graceful degradation or a conversational fallback. |

Existing jim scripts that fit the rule (anchors): `skills/conf/scripts/jimconf.sh` (deterministic config parsing), `skills/file/scripts/jimfile.sh` (file/path ops — exists, slug, next-id, glob, path), `skills/meta-test/scripts/*.sh` (test execution).

Counter-examples that rightly stay in prompts: the `/jim:spec` interview, research adequacy checks (the 7-point spot-check is judgment), design tradeoff reasoning in `/jim:plan`.

The canonical home for this rule and its companion BASIC-style logic-flow idiom (sibling brainstorm `20260505-file-resolver-conventions-audit.md`) is `ARCHITECTURE.md` → Plugin Conventions, per the brainstorm's D2.

### Alignment

This research aligns with VISION.md → Roadmap Trajectory Phase 3 (cross-agent integration with Codex / Gemini CLI / other coding agents): bash-as-LCD is what makes that integration plausible without per-platform rewrites. It also aligns with ARCHITECTURE.md → Plugin Conventions → Scripting Layer, which already states *"no build step, no package manager, no third-party dependencies"* — the LCD finding is the empirical justification for that posture.

### Sources

Tier 1 (canonical):
- `agentskills.io/specification` — Agent Skills open standard
- `code.claude.com/docs/en/skills` — Claude Code skills reference
- `github.com/anthropics/skills` — Anthropic's official skills repo

Tier 2 (per-platform):
- `developers.openai.com/codex/skills` — Codex CLI agent skills
- `geminicli.com/docs/cli/custom-commands` — Gemini CLI custom commands
- `geminicli.com/docs/extensions` — Gemini CLI extensions framework
- `cursor.com/blog/marketplace` — Cursor 2.5 plugin marketplace
- `aider.chat/docs/scripting.html` — Aider scripting model

Tier 3 (Python-in-devcontainer thread):
- `github.com/anthropics/claude-code/issues/21613` — feature request for Python in official devcontainer
- `github.com/anthropics/devcontainer-features` — Anthropic's devcontainer features (Python is opt-in)

## Peer Feedback

*Added 2026-05-05.*

### For the Architect (plan delta)

The current `plan.md` for 001-meta does not include validation logic for the scripting layer (`scripts/` directories) or the BASIC-style logic-flow gate idiom. Per `docs/brainstorms/20260505-bash-scripts-in-meta.md` "Files to change" #3, the plan must be amended:

- (a) Add a new design decision covering the scripting layer's place in meta's validation flow.
- (b) Extend Task 1 (`skills/meta-skill/SKILL.md`) and Task 2 (`skills/meta-agent/SKILL.md`) checklists with script-conformance and gate-idiom validation bullets, so the plan's task list and verify commands match the amended spec.

This is not an invalidation of prior plan content — the original decisions (model: sonnet, second-person voice, differential updates, etc.) all stand. It's an additive amendment driven by the scripting layer that emerged after 001-meta was written.

## What We're Building On vs. Reinventing

| Component | Build on | Not reinventing |
|-----------|----------|-----------------|
| SKILL.md structure + progressive disclosure | Skill-creator (identical model) | ✓ Don't redesign |
| Agent frontmatter format | meta-architect-skill (already our standard) | ✓ Don't redesign |
| Jim-specific `agent:` field in skill frontmatter | jim WORKFLOW.md (our addition) | New, not in prior art |
| Spec-first workflow before building | jim WORKFLOW.md (our addition) | New — skill-creator skips this |
| Structural validation before handoff | Our decision | Skill-creator uses eval loop instead; we do structural only in v1 |
| Differential update (refine, don't overwrite) | jim WORKFLOW.md (our addition) | New — not in prior art |
