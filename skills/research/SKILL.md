---
name: research
description: >
  Investigate codebase, external docs, and technical landscape to produce
  a grounded research.md. Use when the user invokes /jim:research, when
  exploring feasibility before a spec, or when gathering context for planning.
  Do not use for design decisions (/jim:plan), implementation (/jim:build),
  or spec creation (/jim:spec).
agent: researcher
argument-hint: "[spec-path | brainstorm-path | directory | topic]"
allowed-tools: Bash(bash *)
---

# /jim:research

Investigate codebase, external docs, and technical landscape to produce a grounded research.md. Local evidence first, external knowledge second, strategic alignment always.

*(The `agent: researcher` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Process

### 1. Route input

Use `$ARGUMENTS` to determine the research target and mode:

| Input | Behavior |
|-------|----------|
| Empty | Ask: "What do you want to research? You can give me a spec path, brainstorm, directory, or topic." |
| Path ending in `spec.md` | Spec-linked research: read the spec, infer type (feature/bug/refactor). Output goes to the same directory. |
| Path ending in `.md` | Read the file, infer context (brainstorm, debug doc, etc.). Suggest an output location. |
| Directory path | Check for README.md or spec.md in the directory first for context, then scan. Suggest output location. |
| String | Treat as topic for exploratory research. Suggest output location. |

### 2. Determine output location

- **Spec path input:** Resolve the research write path (same directory as the spec):

      bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path research <group> <id> <name>

  Write the research to that path.
- **Everything else:** Suggest a location and confirm with the user before writing:
  - If a related spec exists, suggest its directory.
  - Otherwise suggest `docs/research/{YYYYMMDD}-{topic}.md`.

### 3. Check for existing research

If research.md already exists at the target path, this is a differential update:

1. Read the existing research.md.
2. Summarize its current state to the user.
3. Ask: "Want me to update the existing research, or start fresh?"
4. If updating, use Edit to preserve sections the user didn't ask to change.

### 4. Phase 0 — Local Archaeology

Default phase. Run before any web research.

**Greenfield check first:** Glob the target directory/group for source files. If the directory is empty (only docs), or Grep for the research topic returns zero hits across the codebase:
- Produce a brief "greenfield — no local codebase to scan" note.
- Include the audit trail of patterns attempted (e.g., `glob **/auth/**`, `grep "auth"`).
- Skip to Phase 1.

**Delegate bulk scanning to Agent(Explore):** Dispatch an Explore subagent with a focused prompt covering the specific files, patterns, and terms to search for. The Explore agent runs on haiku for cost efficiency — keep the prompt targeted.

**Synthesize findings from Explore results:**
- Anchor file paths with line ranges (implementation + test locations)
- At least one existing test file as template for the coder (framework, setup, mocks)
- Local patterns, utilities, and conventions
- Existing specs in the same group

**Adjust focus by spec type:**
- **Feature:** Integration points, existing patterns, conventions to follow.
- **Bug:** Trace reproduction through codebase, identify fault location, check related bugs in group.
- **Refactor:** Map current state, document all callers/consumers.

### 5. Phase 1 — External Intelligence

Conditional phase. Triggered only after Phase 0 completes.

**Skip when:**
- Phase 0 found sufficient local context AND the spec is a bug or refactor with no external dependencies.
- The spec doesn't reference external APIs, libraries, or examples.

**When triggered:**
- Search for prior art, library comparisons, external API docs.
- Follow WebFetch guardrails: only when the spec references external examples, APIs, or knowledge bases, or code contains TODOs mentioning third-party migrations.
- **WebFetch guardrail:** If a WebFetch or WebSearch call fails or returns a rate-limit error (429), stop immediately and ask the user to fetch that URL manually. Do not continue the task with missing data. Do not defer the ask to the end of the task. The user will paste the content and you can resume.
- **Library analysis:** Compare requested libraries against the project's dependency files (package.json, go.mod, requirements.txt, etc.) to prevent library sprawl.
- **20-line rule:** Link, don't paste. URL + key constraints, not full code blocks.
- **Prior art file table:** For each prior art entry, include a file-level table (File | What It Is | Why It Matters) when the repo is accessible (best-effort).
- **Prior art tiering:** When 5+ prior art entries exist, organize into Tier 1 (Study Closely) / Tier 2 (Study for Specific Patterns) / Tier 3 (Reference Only). Under 5, use a flat list.

### 6. Phase 2 — Alignment Validation

Mandatory phase — always runs.

1. Read strategic constraints, if present:

   IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`) EXISTS THEN
     READ FILE — locked constraint.
   END IF

   IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`) EXISTS THEN
     READ FILE — locked constraint.
   END IF
2. Produce an explicit alignment statement: "This approach aligns with [strategic goal] and follows the [architectural pattern]" — or flag divergence conversationally.
3. If strategic docs are missing, note their absence. Don't block on it.
4. If research recommendations contradict a locked constraint, raise it as a Peer Feedback item for the PM.

### 7. Check for plan invalidation

If a plan.md exists in the same spec directory:
- Compare research findings against plan assumptions.
- If findings would invalidate plan sections, add to Peer Feedback: which plan sections may need revision and why.

### 8. Generate research.md

1. Read `assets/research-template.md` for the output structure.
2. Fill sections based on phase results.
3. Include conditional sections (Prior Art, Libraries, Peer Feedback) only when they have content. Remove empty conditional sections.
4. Set frontmatter `spec:` to the relative path of the source spec, or `"standalone"` for non-spec research.
5. Set frontmatter `status:`:
   - `Active` — no upstream concerns.
   - `Needs PM Review` — Peer Feedback contains spec feasibility signals.
   - `Needs Architect Review` — Peer Feedback contains plan invalidation signals.

### 9. Self-check

Before presenting, read `references/research-dod.md` and validate the research against every applicable checklist item. Fix any gaps before proceeding. This is the same checklist used by `research:check`.

### 10. Present and stop

Show the research.md to the user. If a Peer Feedback section exists, surface the key signals conversationally:

> "Heads up: I found [concern] that may affect [spec/plan]. You may want to review before proceeding."

Ask for approval. Write the file (Write for new, Edit for updates). Do not proceed to the next phase unprompted.
