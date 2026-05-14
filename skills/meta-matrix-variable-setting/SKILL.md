---
name: meta-matrix-variable-setting
description: >
  Manual probe for `SET <name> = !`bash …`` variable-binding substitution
  behavior. Quit and relaunch Claude Code from the repo root so this skill
  is discovered at session start. Read the rendered body for SUBST_*
  sentinels.
allowed-tools: Bash(echo *), Bash(bash -c *)
---

# Variable-setting substitution matrix

Each row binds a slot via `SET <name> = !`echo …``. If the sentinel string is visible after the `=`, the `!`-injection fired and the bound name carries the resolved value. If you see literal backticks, the substitution layer suppressed the slot. See the dispatcher (`skills/meta-matrix/SKILL.md`) for the shared "How to interpret" guidance.

## Session metadata

Before rendering the sentinel rows, emit the active Claude Code model identifier so this rendered matrix is self-attributable. Read your system prompt for the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"` and emit, verbatim, exactly two lines:

    MODEL_NAME: <name from system prompt>
    MODEL_ID: <id from system prompt>

If you cannot locate that line in your system prompt, emit `MODEL_NAME: unknown` and `MODEL_ID: unknown` rather than guessing.

### W — `SET <name> = <slot>` (bind a slot to a name)

SET vision_doc = !`echo SUBST_W_SET_ASSIGN`

### W2 — SET assignment without an accompanying IF (D2 readback probe)

SET v2_path = !`echo SUBST_VAR_W2_SET_STANDALONE`

Interpretation note: the sentinel `SUBST_VAR_W2_SET_STANDALONE` should appear after the `=`. This probe verifies that a `SET` line substitutes correctly even when no downstream `IF` predicate consumes the name, complementing row W (which embeds the `SET` in a directive-vocabulary context).
