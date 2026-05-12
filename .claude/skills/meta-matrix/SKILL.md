---
name: meta-matrix
description: >
  Manual regression probe for the substitution convention. Quit and relaunch
  Claude Code from the repo root so this skill is discovered at session start,
  then invoke it to verify which markdown wrapper patterns let `!`-injection
  fire and which suppress it silently. Each row uses a unique sentinel marker
  so you can read the loaded body and tell at a glance which substituted (you
  see the sentinel) and which did not (you see literal backticks).
allowed-tools: Bash(echo *), Bash(bash -c *)
---

# Substitution wrapper test matrix

Each row prints a unique sentinel via `echo`. If you see the sentinel
string in the loaded skill body, that pattern substituted. If you see the
literal text `` !`echo …` ``, the preprocessor skipped it.

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

### N — inside fenced code block (expected ❌, code-fence is literal)

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

## Proposed directive vocabulary (under test for the bug spec)

Each row below tests one shape from the proposed `READ_IF_EXISTS` /
`RUN_IF_EXISTS` / `SET` / `DO_IF_EXISTS` directive vocabulary. Goal:
confirm the preprocessor accepts the directive prefix as a benign
end-of-line surface for `!`-injection`, so the small declarative
language can rest on `!`-injection` rather than fight it.

### U — `READ_IF_EXISTS <slot> — note` (single-line read gate)

READ_IF_EXISTS !`echo SUBST_U_READ_IF_EXISTS` — locked constraint, do not re-litigate.

### V — `RUN_IF_EXISTS <slot> — note` (single-line run gate)

RUN_IF_EXISTS !`echo SUBST_V_RUN_IF_EXISTS` — show full output.

### W — `SET <name> = <slot>` (bind a slot to a name)

SET vision_doc = !`echo SUBST_W_SET_ASSIGN`

### X — `DO_IF_EXISTS <slot>:` followed by ordered list (multi-step gate)

DO_IF_EXISTS !`echo SUBST_X_DO_IF_EXISTS`:
1. First step uses the slot value above.
2. Second step.

### Y — numbered-list compound: `1. READ_IF_EXISTS <slot>`

1. READ_IF_EXISTS !`echo SUBST_Y_NUMBERED_DIRECTIVE` — note.

### Z — indented under a numbered step (continuation paragraph): directive

1. Top-level step prose:

   READ_IF_EXISTS !`echo SUBST_Z_INDENTED_DIRECTIVE` — locked constraint.

## Lean control-flow shape (under test for the convention refinement)

The patterns below verify the refined paren-free `IF` shape: indentation-as-block-delimiter (no `DO:`/`DONE`), `ELSE IF X == "value" THEN` chained branches, `ENDIF` (one word) as terminator. All `!`-injection slots live in `SET` lines (which W already verified). AA and BB confirm the surrounding control-flow keywords do not disrupt substitution.

### AA — SET + lean IF with indented numbered body, no DO:/DONE

SET subst_aa_path = !`echo SUBST_AA_PATH`
SET subst_aa_flag = !`echo SUBST_AA_FLAG`

IF subst_aa_path EXISTS THEN
  1. First step references subst_aa_path.
  2. Second step would STOP on a condition.
ENDIF

### BB — full chained form: IF / ELSE IF X == "value" THEN / ENDIF

SET subst_bb_path = !`echo SUBST_BB_PATH`
SET subst_bb_flag = !`echo SUBST_BB_FLAG`

IF subst_bb_path EXISTS THEN
  1. Run something using subst_bb_path.
  2. STOP on non-zero.
ELSE IF subst_bb_flag == "true" THEN
  STOP with: "Required script not found at subst_bb_path."
ENDIF

## How to interpret

After invoking this skill, scan the rendered body for each `SUBST_*`
sentinel:

- **Sentinel visible** → that wrapper allowed substitution. ✅
- **Literal `` !`echo SUBST_*` `` visible** → that wrapper suppressed
  substitution. ❌

The full matrix (A–Z) tells you which jim-production patterns are
load-bearing slots vs. silent failures, AND whether the proposed
directive vocabulary (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `SET`,
`DO_IF_EXISTS`) lands safely. Cross-reference against the inventory in
`docs/debug/20260512-skill-bash-substitution-wrappers.md` for which
production files contain each pattern.

**The directive vocabulary is only worth standardizing if patterns
U–Z all return ✅.** If any of those fail, the bug spec must pick a
different convention shape before migration.

**The lean control-flow refinement is only viable if AA and BB both
return ✅.** Both patterns expect the four `SET ... = !`echo SUBST_*`` slots
to substitute (sentinels `SUBST_AA_PATH`, `SUBST_AA_FLAG`, `SUBST_BB_PATH`,
`SUBST_BB_FLAG` visible in the rendered body). The surrounding control-flow
keywords (`IF ... THEN`, `ELSE IF == "value" THEN`, `ENDIF`, indented
numbered lists with no `DO:`/`DONE`) should not affect substitution —
they're LLM-interpreted prose, invisible to the preprocessor. If either
AA or BB shows literal `` !`echo SUBST_*` `` for any of its four SET
slots, the lean form is not safe and the convention must keep the heavier
`DO:`/`DONE`/`END IF` shape.
