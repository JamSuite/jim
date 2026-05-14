---
name: meta-matrix-bash-invocation
description: >
  Manual probe for `!`-injection wrapper-pattern substitution behavior
  (markdown rows A–T from the 011 fixture). Quit and relaunch Claude
  Code from the repo root so this skill is discovered at session start.
  Read the rendered body for SUBST_* sentinels.
allowed-tools: Bash(echo *), Bash(bash -c *)
---

# Bash-invocation substitution matrix

Each row prints a unique sentinel via `echo`. If you see the sentinel string in the loaded skill body, that pattern substituted. If you see the literal text `` !`echo …` ``, the preprocessor skipped it. See the dispatcher (`skills/meta-matrix/SKILL.md`) for the shared "How to interpret" guidance.

## Session metadata

Before rendering the sentinel rows, emit the active Claude Code model identifier so this rendered matrix is self-attributable. Read your system prompt for the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"` and emit, verbatim, exactly two lines:

    MODEL_NAME: <name from system prompt>
    MODEL_ID: <id from system prompt>

If you cannot locate that line in your system prompt, emit `MODEL_NAME: unknown` and `MODEL_ID: unknown` rather than guessing.

## Controls (already confirmed in prior testing)

### A — bare on its own line (CONTROL, expected ✅)

!`echo SUBST_A_BARE_LINE`

### B — bare with `bash -c` (CONTROL, expected ✅)

!`bash -c 'echo SUBST_B_BASH_DASH_C'`

### C — pseudocode IF wrapper (CONTROL, expected ❌)

IF (!`echo SUBST_C_IF_PAREN`) EXISTS THEN

### D — jim-style IF wrapper with bash invocation (CONTROL, expected ❌)

IF (!`bash -c 'echo SUBST_D_IF_BASH'`) EXISTS THEN

## New patterns under test

### E — unordered list bullet, slot at end-of-bullet

- Bullet body text !`echo SUBST_E_BULLET_TAIL`

### F — ordered list item, slot at end-of-line

1. Numbered body text !`echo SUBST_F_NUMBERED_TAIL`

### G — ordered list item with IF wrapper (matches `build/SKILL.md:92`)

1. IF (!`echo SUBST_G_NUMBERED_IF`) EXISTS THEN DO:

### H — indented under a numbered step, IF wrapper (matches `research/SKILL.md:99`)

1. Top-level step prose:

   IF (!`echo SUBST_H_INDENTED_IF`) EXISTS THEN
     READ FILE.
   END IF

### I — mid-sentence prose, slot embedded between words

Run the script via !`echo SUBST_I_MIDSENTENCE` and continue reading.

### J — mid-sentence prose with bold lead-in (matches `meta-skill/SKILL.md:25`)

**Gate 1 — Lead-in:** Locate the resource via !`echo SUBST_J_BOLD_LEADIN` then proceed.

### K — slot followed by sentence-terminator period (matches `vision/SKILL.md:79`)

Write to !`echo SUBST_K_TRAILING_PERIOD`.

### L — table cell (matches `arch/SKILL.md:24`)

| Input | Behavior |
| :--- | :--- |
| Empty | Default: !`echo SUBST_L_TABLE_CELL` |

### M — blockquote

> Quoted text !`echo SUBST_M_BLOCKQUOTE` here.

### N — inside fenced code block (substitutes ✅; fences are NOT literal — see ARCHITECTURE.md → Substitution Conventions)

```
fenced code !`echo SUBST_N_FENCED`
```

### O — inside indented code block (4-space indent)

    indented code !`echo SUBST_O_INDENTED_FENCE`

### P — inside inline backtick code (expected ❌, inline-code is literal)

Prose around `inline !`echo SUBST_P_INLINE_CODE` inline` more prose.

### Q — inside HTML comment

<!-- comment !`echo SUBST_Q_HTML_COMMENT` end -->

### R — slot at line start, no leading text (sibling of A, no whitespace)

!`echo SUBST_R_LINE_START`

### S — slot preceded by space at start of line

 !`echo SUBST_S_LEADING_SPACE`

### T — slot inside parentheses NOT in an IF construct

(Standalone parens !`echo SUBST_T_PARENS`)
