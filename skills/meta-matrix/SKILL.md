---
name: meta-matrix
description: >
  Manual probe matrix for Claude Code runtime behavior. Quit and relaunch
  Claude Code from the repo root so this skill family is discovered at
  session start. Invoke with no argument to chain all four category
  sub-skills sequentially; invoke with one of bash-invocation,
  variable-setting, conditional-evaluation, or skill-invocation to load
  only that category's sentinel rows.
argument-hint: "[bash-invocation | variable-setting | conditional-evaluation | skill-invocation]"
allowed-tools: Skill(jim:meta-matrix-bash-invocation) Skill(jim:meta-matrix-variable-setting) Skill(jim:meta-matrix-conditional-evaluation) Skill(jim:meta-matrix-skill-invocation)
---

# /jim:meta-matrix

Manual diagnostic for Claude Code substitution and invocation behavior. Each sub-skill body contains sentinel rows you read to confirm which patterns work and which silently fail.

Direct invocation of any sub-skill (`/jim:meta-matrix-<category>`) bypasses this dispatcher and is supported; the dispatcher exists for chain-all and category-selection ergonomics.

## Session metadata

Before dispatching to any sub-skill, emit the active Claude Code model identifier so this rendered matrix is self-attributable. Read your system prompt for the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"` and emit, verbatim, exactly two lines:

    MODEL_NAME: <name from system prompt>
    MODEL_ID: <id from system prompt>

If you cannot locate that line, emit `MODEL_NAME: unknown` / `MODEL_ID: unknown` rather than guessing. Each loaded sub-skill will repeat this two-line header. In chain-all mode (5 headers total), all five should agree; a discrepancy surfaces a mid-session model swap.

## Dispatch

IF $ARGUMENTS == "" THEN
  Sequentially invoke each sub-skill via the Skill tool, in this order:
    1. Skill(jim:meta-matrix-bash-invocation)
    2. Skill(jim:meta-matrix-variable-setting)
    3. Skill(jim:meta-matrix-conditional-evaluation)
    4. Skill(jim:meta-matrix-skill-invocation)
ELSE IF $ARGUMENTS == "bash-invocation" THEN
  Invoke Skill(jim:meta-matrix-bash-invocation).
ELSE IF $ARGUMENTS == "variable-setting" THEN
  Invoke Skill(jim:meta-matrix-variable-setting).
ELSE IF $ARGUMENTS == "conditional-evaluation" THEN
  Invoke Skill(jim:meta-matrix-conditional-evaluation).
ELSE IF $ARGUMENTS == "skill-invocation" THEN
  Invoke Skill(jim:meta-matrix-skill-invocation).
ELSE
  STOP and tell the user: "Unknown category '$ARGUMENTS'. Valid: bash-invocation, variable-setting, conditional-evaluation, skill-invocation."
ENDIF

## How to interpret

After invocation, scan the rendered body for each `SUBST_*` sentinel:

- Sentinel visible → that wrapper allowed substitution. ✅
- Literal `` !`echo SUBST_*` `` visible → that wrapper suppressed substitution. ❌

The full matrix tells you which jim-production patterns are load-bearing slots vs. silent failures, AND whether the canonical sentinel form (`SET <name> = !`bash …`` + `IF <name> != "NOT_FOUND" THEN … ELSE … ENDIF`) lands safely. Cross-reference against the inventory in `docs/debug/20260512-skill-bash-substitution-wrappers.md` for which production files contain each pattern.

**The lean control-flow refinement is only viable if AA and BB both return ✅** (rows live in `meta-matrix-conditional-evaluation`). Both patterns expect their four `SET … = !`echo SUBST_*`` slots to substitute. The surrounding control-flow keywords (`IF … THEN`, `ELSE IF == "value" THEN`, `ENDIF`, indented numbered lists with no `DO:`/`DONE`) should not affect substitution — they're LLM-interpreted prose, invisible to the preprocessor.

**The D2-revised path-or-`NOT_FOUND` semantics rely on rows GG/HH** (spec 011 amendment 2026-05-13). Expected reading of the rendered body:

- GG: sentinel `SUBST_GG_ELSE_OK` visible (ELSE branch fires); `SUBST_GG_THEN_FIRED` **not** reached.
- HH: sentinel `SUBST_HH_THEN_OK` visible (THEN branch fires); `SUBST_HH_ELSE_FIRED` **not** reached.

If either GG or HH evaluates the wrong branch, the sentinel form is not safe under the substitution layer and the amendment must be reconsidered before merging.

**Rows CC–FF are historical** (spec 013 D8 empty-no-op contract). They are preserved verbatim for forensic record but are no longer load-bearing — D2 was revised to path-or-`NOT_FOUND` on 2026-05-13, retiring the empty-substitution contract entirely. If you are running this matrix after the 2026-05-13 amendment, GG/HH are the load-bearing conditional-evaluation rows; CC–FF outcomes are informational only.

**Rows U, V, X, Y, Z** exercise the retired `*_IF_EXISTS` directive vocabulary. Preserved as forensic record per spec 011's 2026-05-13 amendment; no longer load-bearing.
