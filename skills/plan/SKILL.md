---
name: plan
description: >
  Produce or update an implementation plan (plan.md) from an approved spec.
  Use when the user invokes /jim:plan, when an approved spec needs a technical
  plan before implementation begins, or when an existing plan needs updating
  after spec changes. Do not use for spec creation (/jim:spec), research
  (/jim:research), or code implementation (/jim:build).
agent: architect
argument-hint: "[spec-path]"
allowed-tools: Bash(bash *)
---

# /jim:plan

Produce a complete, coder-ready implementation plan from an approved spec. Research is gathered automatically if missing.

## Argument Routing

Use `$ARGUMENTS` to determine the spec path:

| Input | Behavior |
| :--- | :--- |
| Empty | Ask: "Which spec should I plan? Provide the path to a spec.md." |
| Path ending in `spec.md` | Use as the target spec |
| Directory path | Look for `spec.md` inside it |

## Process

### 1. Read and gate the spec

Read the spec at the provided path. Check frontmatter `status:`.

- `status: draft` — Stop. Tell the user: "This spec is still in draft. Approve it first, then re-run /jim:plan."
- `status: approved` — Continue.

Note the spec's `type` (feature, bug, refactor), `title`, `id`, and `group` for later.

### 2. Handle research

Check for `research.md` in the same directory as the spec.

**Missing:** Auto-spawn `@jim:researcher` via the Agent tool, passing the spec path. Wait for research to complete, then read the resulting research.md and continue.

**Exists — check for staleness:** Compare the `date:` field in research.md frontmatter to the spec. If the spec has been updated since research was gathered, tell the user: "Research may be stale — the spec was modified after research was completed. Re-research now, or proceed with existing findings?" Wait for the user's decision before continuing.

**Current:** Read research.md fully. Note all anchors, integration points, constraints, and Peer Feedback signals.

**Peer Feedback in research:** If research.md contains a Peer Feedback section with plan invalidation signals, address each one explicitly in the plan — accept, reject with rationale, or flag for the user to decide.

### 3. Check the architecture doc

READ_IF_EXISTS !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture` — treat every architectural invariant as a locked constraint. No design decision may violate these without explicit user approval.

If absent, note this in the Constitution Check section of the plan. Proceed without constraints.

### 4. Check for an existing plan

Look for `plan.md` in the same directory as the spec.

- **Exists:** This is a differential update. Read the existing plan fully. Summarize proposed changes to the user — what sections will change, what will be preserved — before writing anything. Use Edit, not Write.
- **Missing:** Generate a new plan from `assets/plan-template.md`.

### 5. Design

Read `assets/plan-template.md` before designing. Follow its structure.

**Design decisions first.** For every non-obvious choice, write a Chosen/Why/Rejected block. If a choice was obvious, still document it briefly — the coder has no context you don't give them.

**Type-specific approach:**

- **Feature:** Standard dependency-ordered task breakdown.
- **Bug:** Structure tasks as: (1) Reproduce — a task that verifies the bug is reproducible with a shell command; (2) Fix — the code change; (3) Regression — a task that verifies the fix and prevents recurrence.
- **Refactor:** Front-load structural changes. Every task ends with a Verify command that confirms existing tests still pass.

**Spec gaps:** If designing reveals that a spec requirement is technically underspecified or infeasible, flag it conversationally before continuing: "I found an issue with AC [X] — [what's wrong]. Should I [option A] or [option B], or would you prefer to update the spec first?" The human decides.

**Research gaps:** If the research lacks integration anchors needed for a key design decision, note it explicitly in Open Questions and mark the related task as `[NEEDS CLARIFICATION]`. You may also re-invoke the researcher for targeted follow-up if the gap is blocking.

### 6. Write the plan

Populate all sections from the template:

1. **Frontmatter** — `spec:` (relative path), `type:` (from spec), `status: draft`
2. **Overview** — 1-2 sentences on the technical approach
3. **Design Decisions** — Chosen/Why/Rejected for every non-obvious choice
4. **Constitution Check** — ARCHITECTURE.md constraints listed and confirmed honored, or absence noted
5. **File Manifest** — every file to be created or modified, with exact paths
6. **Interface Contracts** — types, interfaces, API shapes — defined before tasks
7. **Data Flow** — Mermaid diagram for non-trivial flows; sequence diagram for multi-agent interactions
8. **Task Breakdown** — atomic tasks in dependency order, each with `**Verify:**` shell command
9. **Requirements Coverage Summary** — every spec AC mapped to at least one task; ambiguous ACs marked `[NEEDS CLARIFICATION]`
10. **Out of Scope** — explicit deferrals
11. **Open Questions** — unresolved items

Resolve the plan write path:

    bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path plan <group> <id> <name>

Write the plan to that path. Status stays `draft`.

### 7. Self-check

Before presenting, read `references/plan-dod.md` and validate the plan against every checklist item. Fix any failures inline. Do not present a plan that fails the DoD.

### 8. Present and stop

Show the completed plan. Summarize what was created or changed. If any `[NEEDS CLARIFICATION]` markers exist, surface them explicitly:

> "There are [N] open clarification items I flagged — see the Requirements Coverage Summary. Resolve these before handing the plan to the coder."

Status stays `draft` until the user explicitly approves. Ask: "Any changes, or should I mark this approved?"

Do not proceed to the next phase.

## Validation Checklist

Before presenting, confirm:

- [ ] Spec was `status: approved` before planning began
- [ ] research.md was read (or researcher was spawned and completed)
- [ ] ARCHITECTURE.md was checked (present or absence noted)
- [ ] File manifest lists every file that will be created or modified
- [ ] Interface contracts are defined before the task breakdown
- [ ] Every task has a shell-executable `**Verify:**` command
- [ ] Requirements Coverage Summary covers every spec AC
- [ ] plan-dod.md checklist passed
- [ ] `status: draft` in frontmatter
- [ ] Differential update used Edit, not Write
