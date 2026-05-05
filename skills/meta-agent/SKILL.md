---
name: meta-agent
description: >
  Create or update a jim plugin agent from an approved spec and plan.
  Use when the user invokes /jim:meta-agent, asks to build a jim agent,
  or wants to create an agent .md file for the jim plugin. Do not use
  for building application code or non-jim agents.
agent: meta
argument-hint: "[agent-name]"
allowed-tools: Bash(bash *)
---

# /jim:meta-agent

Create or update a jim plugin agent (`agents/{name}.md`) from an approved spec and plan.

*(The `agent: meta` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Process

### 1. Pass three gates before building

Use `$ARGUMENTS` as a hint for the agent name. Search `!`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get specs`/jim/` for a matching approved spec (`status: approved` in frontmatter), or ask the user which spec to build from.

**Gate 1 — Spec:** Locate an approved spec in `!`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get specs`/jim/`. If no approved spec exists, spawn `@jim:pm` via the Agent tool to create one. If the pm agent is not available, tell the user to run `/jim:spec` instead.

**Gate 2 — Research Quality:** Read `research.md` from the spec directory. Evaluate it against this 7-point spot-check:

1. **Official Docs** — cites and summarizes Claude Code **sub-agents** documentation (not just skills)
2. **Platform Capabilities** — documents current frontmatter fields, mechanics, behavioral defaults
3. **Prior Art** — includes 1-2+ concrete prior art examples with extracted patterns, not just links
4. **Concrete Examples** — includes at least one real agent `.md` file to pattern-match against
5. **Synthesis** — contains a "what to carry forward" section with actionable items
6. **Freshness** — explicitly addresses current mechanics (no stale assumptions)
7. **Spec Alignment** — frontmatter `spec:` field points to the correct spec

If research.md is missing or fails ANY check, spawn `@jim:researcher` via the Agent tool, detailing exactly what is missing or inadequate. After research is fixed, any existing plan.md must be reviewed and updated by `@jim:architect` — the plan may have been built on flawed or missing research. Tell the user to invoke `/jim:plan` after research is complete. If the researcher agent is not available, tell the user to run `/jim:research` instead. Stop execution.

**Gate 3 — Plan:** Locate `plan.md` alongside the spec. If no plan exists, spawn `@jim:architect` via the Agent tool to create one. If the architect agent is not available, tell the user to run `/jim:plan` instead.

After all three gates pass, read spec + plan + research fully. Note the agent name, purpose, skills it composes, tools it needs, acceptance criteria, task breakdown, and platform findings before writing anything. The research contains domain knowledge (e.g., Claude Code capabilities, prior art) that directly informs how to build the artifact — do not skip it.

### 2. Check for an existing artifact

Check whether `agents/{name}.md` already exists.

- **Exists:** Read it. This is a differential update — summarize the proposed changes to the user before applying them. Use Edit, not Write.
- **Does not exist:** Write a new file at `agents/{name}.md`.

### 3. Build the agent file

Write (or update) `agents/{name}.md` following the structure below.

**Required frontmatter:**

```yaml
---
name: {agent-name}        # kebab-case — must match filename exactly
description: >
  {One-line purpose with triggering conditions. Include 2-3 <example>
  blocks showing Context, user request, assistant response, and
  commentary. Be specific about when to use AND when not to use.}
skills: [skill-a, ...]    # skills this agent composes (omit if none)
tools: [Read, Write, ...] # only tools the agent actually needs
model: sonnet             # must be explicit — omitting leaves it as `inherit`, which is unpredictable
---
```

**Description with examples:**

```
{What agent does and when to trigger it}. Examples:

<example>
Context: {Situation description}
user: "{What the user says}"
assistant: "{How Claude should respond using this agent}"
<commentary>
{Why this agent is appropriate here}
</commentary>
</example>
```

Include 2–3 examples covering different phrasings and contexts. Add one example of when NOT to use the agent if the triggering conditions are easily confused with something else.

**Body structure:**

Write in second person. The markdown body becomes the agent's entire system prompt. Agents do NOT inherit the Claude Code system prompt, CLAUDE.md, or parent conversation context — the body must be fully self-contained.

Required sections:
1. **Role definition** — "You are the {role} for jim..."
2. **Context** — essential file paths, key locations, tool usage patterns (the agent has no other way to know these)
3. **Core responsibilities** — what the agent does
4. **Process** — ordered steps for handling an invocation
5. **Constraints** — what the agent does NOT do

**Budget:** Agent body ≤ 800 tokens (≈ 150–200 lines of markdown). The `skills` field preloads full skill content at startup — keep the body lean and delegate detail to the skills.

**Writing style:**
- Second-person voice throughout: "You are...", "Read...", "Check..."
- Imperative instructions
- Explain *why* behind constraints
- No personality soup

### 4. Validate

Work through this checklist before presenting the artifact. Fix failures inline and re-validate.

**Frontmatter**
- [ ] `name` present, kebab-case, matches filename exactly — open-standard requirement (agentskills.io)
- [ ] `description` present, includes triggering conditions and at least one `<example>` block
- [ ] `tools` present, follows least privilege — only what the agent actually uses
- [ ] `model` explicitly set — never omit (the Claude Code default `inherit` is unpredictable)

**Structure**
- [ ] Body ≤ 800 tokens
- [ ] Second-person voice throughout ("You are...")
- [ ] Body is fully self-contained — no assumed inherited context
- [ ] All required sections present: role, context, responsibilities, process, constraints

**Anti-patterns — any of these is a failure:**
- [ ] No personality soup ("I am an AI assistant here to help...")
- [ ] No permission creep (Write/Bash for a read-only agent)
- [ ] No instruction shadowing (repeating rules already in WORKFLOW.md)
- [ ] No duplicate logic (same instructions in 3+ agents → extract to a shared skill)

### 5. Present to user

Show the completed artifact. List what was created or changed. Stop and wait for review — do not proceed to the next phase.
