---
name: spec
description: >
  Create or update a feature, bug, or refactor spec through collaborative
  interview. Use when the user invokes /jim:spec, describes an idea they
  want scoped, reports a bug, or wants to refine an existing spec. Do not
  use for technical planning (/jim:plan) or implementation (/jim:build).
agent: pm
argument-hint: "[idea-or-name]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Skill(jim:spec-check)
---

# /jim:spec

Turn a rough idea into a structured spec (`docs/specs/{group}/{00X}-{name}/spec.md`) through collaborative interview.

*(The `agent: pm` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Process

### 1. Seed the conversation

Use `$ARGUMENTS` as the idea or name hint.

| Input | Behavior |
|-------|----------|
| Empty | Ask the user what they want to scope |
| String | Treat as idea seed — begin interview with it |
| Path to existing spec | Enter differential update mode (step 11) |

### 2. Read strategic context

SET vision_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`
IF vision_doc != "NOT_FOUND" THEN
  Read vision_doc — locked constraint. Do not re-litigate strategic decisions.
ENDIF

SET arch_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`
IF arch_doc != "NOT_FOUND" THEN
  Read arch_doc — locked constraint. Technical invariants are not negotiable.
ENDIF

If either is missing, note it conversationally ("I notice there's no vision doc yet — you might want to create one to anchor future specs") and proceed. Never block on their absence.

Read `references/spec-types.md` for type guidance, anti-patterns, and status lifecycle.

### 3. Check existing specs

List existing specs in every group via !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh glob specs` to identify existing groups and specs.

- If `$ARGUMENTS` matches an existing spec name, ask: "Update the existing spec, or create a new one?"
- Identify the target group. If ambiguous, suggest a noun-based group name or ask.
- Note existing spec IDs in the group — you'll need the next available ID later, but don't assign it yet.

Flag potential cross-spec side effects if the new idea overlaps with existing specs in the same group.

### 4. Detect spec type

Infer from context:
- Descriptions of broken behavior → **bug**
- Descriptions of new capabilities → **feature**
- Descriptions of code quality or structural issues → **refactor**

If ambiguous, ask the user to confirm. Never guess silently.

For bugs specifically, ask if there is an existing debug document to link via `origin:`.

### 5. Gray-area analysis

Analyze the idea against these 6 dimension categories:

1. **Scope boundaries** — What's in, what's out? Where does this end?
2. **Target user** — Who specifically benefits? What role?
3. **Edge cases** — What happens at the boundaries? Error states?
4. **Interaction model** — How does the user interact with this? CLI? UI? API?
5. **Data shape** — What data flows in and out? What's persisted?
6. **Acceptance testability** — How would you prove this works? What's measurable?

Pick the 2-3 most uncertain dimensions. Present each with:
- A brief explanation of why it's uncertain
- 3-4 numbered options that represent plausible interpretations
- An escape hatch: "or describe your own"

Let the user choose which dimension to discuss first. This respects their priorities and avoids feeling like an interrogation.

### 6. Interview loop

Ask 1-3 questions at a time. Never a wall of questions.

**Technique: Recursive drill-down.** Vague statements get follow-ups:
- "Add logging" → "What log level? What destination? What format?"
- "It should be fast" → "What's the current latency? What's the target? Under what load?"

**Technique: Answer-to-slot mapping.** Each question targets a specific template section. Track which slots are filled:
- Problem Statement ← what problem, who's affected
- User Stories ← role, action, benefit
- Acceptance Criteria ← measurable outcomes
- Out of Scope ← explicit exclusions
- Defect Profile ← reproduction steps, actual/expected (bugs)
- Refactor Rationale ← motivation, current/desired state (refactors)

**Technique: Mockup First.** For specs with visible output (UI, CLI output, file format), sketch an ASCII mockup before writing acceptance criteria. This forces concrete thinking and catches misunderstandings early. Skip for purely internal changes.

**Technique: Anti-pattern flags.** If you notice an anti-pattern forming (see `references/spec-types.md`), raise it conversationally:
- "This is getting broad — should we split off the search piece into its own spec?"
- "That criterion sounds hard to test. Can we make it measurable?"

**Technique: The Level-Up Method.** When the user surfaces a technical suggestion (function shape, library, file path, technology preference), do not embed it in an AC:

1. **Intercept** — acknowledge the suggestion.
2. **Ladder Up** — ask "What does this technology enable?" until you reach a functional requirement.
3. **Bifurcate** — write the abstraction into the AC; record the technical proposal as an Implementation Insight in the spec's `## Research & Architecture Handoff` section with the deflection reason (Razor / Delegation / Story-Link / Constraint-Sourcing).

**Technique: Scope-vs-original-ask flagging.** If a candidate AC, User Story, or Implementation Insight appears to extend beyond the user's original ask, raise it conversationally and defer the decision to the user. Scope is the user's call, not yours. (Extends the existing anti-pattern flagging technique by anchoring scope drift to what the user originally asked for.)

**Technique: Strategic alignment.** If VISION.md exists and the idea seems to diverge from it, raise it as a conversation — never as a blocker:
- "I notice the vision focuses on X, but this pulls toward Y. Intentional pivot, or should we scope differently?"

Cap at 3-5 questions per topic area. If a topic area still feels vague after 5 questions, note it as an Open Question and move on.

### 7. Exit condition

The spec is writable when you can meaningfully populate the required template sections for the detected type (see `references/spec-types.md` for per-type required sections).

No confidence scores. No numeric thresholds. The question is structural: "Can I fill the template?"

### 8. Generate spec.md

Now assign the ID. Run via Bash, substituting the target group:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh next-id <group>
```

The script returns the next zero-padded 3-digit ID (max existing + 1, or `001` if the group is empty). Gaps in the sequence are not reclaimed.

Read `assets/spec-template.md`. Generate the spec:

- Include only the sections relevant to the detected type. Strip type-conditional markers for other types.
- Remove the `<!-- ... only -->` / `<!-- end ... only -->` comment markers from the kept sections.
- Populate `origin:` if source documents were referenced. Otherwise, remove the `origin:` field entirely.
- Reference vision/roadmap alignment in the overview if strategic docs exist.
- Fill Open Questions with any unresolved items from the interview.
- For bugs, ensure acceptance criteria includes "Regression test covers the reported scenario."
- For refactors, ensure acceptance criteria includes "Existing tests pass without modification."
- **Research & Architecture Handoff** — conditional. Include the `## Research & Architecture Handoff` section *only* when Implementation Insights were surfaced during the interview via the Level-Up Method (Step 6). Each Insight follows the per-Insight sub-template in `assets/spec-template.md`. If no Insights were collected, strip the section entirely along with its comment marker (same convention as the `<!-- ... only -->` type markers).

Resolve the spec write path:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path spec <group> <id> <name>
```

Write the spec to that path.

### 9. Socratic self-check

Before presenting, invoke `/jim:spec-check` against the just-written spec.md to run the Socratic audit.

1. **Invoke via the Skill tool.** Call `Skill(jim:spec-check)` and pass the resolved spec path as `args`. The called skill's body runs inline in the main thread (per `ARCHITECTURE.md` → Skill Invocation); `$ARGUMENTS` does not auto-forward, so the path must be passed explicitly.
2. **Apply audit outcomes.** The audit returns structured outcomes — items deflected to Handoff (with probe + reason), External Constraints retained (with cited source), orphan ACs flagged, Connextra-failing stories flagged, and a `clean` / `residual` status.
3. **Bounded retry (cap 3).** If the audit reports unresolved issues, re-run the relevant Bifurcate or source-attribution step inline and re-invoke `Skill(jim:spec-check)`. After 3 iterations, residual issues surface conversationally at Step 10.
4. **Existing in-line checks remain.** The 7 anti-patterns from `references/spec-types.md` (Kitchen Sink, Vague Criteria, Solution Masquerading, Empty Out of Scope, Premature Tech, Wrong Type, Over-specification), locked-constraint compatibility with VISION.md / ARCHITECTURE.md, and type-section completeness still apply.

Do not narrate the audit. Apply corrections inline. Surface only the final deflection summary at Step 10.

### 10. Present and stop

Show the draft to the user. Status is `draft`.

Surface the audit outcomes conversationally — only the deflections and why, not the full interrogation:

> "During validation, I moved N items to the Research & Architecture Handoff:
> - 'X' — failed {probe} ({reason})
> - 'Y' — failed {probe} ({reason})
> Source-attributed: 'Z' — kept as External Constraint, sourced to {source}."

These are your recommendations — the user has **final authority** over classifications, deflections, and source attributions. Offer to revert any deflection or override any classification before asking for approval.

Ask: "Want to change anything, or should I mark this as approved?"

- If the user requests changes → return to the interview loop (step 6) or edit directly.
- If the user approves → set `status: approved` in the frontmatter. Use Edit, not Write.

Never auto-approve. Never set `approved` without explicit human confirmation.

### 11. Differential update path

If `$ARGUMENTS` points to an existing spec, or if step 3 identified a name collision and the user chose to update:

1. Read the existing spec fully.
2. Summarize proposed changes organized by section — what's added, changed, or removed.
3. Ask: "Update in place, or create a new increment?"
4. If updating: use Edit, not Write. Preserve sections the user didn't ask to change.
5. If creating new: follow the normal generation path (step 8) with a new ID.

## Validation Checklist

Before presenting any generated spec, verify:

**Frontmatter**
- [ ] `title` present and descriptive
- [ ] `type` is one of: feature, bug, refactor
- [ ] `group` is noun-based, lowercase
- [ ] `id` is 3-digit zero-padded, sequential within group
- [ ] `status` is `draft`
- [ ] `origin` present only if source documents exist (removed otherwise)

**Content**
- [ ] Only type-relevant sections included (no feature sections in bug specs)
- [ ] Acceptance criteria are specific and testable (no "works well")
- [ ] Out of Scope has at least one exclusion
- [ ] Overview is 1-2 sentences max
- [ ] Bug specs include "Regression test covers the reported scenario"
- [ ] Refactor specs include "Existing tests pass without modification"

**Anti-patterns (any = failure)**
- [ ] No Kitchen Sink (spec has one clear problem)
- [ ] No Vague Criteria (all criteria are measurable)
- [ ] No Solution Masquerading (describes problem, not solution)
- [ ] No Empty Out of Scope
- [ ] No Premature Tech (no DB schemas, API endpoints, library choices)
- [ ] No Wrong Type (sections match the declared type)
- [ ] No Over-specification (ACs are user-observable; type-aware calibration applied per `references/spec-types.md` #7)

**Socratic DoD outcomes**
- [ ] `## Research & Architecture Handoff` section is present iff Implementation Insights were collected during interview
- [ ] Every AC has been Three-Tier classified (Functional / External Constraint / Implementation Detail) by `/jim:spec-check`
- [ ] Every External Constraint cites a source from the Allowed Source list
