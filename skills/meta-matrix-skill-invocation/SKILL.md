---
name: meta-matrix-skill-invocation
description: >
  Manual probe for all four Claude Code skill-invocation paths (direct
  slash command, Skill-tool mid-run, `context: fork` subagent, `skills:`
  preload subagent) and `$ARGUMENTS` propagation through the Skill tool.
  Quit and relaunch Claude Code from the repo root so this skill is
  discovered at session start. Read the rendered body for SUBST_* sentinels;
  subagent-side sentinels (S4, S5) appear in returned Skill/Agent tool results.
allowed-tools: Bash(echo *), Bash(bash -c *), Skill(jim:meta-matrix-fork-probe), Agent(meta-matrix-probe)
---

# Skill-invocation substitution matrix

Each row probes one invocation path from `docs/research/20260512-001-meta-skill-invocation-freshness.md` § "Same-agent vs subagent execution". S1 covers path 1 (direct slash-command). S2 covers path 4 (Skill tool mid-run from the dispatcher). S3 probes `$ARGUMENTS` propagation through the Skill tool. **S4 covers path 2 (`context: fork`); S5 covers path 3 (`skills:` preload)** — both rely on internal harness skills (`meta-matrix-fork-probe`, `meta-matrix-preload-probe`) and the `meta-matrix-probe` subagent. See the dispatcher (`skills/meta-matrix/SKILL.md`) for the shared "How to interpret" guidance.

## Session metadata

Before rendering the sentinel rows, emit the active Claude Code model identifier so this rendered matrix is self-attributable. Read your system prompt for the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"` and emit, verbatim, exactly two lines:

    MODEL_NAME: <name from system prompt>
    MODEL_ID: <id from system prompt>

If you cannot locate that line in your system prompt, emit `MODEL_NAME: unknown` and `MODEL_ID: unknown` rather than guessing.

### S1 — direct slash-command invocation (path 1)

!`echo SUBST_SKILL_PATH1_DIRECT`

Interpretation note: visible after direct `/jim:meta-matrix-skill-invocation` invocation (path 1) and after dispatcher chain-all; presence confirms the body loaded at all.

### S2 — invocation via Skill tool from dispatcher (path 4)

!`echo SUBST_SKILL_PATH4_VIA_TOOL`

Interpretation note: visible whenever this sub-skill loads via the Skill tool (path 4), which happens during dispatcher chain-all or `/jim:meta-matrix skill-invocation`. Presence confirms path-4 invocation works.

### S3 — $ARGUMENTS propagation through Skill tool

!`echo SUBST_SKILL_ARGS_PROPAGATE "$ARGUMENTS"`

Interpretation note: read the value after `SUBST_SKILL_ARGS_PROPAGATE`. The interesting case is when this sub-skill is reached via the dispatcher: whether `$ARGUMENTS` is empty, carries the dispatcher's argument string, or something else is undocumented; this row captures the answer empirically.

### S4 — context: fork subagent invocation (path 2)

Invoke `Skill(jim:meta-matrix-fork-probe)` from the body above this section. The fork-probe skill carries `context: fork` + `agent: meta-matrix-probe` frontmatter, so Claude Code spawns a fresh subagent and uses the fork-probe body as the subagent's task prompt. The fork-probe body uses a **dual-sentinel design** (one bare literal `SUBST_SKILL_PATH2_FORK_LITERAL`, one through `!`-injection `!`echo SUBST_SKILL_PATH2_FORK_THRU_INJECTION``); the forked subagent's final message returns both readings to this conversation as the Skill tool's result.

**Expect a consent prompt on first invocation.** Empirically (2026-05-13 second rerun, see plan Open Questions), Claude Code shows an explicit "Use skill 'jim:meta-matrix-fork-probe'?" prompt the first time this row fires in a project, even though `Skill(jim:meta-matrix-fork-probe)` is in this sub-skill's `allowed-tools`. This appears to be an additional gate Claude Code applies to skills with `context: fork` frontmatter, separate from the `Skill(name)` permission token. Select "Yes, don't ask again for jim:meta-matrix-fork-probe in <project>" to avoid re-prompting in the same project.

Interpretation rubric (compare the LITERAL and THRU_INJECTION readings the probe agent reports):

| LITERAL                  | THRU_INJECTION                                    | Inferred                                                                |
| :----------------------- | :------------------------------------------------ | :---------------------------------------------------------------------- |
| `SUBST_*_LITERAL` (bare) | `SUBST_*_THRU_INJECTION` (bare)                   | **Substitution fired** somewhere along the path 2 chain.                |
| `SUBST_*_LITERAL` (bare) | `` !`echo SUBST_*_THRU_INJECTION` `` (literal)    | **Substitution did NOT fire** on path 2 — bodies pass through verbatim. |
| `ABSENT`                 | `ABSENT`                                          | **Harness failure** — `context: fork` mechanism unsupported or denied.  |
| `ABSENT`                 | bare or literal                                   | **Unexpected** — something stripped the literal. Investigate.           |

The dual-sentinel design supersedes the original single-sentinel design used in the 2026-05-13 first matrix rerun. The earlier rerun observed bare-string THRU_INJECTION but did not provide a LITERAL control to confirm the harness fired in the first place; the amendment closes that ambiguity.

### S5 — skills: preload subagent invocation (path 3)

Invoke `Agent(meta-matrix-probe)` from the body above this section with the prompt `"Emit your preloaded probe content."` The agent's `skills: [meta-matrix-preload-probe]` field preloads the preload-probe body into its startup context; that body also uses the **dual-sentinel design** (`SUBST_SKILL_PATH3_PRELOAD_LITERAL` + `!`echo SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION``). The agent reports both readings as its final message.

Interpretation rubric is the same shape as S4 — compare LITERAL and THRU_INJECTION to infer:

| LITERAL                  | THRU_INJECTION                                    | Inferred                                                                |
| :----------------------- | :------------------------------------------------ | :---------------------------------------------------------------------- |
| `SUBST_*_LITERAL` (bare) | `SUBST_*_THRU_INJECTION` (bare)                   | **Substitution fired** along the path 3 chain.                          |
| `SUBST_*_LITERAL` (bare) | `` !`echo SUBST_*_THRU_INJECTION` `` (literal)    | **Substitution did NOT fire** — preload passes bodies through verbatim. |
| `ABSENT`                 | `ABSENT`                                          | **Harness failure** — `skills:` preload mechanism unsupported or denied.|
| `ABSENT`                 | bare or literal                                   | **Unexpected** — something stripped the literal. Investigate.           |

The probe characterizes preload-time substitution semantics — a path orthogonal to S4's fork-time behavior.

---

**Coverage.** All four invocation paths from `docs/research/20260512-001-meta-skill-invocation-freshness.md` § "Same-agent vs subagent execution" are probed in this sub-skill:

- S1 → path 1 (direct slash-command)
- S2 → path 4 (Skill tool mid-run)
- S3 → `$ARGUMENTS` propagation through the Skill tool (closed empirically — see `docs/specs/sdlc/011-meta-matrix/plan.md` Verification Log row S3)
- S4 → path 2 (`context: fork`), via `skills/meta-matrix-fork-probe/`
- S5 → path 3 (`skills:` preload), via `agents/meta-matrix-probe.md` + `skills/meta-matrix-preload-probe/`

The harness implementations (`meta-matrix-fork-probe`, `meta-matrix-preload-probe`, `meta-matrix-probe`) are internal — direct invocation by users is supported by Claude Code but yields only one sentinel each. Use this sub-skill (or the parent `/jim:meta-matrix` dispatcher) for the full path-coverage matrix.
