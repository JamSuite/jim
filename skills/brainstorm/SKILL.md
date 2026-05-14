---
name: brainstorm
description: >
  Capture freeform ideation and exploratory thinking to
  docs/brainstorms/{YYYYMMDD}-{topic}.md. Use when the user invokes
  /jim:brainstorm, wants to think through ideas, or explore options without
  committing to a spec. Do not use when the user wants a structured spec
  (/jim:spec) or strategic document (/jim:vision, /jim:roadmap).
agent: pm
argument-hint: "[topic]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)
---

# /jim:brainstorm

Capture freeform ideation and exploratory thinking. No rigid structure — the goal is to think freely, not to produce a spec.

*(The `agent: pm` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Process

### 1. Get the topic

Use `$ARGUMENTS` as the topic for the brainstorm file. If empty, ask: "What do you want to brainstorm about?"

### 2. Read context (light)

Hold these as context for end-of-session routing. Don't discuss them.

SET vision_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`
IF vision_doc != "NOT_FOUND" THEN
  Read vision_doc — hold as context.
ENDIF

SET roadmap_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get roadmap`
IF roadmap_doc != "NOT_FOUND" THEN
  Read roadmap_doc — hold as context.
ENDIF

### 3. Create the brainstorm file

Resolve the brainstorm filename via Bash, substituting the topic from step 1:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path brainstorm <topic>
```

Create the file at the resolved path. Create the brainstorms directory if it doesn't exist.

Write the initial content:

```markdown
# Brainstorm: {Topic}

*{YYYY-MM-DD}*
```

### 4. Listen and capture

This is the core loop. The PM's role is active listener and synthesizer:

- Ask light clarifying questions to flesh out the thinking. Not a full PM interview — just enough to deepen ideas.
- Capture ideas in whatever structure emerges: bullet lists, prose, questions, pros/cons, diagrams.
- Use Edit to append notes to the brainstorm file as the conversation progresses. Iterative appending — not an end-of-session dump. This prevents data loss and keeps the file as the working document.
- Do not push toward a spec. Do not impose frameworks (no RICE, no OST, no JTBD). Let the user think freely.
- Do not critique or evaluate ideas — capture them. Evaluation happens later if the user decides to spec.

### 5. Detect natural ending

When the conversation reaches a natural stopping point — the user says "I think that's it", "thanks", topic exhaustion, or a long pause — move to routing.

### 6. End-of-session routing

Offer to route synthesized ideas into the formal workflow:

> "Want me to route any of these ideas into the formal workflow? I can create a spec (`/jim:spec`), update the vision (`/jim:vision`), add to the roadmap (`/jim:roadmap`), or run a technical investigation (`/jim:research`)."

This is an offer, not a push. If the user says no, close the session.

If the user says yes to a spec, suggest running `/jim:spec` with the brainstorm file as input context (it can be linked via the `origin:` field).
