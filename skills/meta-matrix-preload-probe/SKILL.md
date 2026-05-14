---
name: meta-matrix-preload-probe
description: >
  Internal harness for meta-matrix path-3 (`skills:` preload) probing.
  Preloaded into the meta-matrix-probe subagent at startup via that agent's
  `skills:` frontmatter; not for direct user invocation. By itself this
  skill emits one sentinel and stops; quit and relaunch Claude Code from
  the repo root so it is discovered at session start.
allowed-tools: Bash(echo *)
---

# Preload-probe (path 3 harness)

This body is injected into the `meta-matrix-probe` subagent's startup context via `agents/meta-matrix-probe.md`'s `skills: [meta-matrix-preload-probe]` field. The two sentinels below are the probe signals.

## Sentinels (dual design — substitution-tier disambiguation)

Two probes for the same path, side-by-side:

- **LITERAL (control — bare text, no `!`-injection):** SUBST_SKILL_PATH3_PRELOAD_LITERAL
- **THRU_INJECTION (test — should substitute if path 3 fires `!`-injection):** !`echo SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION`

The LITERAL sentinel arrives in the probe agent's startup context as plain text regardless — it is the control that proves the `skills:` preload mechanism delivered this body. The THRU_INJECTION sentinel arrives substituted (bare string) only if `!`-injection ran along the parent → Agent-tool → preload-injection → subagent-startup chain. Comparing the two pins down whether substitution fired during path 3.

## How to read the THRU_INJECTION slot (load-bearing — invert your intuition)

**Bare text visible = `echo` ran (substitution fired). Backticked text visible = `echo` did NOT run (no substitution).**

- If the probe agent sees the **bare sentinel** `SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION` in its preloaded context (just the plain text, no backticks, no `echo`, no `!`) → the `!`-injection FIRED somewhere along the chain. The `echo` ran and emitted the sentinel as plain text. **Inferred: substitution fired.**
- If the probe agent sees the **literal** `` !`echo SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION` `` (backticks and `echo` command preserved) → the `!`-injection did NOT fire. **Inferred: did not fire.**

The trap: do NOT read "bare text visible, nothing transformed it" as "didn't fire." Visible plain text IS the transformation evidence — the preprocessor REPLACED the backticked expression with the echo's output. The LITERAL slot's bare sentinel is plain text in source (no `!`-injection); the THRU slot's bare sentinel is plain text **produced by** `!`-injection running. They look the same; the source difference is what makes the comparison meaningful.

## Report

When the `meta-matrix-probe` subagent is spawned (typically by `meta-matrix-skill-invocation` row S5 via `Agent(meta-matrix-probe)`), the agent inspects this preloaded body and emits a row S5 block per `agents/meta-matrix-probe.md` § Process:

    Row S5 (skills: preload, path 3):
      LITERAL:        <what the agent sees for SUBST_SKILL_PATH3_PRELOAD_LITERAL>
      THRU_INJECTION: <what the agent sees for SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION — bare string or literal `!`echo …`` form>
      Inferred:       <apply the THRU-slot rule above: bare in THRU → "substitution fired"; literal `!`echo …`` in THRU → "did not fire"; both absent → "harness failure"; LITERAL absent only → "unexpected">

The parent reads the returned Agent tool result for both sentinels and the inferred-tier finding. This probe characterizes preload-time substitution semantics — a path orthogonal to path-2 (`context: fork`) behavior probed by `meta-matrix-fork-probe`.
