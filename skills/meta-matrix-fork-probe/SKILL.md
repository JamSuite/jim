---
name: meta-matrix-fork-probe
description: >
  Internal harness for meta-matrix path-2 (`context: fork`) probing. Invoked
  only by `skills/meta-matrix-skill-invocation/` (row S4) via the Skill tool.
  By itself this skill emits one sentinel and stops; quit and relaunch Claude
  Code from the repo root so it is discovered at session start. Not intended
  for direct user invocation.
context: fork
agent: meta-matrix-probe
allowed-tools: Bash(echo *)
---

# Fork-probe (path 2 harness)

You have been spawned via `context: fork`. This skill body is your task prompt; the `meta-matrix-probe` agent persona is your system prompt. Your single job is to surface whether `!`-injection in a forked skill body substitutes — by comparing how two paired sentinels arrive in your context.

## Sentinels (dual design — substitution-tier disambiguation)

Two probes for the same path, side-by-side:

- **LITERAL (control — bare text, no `!`-injection):** SUBST_SKILL_PATH2_FORK_LITERAL
- **THRU_INJECTION (test — should substitute if path 2 fires `!`-injection):** !`echo SUBST_SKILL_PATH2_FORK_THRU_INJECTION`

The LITERAL sentinel arrives at your context as plain text regardless of substitution behavior — it is the control that proves the harness fired and delivered the body. The THRU_INJECTION sentinel arrives substituted (bare string) only if `!`-injection ran along the parent → Skill-tool → fork-handoff → subagent-startup chain. Comparing the two pins down whether substitution fired.

## How to read the THRU_INJECTION slot (load-bearing — invert your intuition)

**Bare text visible = `echo` ran (substitution fired). Backticked text visible = `echo` did NOT run (no substitution).**

- If you see the **bare sentinel** `SUBST_SKILL_PATH2_FORK_THRU_INJECTION` in your task prompt (just the plain text, no backticks, no `echo`, no `!`) → the `!`-injection FIRED somewhere along the chain. The `echo` ran and emitted the sentinel as plain text. **Inferred: substitution fired.**
- If you see the **literal** `` !`echo SUBST_SKILL_PATH2_FORK_THRU_INJECTION` `` (backticks and `echo` command preserved) → the `!`-injection did NOT fire. **Inferred: did not fire.**

The trap: do NOT read "bare text visible, nothing transformed it" as "didn't fire." Visible plain text IS the transformation evidence — the preprocessor REPLACED the backticked expression with the echo's output. The LITERAL slot's bare sentinel is plain text in source (no `!`-injection); the THRU slot's bare sentinel is plain text **produced by** `!`-injection running. They look the same; the source difference is what makes the comparison meaningful.

## Report

In your final message, follow `agents/meta-matrix-probe.md` § Process precisely:

1. Emit the model header (`MODEL_NAME` / `MODEL_ID`) as the first two lines.
2. Emit the row S4 block per the agent's reporting template:

       Row S4 (context: fork, path 2):
         LITERAL:        <what you see for SUBST_SKILL_PATH2_FORK_LITERAL>
         THRU_INJECTION: <what you see for SUBST_SKILL_PATH2_FORK_THRU_INJECTION — bare string or literal `!`echo …`` form>
         Inferred:       <apply the THRU-slot rule above: bare in THRU → "substitution fired"; literal `!`echo …`` in THRU → "did not fire"; both absent → "harness failure"; LITERAL absent only → "unexpected">

3. Stop.

Do not run `echo` yourself to produce the sentinels — the probe characterizes what *arrived* in your task prompt, not what you can locally synthesize. If a sentinel is absent from your context, write `ABSENT` in its slot.

The parent skill (`meta-matrix-skill-invocation` row S4) reads the Skill tool result for both sentinels and the inferred-tier finding.
