---
spec: "006-coder/spec.md"
status: Active
date: "2026-03-16"
---

# Research: Coder Agent and Skills

## Anchors

- `docs/prior-art/V1SDLC/v1-agent-coder.md:1-46`: V1 coder agent — establishes the core TDD loop, type-specific behavior (feature/bug/refactor), and stop-on-failure constraint that `@jim:coder` must preserve.
- `docs/prior-art/V1SDLC/v1-coder-skill.md:1-56`: V1 coder skill — TDD cycle, implementation gears (obvious/fake-it/triangulate), Tidy First commit separation. Direct ancestor of `skills/build/references/tdd-guide.md`.
- `WORKFLOW.md:57`: Defines `/jim:build` as "TDD red-green-refactor + commit per task" with output "Tests + code". Confirms the coder routes failures back upstream.
- `agents/coder.md:1-46`: Existing V1-style agent definition already in place. The 006 spec evolves this with skills frontmatter, examples, and debug support.
- `skills/research/SKILL.md`, `skills/plan/SKILL.md`: Existing skills as structural templates for `skills/build/SKILL.md` and `skills/debug/SKILL.md`.

## Local Patterns

- **Greenfield for build/debug skills:** `glob skills/build/**` and `glob skills/debug/**` return no results. These are new skill directories.
- **Agent pattern:** All existing agents (`pm.md`, `architect.md`, `researcher.md`, `meta.md`) follow the same frontmatter format: `name`, `description`, `tools`, `model`, optional `skills`. Body is a self-contained system prompt under ~800 tokens.
- **Skill pattern:** All existing skills use `SKILL.md` with frontmatter (`name`, `description`, `agent`), a process section with numbered steps, and optional `assets/` and `references/` subdirectories.
- **Test template:** No automated tests exist for agent/skill execution. The project validates through manual invocation and `pre-commit.sh`.

## Prior Art

### Tier 1: Study Closely

#### Augmented Coding: Beyond the Vibes (Kent Beck)
**Source**: [newsletter.kentbeck.com](https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes) *(Kent Beck moved off Substack; `tidyfirst.substack.com` now 301-redirects here — content unchanged, free to read, 2026-07-17)*
**Relevant to**: `/jim:build`, `@jim:coder` agent definition

| Concept | What It Is | Why It Matters for Jim |
|---------|------------|------------------------|
| Red-Green-Refactor with AI | Strict TDD cycle enforced via system prompt — AI writes failing test, minimum code, then refactors | Direct validation of Jim's core loop. Beck's production use (B+ tree in Rust/Python) proves the model works at scale. |
| Structural vs behavioral separation | Commits must never mix refactoring with new behavior | Exact match for Jim's Tidy First commitment discipline. |
| Three warning signs | Excessive loops, unrequested functionality, test manipulation/deletion | Jim's failure handling should detect these: test passing on Red = warning sign #3; scope creep = warning sign #2. |

**Key takeaways for Jim:**
- Beck's "augmented coding" philosophy is the theoretical foundation Jim implements. The coder agent IS Beck's vision operationalized.
- The "three warning signs" map directly to Jim's stop conditions: test passes on Red (test manipulation), scope creep (unrequested functionality).
- Separation of structural/behavioral changes across commits is non-negotiable — Beck confirms this from production experience.

#### Forcing Claude Code to TDD (alexop.dev)
**Source**: [alexop.dev](https://alexop.dev/posts/custom-tdd-workflow-claude-code-vue/)
**Relevant to**: `/jim:build` TDD loop, `@jim:coder` agent architecture

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| `.claude/skills/tdd-integration/skill.md` | TDD skill with explicit phase gates | Proves "Do NOT proceed to Green phase until test failure is confirmed" language works to enforce strict TDD in Claude Code. |
| `.claude/hooks/user-prompt-skill-eval.ts` | UserPromptSubmit hook forcing skill activation | Demonstrates that skills only activate ~20% without hooks; hooks raise it to ~84%. |

**Key takeaways for Jim:**
- **Context isolation is critical**: Separate subagents for Red/Green/Refactor prevent the test writer from seeing implementation plans — tests reflect requirements, not anticipated code. Jim's `@jim:coder` runs as a subagent already, providing this isolation.
- **Explicit phase gates**: "Do NOT proceed until..." language in skill definitions is the enforcement mechanism. Jim's build skill should use identical gating.
- **Hook-based activation**: Skills without hooks activate inconsistently. Jim may need to consider hooks for `/jim:build` activation reliability in future iterations.

#### Get Shit Done (GSD)
**Repo**: [github.com/open-gsd/gsd-core](https://github.com/open-gsd/gsd-core) *(formerly `gsd-build/get-shit-done`, archived 2026-06-26; default branch now `next`)*
**Relevant to**: `/jim:build`, `/jim:debug`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`commands/gsd/execute-phase.md`](https://github.com/open-gsd/gsd-core/blob/next/commands/gsd/execute-phase.md) (local: `docs/prior-art/github.com/gsd/execute-phase.md`) | Wave-based parallel execution orchestrator | Shows lean orchestrator pattern: discover plans → analyze dependencies → group into waves → spawn subagents → collect results. Source states a "thin orchestrator, fresh full subagent" doctrine *qualitatively* — the earlier "~15% / 100%" figures were not in the source and are removed (re-verified 2026-07-17). |
| `agents/gsd-executor.md` | Primary implementation agent | Dedicated executor agent separate from planner/verifier — same separation Jim uses. |
| `agents/gsd-debugger.md` | Error diagnosis agent | Direct parallel to `/jim:debug` — separate diagnosis from fixing. |
| `agents/gsd-verifier.md` | Post-implementation verification | Maps to Jim's Verify step and `./pre-commit.sh` gate. |

**Key takeaways for Jim:**
- **Fresh context per subagent** (100% token budget) prevents context rot during long TDD loops. Jim's coder already runs as a subagent, gaining this benefit.
- **Atomic commits with phase identifiers** (e.g., `feat(08-02): ...`) — Jim should adopt similar traceability in commit prefixes.
- **XML-structured task definitions** with `<action>`, `<verify>`, `<done>` sections give precise instruction boundaries. Jim's plan.md task format with `**Verify:**` commands serves the same purpose.

### Tier 2: Study for Specific Patterns

#### Spec Kit (GitHub)
**Repo**: [github.com/github/spec-kit](https://github.com/github/spec-kit)
**Relevant to**: `/jim:build`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`templates/commands/implement.md`](https://github.com/github/spec-kit/blob/main/templates/commands/implement.md) *(moved from `extensions/claude-code/commands/speckit.implement.md`, which 404s as of 2026-07-17)* (local: `docs/prior-art/github.com/spec-kit/implement.md`) | Task execution command with checklist gates, phase-by-phase execution, and progress tracking | Demonstrates: pre-execution checklist validation, TDD ordering (tests before code), halt on non-parallel task failure, marking tasks `[X]` on completion. |

**Key takeaways for Jim:**
- **Checklist gate before execution**: spec-kit checks prerequisite checklists and STOPs if incomplete — Jim should similarly reject `status: draft` plans.
- **Phase-by-phase with halt-on-failure**: Non-parallel tasks halt execution on failure, parallel tasks continue — Jim uses sequential-only, so halt-on-failure is the right default.
- **Extension hooks** (before/after implement): spec-kit supports pre/post hooks for implementation. Jim's `./pre-commit.sh` gate is a simpler version of the same pattern.

#### cc-sdd
**Repo**: [github.com/gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
**Relevant to**: `/jim:build`, `/jim:plan`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| [`docs/guides/claude-subagents.md`](https://github.com/gotalab/cc-sdd/blob/main/docs/guides/claude-subagents.md) (local: `docs/prior-art/github.com/cc-sdd/claude-subagents.md`) | Subagent orchestration guide for spec workflow | Shows phase-based subagent orchestration: init → requirements → design → tasks, with interactive (stop-after-each-phase) and automatic modes. |

**Key takeaways for Jim:**
- **Interactive vs automatic modes**: cc-sdd's `spec-quick` supports both — Jim's `/jim:build` is always interactive (stop-and-escalate on failure), which is the right default for TDD discipline.
- **Validation gates deliberately skipped in quick mode**: cc-sdd notes that validation is manual. Jim's approach of mandatory verification per task is stricter and better for TDD.

#### Claude Code Spec Workflow (Pimzino)
**Repo**: [github.com/Pimzino/claude-code-spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow)
**Relevant to**: `/jim:debug`, `/jim:build`

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| `.claude/agents/spec-task-executor` | Implements individual spec tasks with full specification context | Context-aware execution achieving "60-80% token reduction" through optimized document sharing. |
| `commands/bug-fix-workflow.md` | Report → Analyze → Fix → Verify bug workflow | Direct template for `/jim:debug`'s structured diagnosis flow. |

**Key takeaways for Jim:**
- **Token reduction through context sharing**: Only pass the specific task + spec context to the executor, not the entire conversation history. Jim's coder already receives focused context via plan.md + spec.md + research.md.
- **Bug-fix workflow structure**: Report → Analyze → Fix → Verify maps cleanly to Jim's `/jim:debug` output structure (error analysis → reproduction → root cause → recommended next step).

### Tier 3: Reference Only

#### SuperClaude Framework
**Repo**: [github.com/SuperClaude-Org/SuperClaude_Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework)
**Relevant to**: `@jim:coder` agent patterns

| File | What It Is | Why It Matters for Jim |
|------|------------|------------------------|
| `PLANNING.md` (local: `docs/prior-art/github.com/SuperClaude/PLANNING.md`) | Architecture and design principles including confidence-first implementation | Confidence thresholds (>=90% proceed, <70% STOP) parallel Jim's stop-and-escalate pattern. |
| `src/superclaude/pm_agent/self_check.py` | Post-implementation validation with "7 Red Flags" | Red flags like "Tests pass without output" and "Implementation complete with failing tests" reinforce Jim's "never assume a test passes" rule. |

**Key takeaways for Jim:**
- **Confidence-first as stop signal**: SuperClaude's <70% confidence = STOP mirrors Jim's "stuck → STOP → escalate" pattern. Jim doesn't need numeric thresholds — the plan provides the confidence signal.
- **Self-check "7 Red Flags"**: Useful reference for Jim's failure detection, especially "tests pass without output" — Jim's spec already requires "All test runs executed via Bash with visible output."

#### Other References
- **[Taming GenAI Agents with TDD](https://www.nathanfox.net/p/taming-genai-agents-like-claude-code)** (nathanfox.net): Embedding TDD in CLAUDE.md creates "institutional discipline" — Jim goes further with a dedicated skill and explicit phase gates.
- **[VoltAgent Awesome Claude Code Subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)**: Tool scoping (limiting agent permissions to necessary tools) is standard across 100+ subagents. Jim's `tools: [Read, Write, Edit, Glob, Grep, Bash]` is appropriately scoped.

## Security & Performance

- **Context rot during long TDD loops**: The primary performance risk. GSD and alexop.dev both solve this with fresh context per subagent. Jim's coder already runs as a subagent with focused context (plan + spec + research), which mitigates this. The 3-retry limit on Green phase provides an additional safety valve. If multi-task plans prove too long for a single subagent context, per-task subagent spawning (GSD-style) is a future escalation path — but start with the simpler single-subagent model and let experience dictate.
- **Runaway Bash execution**: The coder runs tests via Bash. The spec's scope discipline ("does NOT add functionality beyond the plan") and stop-on-failure rules bound execution. Claude Code's native bash approval prompts serve as the ultimate backstop against destructive commands during test runs — no additional sandboxing needed for the skill definition itself.

## Recommendations

- **Preserve V1 simplicity**: The V1 agent (46 lines) and skill (56 lines) are already well-structured. The 006 spec's additions (skills frontmatter, examples, debug skill, type-specific behavior) are incremental. Do not over-engineer.
- **Use explicit phase gate language**: Adopt alexop.dev's "Do NOT proceed to Green phase until test failure is confirmed" pattern in the build skill. This is the proven enforcement mechanism.
- **Reference doc over agent bloat**: The spec correctly separates methodology detail into `tdd-guide.md` (reference) rather than bloating the agent prompt. The agent body should stay under 800 tokens per the spec.
- **Debug report structure**: Model `/jim:debug` output on Pimzino's Report → Analyze → Fix → Verify flow, adapted as: Error Analysis → Reproduction Steps → Root Cause Hypothesis → Recommended Next Step.
- **No new dependencies**: Execution relies entirely on native Claude Code tool capabilities (Bash, Glob, Edit, etc.). No external libraries or extensions required.

## Peer Feedback

- **For Architect:** Plan tasks must be strictly decoupled — each task should be independently executable without hidden state dependencies on prior tasks. The fresh-context subagent model (proven across GSD, alexop.dev, and cc-sdd) means the coder cannot rely on accumulated context between tasks. Tasks with implicit ordering assumptions will fail or produce wrong results.

## Alignment

This research aligns with VISION.md's core mission: "Jim provides an agentic SDLC workflow for Claude Code via `/jim:spec`, `/jim:plan`, and `/jim:build` skills." The coder agent is the execution arm of this vision. The human-in-the-loop principle ("Agents STOP and wait for approval") is reinforced by every prior art source studied — Beck, alexop.dev, GSD, and spec-kit all emphasize stop-and-escalate over autonomous retry. ARCHITECTURE.md is empty; no architectural constraints to validate against.
