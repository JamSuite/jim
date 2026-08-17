---
spec: "docs/specs/sdlc/005-architect/spec.md"
status: Active
date: "2026-03-14"
---

# Research: Architect Agent — Prior Art Survey

## Anchors

- `docs/specs/sdlc/005-architect/spec.md:1-150`: Source spec defining `@jim:architect`, `/jim:plan`, and `/jim:arch`.
- `WORKFLOW.md:15-30`: The SDLC feedback loop — `/jim:plan` sits between `/jim:spec` and `/jim:build`, enforcing no ghost tasks.
- `agents/architect.md`: Empty — agent definition not yet created.
- `skills/plan/` and `skills/arch/`: Empty directories — skills not yet created.
- `ARCHITECTURE.md`: Empty — target output of `/jim:arch`, treated as locked constraint by `/jim:plan`.

## Local Patterns

- **Human-in-the-loop**: Agents STOP at phase gates; autonomous multi-phase execution is prohibited.
- **Differential updates**: Artifacts are living documents refined via Edit, not overwritten via Write.
- **Upstream constraints**: VISION.md and ARCHITECTURE.md are always read as locked constraints when they exist.
- **Feedback loops**: Any downstream phase (plan, build) can send you back upstream (spec, plan). The architect flags spec gaps conversationally — the PM decides.
- **Test template**: Not applicable — this is architectural research, not implementation code.

## Prior Art

### Tier 1: Study Closely

**1. GitHub Spec Kit**
- **Repo**: [github/spec-kit](https://github.com/github/spec-kit)
- **Relevant to**: `/jim:plan`, `/jim:arch`, `ARCHITECTURE.md`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`templates/plan-template.md`](https://github.com/github/spec-kit/blob/main/templates/plan-template.md) | Implementation plan template with Constitution Check gates, Complexity Tracking table, and `[NEEDS CLARIFICATION]` markers | Directly applicable to `/jim:plan` template design. The Constitution Check gate pattern maps to Jim's ARCHITECTURE.md-as-constraint model. Complexity Tracking table (Violation / Why Needed / Simpler Alternative Rejected) is a concrete format Jim should adopt. |
| [`templates/constitution-template.md`](https://github.com/github/spec-kit/blob/main/templates/constitution-template.md) | Project principles template — 5 core principles with governance and amendment process | Validates Jim's approach of treating ARCHITECTURE.md as immutable constraints. The amendment process pattern (rationale + review + backwards-compat assessment) is useful for `/jim:arch` updates. |
| [`spec-driven.md`](https://github.com/github/spec-kit/blob/main/spec-driven.md) | SDD methodology manifesto — specs as source of truth, code as generated output | Articulates the philosophy Jim implements: "Specifications don't serve code — code serves specifications." The `/speckit.plan` → `/speckit.tasks` flow validates Jim's `/jim:plan` → `/jim:build` separation. |

**Key takeaways for Jim:**
- **Constitution gates before planning**: Spec Kit runs a "Phase -1: Pre-Implementation Gates" check against project principles before the architect begins design work. Jim should check ARCHITECTURE.md constraints before task breakdown.
- **Explicit uncertainty markers**: `[NEEDS CLARIFICATION]` in plan output forces the architect to surface ambiguity rather than guess. Maps directly to Jim's spec feedback loop.
- **Complexity Tracking table**: A concrete format for documenting when the architect intentionally deviates from simplicity — why it's needed and what simpler alternative was rejected.
- **Three-command pipeline**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` validates Jim's `/jim:spec` → `/jim:plan` → `/jim:build` separation as the emerging SDD standard.

**2. Pimzino Spec Workflow**
- **Repo**: [Pimzino/claude-code-spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow)
- **Relevant to**: `/jim:plan`, `/jim:build`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`.claude/commands/spec-create.md`](https://github.com/Pimzino/claude-code-spec-workflow/blob/main/.claude/commands/spec-create.md) | Four-phase workflow: Requirements → Design → Tasks → Command Generation, with validator agents at each gate | Validates Jim's separation of spec/plan/build. Key pattern: validator agents run at each phase gate before user presentation. Jim could add a self-check step to `/jim:plan` before presenting. |
| [`.claude/commands/spec-execute.md`](https://github.com/Pimzino/claude-code-spec-workflow/blob/main/.claude/commands/spec-execute.md) | One-task-at-a-time execution with mandatory task checkbox marking in tasks.md | Reinforces Jim's atomic task model. The "mark task [x] in tasks.md" pattern and "NEVER automatically proceed to next task" rule mirror Jim's no-ghost-tasks constraint. |
| [`.claude/steering/structure.md`](https://github.com/Pimzino/claude-code-spec-workflow/blob/main/.claude/steering/structure.md) | Steering document defining module boundaries, naming conventions, file size limits (<300 lines) | The "steering document" pattern — persistent project context that constrains all phases — maps to Jim's ARCHITECTURE.md and VISION.md as locked constraints. |

**Key takeaways for Jim:**
- **Validator agents at phase gates**: Pimzino runs `spec-design-validator` before presenting design output. Jim's `/jim:plan` should self-validate against `plan-dod.md` before presenting to the user.
- **Steering documents as persistent context**: The `steering/` directory pattern (product.md, tech.md, structure.md) validates Jim's approach of reading VISION.md and ARCHITECTURE.md as upstream constraints.
- **Atomic task execution**: "ONLY execute one task at a time" + "NEVER automatically proceed" — the same discipline Jim's coder skill enforces.

**3. zhsama/claude-sub-agent**
- **Repo**: [zhsama/claude-sub-agent](https://github.com/zhsama/claude-sub-agent)
- **Relevant to**: `@jim:architect`, `/jim:plan`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`agents/spec-agents/spec-architect.md`](https://github.com/zhsama/claude-sub-agent/tree/main/agents/spec-agents) | Dedicated architect agent that transforms requirements into system design, API specs, and technical approach | Validates Jim's three-agent planning pipeline (analyst → architect → planner). Key insight: the architect is a bridge between analysis and planning, not a standalone role. |
| [`agents/spec-agents/spec-planner.md`](https://github.com/zhsama/claude-sub-agent/tree/main/agents/spec-agents) | Planner agent that breaks architecture into actionable tasks with test strategies | Confirms Jim's decision to combine architect + planner into one `@jim:architect` agent with `/jim:plan` — having separate architect and planner agents adds overhead without clear benefit for Jim's scale. |

**Key takeaways for Jim:**
- **Quality gates with percentage thresholds**: Planning phase uses 95% completeness threshold before passing to development. Jim's approach of human approval is better aligned with its "not a black box" non-goal, but the checklist-driven self-check is worth adopting.
- **Three-phase pipeline validates Jim's model**: analyst (PM) → architect → planner → developer (coder) maps directly to Jim's `/jim:spec` → `/jim:plan` → `/jim:build`.

### Tier 2: Study for Specific Patterns

**4. SuperClaude Framework**
- **Repo**: [SuperClaude-Org/SuperClaude_Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework)
- **Relevant to**: `@jim:architect`, `/jim:plan`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`PLANNING.md`](https://github.com/SuperClaude-Org/SuperClaude_Framework/blob/master/PLANNING.md) *(branch `main`→`master`, 2026-07-17)* | Architecture doc with Confidence-First Implementation (>=90% proceed, 70-89% investigate, <70% stop) and Wave→Checkpoint→Wave parallel execution | The confidence gate pattern is directly applicable. Jim's architect should assess confidence before proceeding with design decisions — if < 70%, stop and present alternatives. |
| [`skills/confidence-check/`](https://github.com/SuperClaude-Org/SuperClaude_Framework/tree/master/skills/confidence-check) *(branch `main`→`master`, 2026-07-17; dir holds `SKILL.md` + `confidence.ts`)* | Runtime skill for pre-execution confidence assessment | Validates the pattern but SuperClaude's implementation (Python pytest plugin) is infrastructure Jim doesn't need. The concept — spend 100-200 tokens on confidence check to save 5,000-50,000 on wrong direction — is the key insight. |

**Key takeaways for Jim:**
- **Confidence gates**: The ROI argument is compelling — small investment in confidence assessment prevents expensive rework. Jim's architect should flag low-confidence design decisions explicitly.
- **SelfCheckProtocol's "Four Questions"**: (1) Are all tests passing? (2) Are all requirements met? (3) No assumptions without verification? (4) Is there evidence? — adaptable as a plan self-check.
- **Seven Red Flags**: "Tests pass" without output, "Everything works" without evidence, etc. — useful anti-patterns for the architect to avoid when presenting plans.

**5. VoltAgent Awesome Claude Code Subagents**
- **Repo**: [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- **Relevant to**: `@jim:architect` agent definition

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`categories/04-quality-security/architect-reviewer.md`](https://github.com/VoltAgent/awesome-claude-code-subagents/blob/main/categories/04-quality-security/architect-reviewer.md) | Architecture review agent with systematic checklists and structured delivery notifications | Useful patterns: delivery notification summarizing key decisions and trade-offs; ADR format (context, decision, consequences, alternatives) validates Jim's Chosen/Why/Rejected structure. |

**Key takeaways for Jim:**
- **Structured delivery notification**: "Architecture plan completed. Designed approach supporting X with Y tradeoffs." — Jim's architect should present plans with a concise summary.
- **Red flags checklist** (from [ecc/agents/architect.md](https://github.com/affaan-m/ecc/blob/main/agents/architect.md) — repo renamed `everything-claude-code`→`ecc` (same repo id, ~230k★); file still present though its top now leads with a "Prompt Defense Baseline" preamble, 2026-07-17): Unclear structure, solution monotheism, premature optimization, tight coupling, undocumented magical behavior — anti-patterns the architect should flag during planning.

### Tier 3: Reference Only

**6. GSD & cc-sdd**
- **Repos**: [open-gsd/gsd-core](https://github.com/open-gsd/gsd-core) *(formerly `gsd-build/get-shit-done`; branch `next`)*, [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
- **Relevant to**: `/jim:plan`, `/jim:arch`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`commands/gsd/plan-phase.md`](https://github.com/open-gsd/gsd-core/blob/next/commands/gsd/plan-phase.md) | Planning command with conditional research spawning and cheap-iteration flags (`--view` / `--skip-research`) for targeted re-planning | Validates `/jim:plan`'s auto-spawn-researcher pattern. Gap closure mode (skip research, target specific gaps) is relevant to the architect's differential update workflow. |
| [`commands/gsd/map-codebase.md`](https://github.com/open-gsd/gsd-core/tree/next/commands/gsd) *(path may have shifted in the `open-gsd/gsd-core` move — verify against the current tree)* | Four parallel agents (Tech, Architecture, Quality, Concerns) produce structured codebase docs | Directly relevant to `/jim:arch` — the architect could spawn focused sub-agents to analyze different codebase dimensions simultaneously when generating ARCHITECTURE.md. |
| [`.kiro/specs/photo-albums-en/design.md`](https://github.com/gotalab/cc-sdd/blob/main/.kiro/specs/photo-albums-en/design.md) | Design doc with interfaces, pre/postconditions, and cross-cutting concerns | Concrete example of plan.md-quality output. The pre/postcondition pattern on interface contracts is directly adoptable by the architect's Interface Contracts section. |
| [`.kiro/specs/photo-albums-en/tasks.md`](https://github.com/gotalab/cc-sdd/blob/main/.kiro/specs/photo-albums-en/tasks.md) | Task breakdown with Requirements Coverage Summary tracing tasks to requirements | The traceability matrix (requirement → task mapping) ensures completeness — if a spec requirement has no task, the plan is incomplete. Directly useful for the architect's self-check. |

**Key takeaways for Jim:**
- **Requirements Coverage Summary**: A traceability section the architect can add to plan.md, mapping spec acceptance criteria to tasks.
- **Parallel codebase analysis for `/jim:arch`**: GSD's four-agent mapping pattern shows how the architect could decompose ARCHITECTURE.md generation into parallel focused scans.

## Security & Performance

- **Security in plans, not deferred to coder**: When the architect generates plan.md, it must explicitly define security boundaries and data validation steps. Relying on the coder to infer security measures from the spec is an anti-pattern (Spec Kit's "Security-First" constitution example). This constraint should be codified in `plan-dod.md` as a checklist item.
- **Context window cost**: The architect must cite relevant ARCHITECTURE.md lines rather than duplicating entire files into plan.md. Pimzino notes 60-80% token reduction with hierarchical context caching.
- **File manifest validation**: When the architect generates file manifests with exact paths, a confused spec could direct writes to sensitive locations. The architect's SKILL.md should include a check that all manifest paths fall within the project directory — bake this into `plan-dod.md` so it's an automated gate, not a mental note.

## Recommendations

All surveyed frameworks confirm Jim's spec→plan→build pipeline as the emerging SDD standard. Jim's conversational approval gates align with the "not a black box" non-goal (VISION.md), and Jim's differential update model (Edit, not Write) is more sophisticated than most frameworks which use full regeneration. ARCHITECTURE.md is empty — `/jim:arch` should populate it as one of its first uses.

1. **Adopt Constitution Check pattern from Spec Kit**: Before task breakdown, the architect should verify the design against ARCHITECTURE.md constraints using a gate checklist. If constraints are violated, document in a Complexity Tracking table (Violation / Why Needed / Simpler Alternative Rejected).

2. **Implement confidence signaling from SuperClaude**: When the architect has low confidence in a design decision (incomplete research, ambiguous spec), flag it explicitly with `[NEEDS CLARIFICATION]` markers rather than guessing. The plan should note confidence level on critical decisions.

3. **Add self-check before presentation**: Borrow Pimzino's validator-at-each-gate pattern. Before presenting plan.md to the user, the architect should validate against `plan-dod.md` and fix gaps.

4. **Include Requirements Coverage Summary from cc-sdd**: Add a traceability section to plan.md showing which spec acceptance criteria each task addresses. Gaps indicate incomplete planning.

5. **Structured delivery summary**: When presenting the plan, lead with a concise summary of key decisions and trade-offs (as modeled by VoltAgent's delivery notification pattern).

## Peer Feedback

- **For Architect**: The existing `research2.md` recommended "Confidence Score" and "Approval Breakpoint" additions to `/jim:plan` output. This deeper survey reinforces that recommendation — Spec Kit's `[NEEDS CLARIFICATION]` markers and SuperClaude's confidence gates are concrete implementations of the same idea. The plan template should include both.
- **For Architect**: Consider adopting Spec Kit's Complexity Tracking table (Violation / Why Needed / Simpler Alternative Rejected) in the plan template. It provides accountability for intentional complexity.
- **For PM**: cc-sdd's Requirements Coverage Summary (tracing tasks back to spec requirements) could be added to the plan template as a traceability aid. This would strengthen the feedback loop between plan and spec.
