---
name: meta-matrix-conditional-evaluation
description: >
  Manual probe for conditional / branching directive substitution — covers
  retired `*_IF_EXISTS` directives (rows U, V, X, Y, Z, forensic), lean
  paren-free `IF` chains (rows AA, BB), historical empty-substitution no-op
  behavior (rows CC–FF, forensic per fixture annotation), and the canonical
  post-amendment sentinel form with positive/negative cases (rows GG, HH,
  load-bearing). Quit and relaunch Claude Code from the repo root so this
  skill is discovered at session start. Read the rendered body for SUBST_*
  sentinels.
allowed-tools: Bash(echo *), Bash(bash -c *)
---

# Conditional-evaluation substitution matrix

Each row probes a branching or conditional-directive surface. Rows U, V, X, Y, Z exercise retired single-line `*_IF_EXISTS` directives (preserved as forensic record per the 2026-05-13 spec 011 amendment). Rows AA, BB exercise the lean paren-free `IF` chain (load-bearing). Rows CC–FF probe historical empty-substitution no-op behavior (forensic). Rows GG, HH exercise the canonical post-amendment sentinel form — `SET <name> = !`bash …`` + `IF <name> != "NOT_FOUND" THEN … ELSE … ENDIF` (load-bearing). See the dispatcher (`skills/meta-matrix/SKILL.md`) for the shared "How to interpret" guidance.

## Session metadata

Before rendering the sentinel rows, emit the active Claude Code model identifier so this rendered matrix is self-attributable. Read your system prompt for the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"` and emit, verbatim, exactly two lines:

    MODEL_NAME: <name from system prompt>
    MODEL_ID: <id from system prompt>

If you cannot locate that line in your system prompt, emit `MODEL_NAME: unknown` and `MODEL_ID: unknown` rather than guessing.

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

## Empty-substitution probes (spec 013 D8 — HISTORICAL; superseded 2026-05-13)

> **Superseded by 2026-05-13 amendment to spec 011** — D2 was revised from path-or-empty to path-or-`NOT_FOUND`, retiring the EXISTS-family directive vocabulary entirely. Rows CC–FF below are no longer load-bearing; the new sentinel form is exercised by rows GG/HH below. Rows CC–FF preserved verbatim for forensic record.

The rows below verify that when an `!`-injection slot substitutes to the
empty string (the failure mode under the original spec 013 D2 — a path
key whose configured file does not exist on disk), every directive in
the family no-ops cleanly rather than triggering a spurious Read / Bash
/ wrong branch. Each row uses a unique sentinel marker in its
surrounding prose so a human reader can tell what is expected at a
glance.

### CC — `READ_IF_EXISTS` with empty substitution (D8 probe)

READ_IF_EXISTS !`echo` — sentinel SUBST_CC_READ_EMPTY-NOOP, expect no Read tool call.

### DD — `RUN_IF_EXISTS` with empty substitution (D8 probe)

RUN_IF_EXISTS !`echo` — sentinel SUBST_DD_RUN_EMPTY-NOOP, expect no Bash tool call.

### EE — `DO_IF_EXISTS` with empty substitution (D8 probe)

DO_IF_EXISTS !`echo`:
  1. Sentinel SUBST_EE_DO_EMPTY-NOOP — this indented block should be skipped entirely.

### FF — `SET` + `IF EXISTS` with empty substitution (D8 probe)

SET ff_path = !`echo`

IF ff_path EXISTS THEN
  Sentinel SUBST_FF_SET_EMPTY-FIRED — should NOT be reached (ff_path is empty).
ELSE
  Sentinel SUBST_FF_SET_EMPTY-ELSE-OK — expected fall-through.
ENDIF

## Sentinel-based gate probes (spec 011 amendment 2026-05-13)

The rows below verify the post-amendment sentinel form: `SET <name> = !`bash …`` + `IF <name> != "NOT_FOUND" THEN … ELSE … ENDIF`. The resolver now returns the literal string `NOT_FOUND` for missing path-typed keys (D2-revised). GG exercises the negative case (SET binds to `NOT_FOUND` → ELSE fires); HH exercises the positive case (SET binds to a resolved path → THEN fires). Both rows must pass for the sentinel form to be safe under the substitution layer.

### GG — `SET x = NOT_FOUND` + `IF x != "NOT_FOUND" THEN … ELSE … ENDIF` (negative case)

SET gg_path = !`echo NOT_FOUND`

IF gg_path != "NOT_FOUND" THEN
  Sentinel SUBST_GG_THEN_FIRED — should NOT be reached (gg_path is "NOT_FOUND").
ELSE
  Sentinel SUBST_GG_ELSE_OK — expected fall-through.
ENDIF

### HH — `SET x = /tmp/sentinel-hh-resolved-path` + `IF x != "NOT_FOUND" THEN … ELSE … ENDIF` (positive case)

SET hh_path = !`echo /tmp/sentinel-hh-resolved-path`

IF hh_path != "NOT_FOUND" THEN
  Sentinel SUBST_HH_THEN_OK — expected; hh_path is /tmp/sentinel-hh-resolved-path.
ELSE
  Sentinel SUBST_HH_ELSE_FIRED — should NOT be reached.
ENDIF
