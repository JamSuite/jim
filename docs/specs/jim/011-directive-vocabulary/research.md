---
spec: "docs/specs/jim/011-directive-vocabulary/spec.md"
status: Active
date: "2026-05-12"
---

# Research: Replace IF-wrap pseudocode with a directive vocabulary for !-injection gates

## Anchors

### Production skill slots (12 confirmed IF-WRAP sites)

All line numbers verified against current file state.

**`skills/plan/SKILL.md:53`** — IF-WRAP on a bare line, inside prose under `### 3. Check the architecture doc`. Surrounded by a paragraph above and `ELSE … END IF` closing block on lines 54–57. No list nesting; the directive replacement is a clean one-line swap.

**`skills/spec/SKILL.md:33,37`** — Two stacked IF-WRAP blocks under `### 2. Read strategic context` (lines 31–39). Both are bare-line, separated by a blank line, followed by a prose paragraph on line 41. No list nesting; both collapse to two `READ_IF_EXISTS` lines.

**`skills/brainstorm/SKILL.md:30,34`** — Two stacked IF-WRAP blocks under `### 2. Read context (light)` (lines 26–36). Bare-line, simple single-action bodies (`READ FILE.`). No list nesting; both collapse to two `READ_IF_EXISTS` lines.

**`skills/vision/SKILL.md:27`** — IF-WRAP with ELSE under `### 2. Read context` (lines 25–31). Line 27 is the condition; lines 28–30 are the THEN body; lines 29–31 are ELSE+END IF. Migration: `READ_IF_EXISTS` with note text. The ELSE body becomes a standalone ELSE-less prose note (no file gate needed for "note conversationally").

**`skills/vision/SKILL.md:35`** — IF-WRAP with ELSE under `### 3. Check for existing VISION.md` (lines 33–39). Line 35 is the condition; the THEN body at line 36 differs from the ELSE body at line 38 — genuine two-branch case. Migration: `SET vision_doc = …` + paren-free `IF vision_doc EXISTS THEN … ELSE … END IF`. Data-loss risk on re-runs if skipped.

**`skills/roadmap/SKILL.md:27`** — IF-WRAP with ELSE under `### 2. Read context` (lines 25–31). Same structure as `vision:27`. Migration: `READ_IF_EXISTS`.

**`skills/roadmap/SKILL.md:41`** — IF-WRAP with ELSE under `### 4. Check for existing ROADMAP.md` (lines 39–45). Genuine two-branch case; same pattern as `vision:35`. Migration: `SET roadmap_doc = …` + paren-free `IF roadmap_doc EXISTS THEN … ELSE … END IF`. Data-loss risk on re-runs.

**`skills/arch/SKILL.md:37`** — IF-WRAP with ELSE under `### 2. Read the vision doc as upstream context` (lines 35–41). Bare line; ELSE body is "Proceed without it." Migration: `READ_IF_EXISTS` with note.

**`skills/arch/SKILL.md:43–47`** *(added 2026-05-12 — missed by the original 12-slot inventory)* — BASIC `IF (X) EXISTS THEN ... ELSE ... END IF` block under `### 3. Check for existing ARCHITECTURE.md`. The parens contain prose ("the target path from §1"), **not** an `!`-injection slot, so the substitution defect does not fire — the slot was invisible to the debug report's grep (which scanned for `!`-injection-in-parens specifically). The form itself, however, is the retired BASIC anti-pattern: parens around the condition + two-word `END IF`. Migration: `SET arch_doc = !\`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture\`` + lean paren-free `IF arch_doc EXISTS THEN … ELSE … ENDIF`. The `$ARGUMENTS=directory` nuance from step 1 is preserved as a parenthetical inside the THEN body.

**`skills/build/SKILL.md:73`** — IF-WRAP slot at line 73 inside a stylistic ` ```text … ``` ` fence (lines 72–80). The outer numbered step context is the prose at line 70. Matrix N ✅ (2026-05-12 rerun) confirms fences do **not** affect substitution; the slot was singly broken (paren-wrap only). The migration replaces the IF-WRAP with the lean `SET` + paren-free `IF pre_commit EXISTS THEN … ELSE IF require_pre_commit == "true" THEN … ENDIF` form per Decision 4 reframe. The fence is stylistic and may be kept or dropped — the user chose drop during the 2026-05-12 lean-form refinement session.

**`skills/build/SKILL.md:106`** — IF-WRAP slot at line 106 inside a second ` ```text … ``` ` fence (lines 105–113), under `### 5. Completion gate`. Same structure as line 73; same migration approach with `pre_completion` / `require_pre_completion` keys.

**`skills/research/SKILL.md:99,103`** — Two stacked IF-WRAP blocks indented 3 spaces under numbered step `1.` at `### 6. Phase 2 — Alignment Validation` (lines 93–105). The IND-IF wrapper shape: the `IF (` is indented under the step number. Migration: replace both IF-WRAP blocks with two `READ_IF_EXISTS` directives at the same indentation (matrix pattern Z confirms indented directives substitute). The surrounding numbered step header on line 97 and the prose continuation on line 106 remain unchanged.

### Convention surfaces

**`ARCHITECTURE.md:279–324`** — `### Logic-Flow Conventions` section. Current text establishes `IF (X) EXISTS THEN` as the locked idiom, provides inline and multi-step block examples, and closes with "This idiom is enforced by `meta-skill` and `meta-agent` validation checklists". The entire section (lines 279–324) is the primary rewrite target. The section heading is at line 279 (not 281 as cited in the spec's current-state paragraph — line 281 is the first body paragraph). Both numbers refer to the same section; the plan should target line 279 as the section start.

**`ARCHITECTURE.md:326–343`** — `### Substitution Conventions` section. Current text lists three sigils and five rules. Rule 5 ("Eager vs. deferred timing") covers timing but does not mention wrapper sensitivity. A sixth rule must be added: `!`-injection slots must not appear inside `(...)` on the same line.

**`skills/meta-skill/SKILL.md:104`** — Checklist item under `**Scripting Layer (when present)**`: "In-prompt existence/absence gates around `!`-injected paths use the BASIC-style idiom from `ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions (`IF (X) EXISTS THEN ... END IF`, ...)." This is the item the spec flips to the new directive-vocabulary rule.

**`skills/meta-agent/SKILL.md:125`** — Checklist item under `**Logic-Flow Idiom (when the agent body uses path gates)**`: identical content to `meta-skill:104`. Same flip required.

### Matrix fixture

**The project-local `subtest` fixture under `.claude/` (its `SKILL.md`)** — Current `name: subtest`, `description:` is a multi-line block describing the 26-pattern (A–Z) wrapper test. (Relocated by spec 014 to the top-level `skills/meta-matrix/` family.) Patterns U–Z (lines 110–144) are present and test the proposed directive vocabulary:

- U (line 120): `READ_IF_EXISTS !... — note`
- V (line 124): `RUN_IF_EXISTS !... — note`
- W (line 128): `SET name = !...`
- X (line 132): `DO_IF_EXISTS !...:` + numbered list
- Y (line 138): `1. READ_IF_EXISTS !... — note`
- Z (line 144): indented `READ_IF_EXISTS !...` under a numbered step

The spec says U–Z all return ✅ in the post-spec run. The spec also says this skill is renamed to `meta-matrix` (project-local rename under `.claude/`: `subtest` → `meta-matrix`; later relocated by spec 014 to the top-level `skills/meta-matrix/` family); the `name:` frontmatter key and `description:` block must be updated on rename. All 26 sentinel rows (A–Z) are preserved verbatim per the spec's acceptance criteria.

### Debug report

**`docs/debug/20260512-skill-bash-substitution-wrappers.md`** — 432 lines. The "Resolved by spec 011" footer attaches after line 432. The body is preserved verbatim. The footer text per the spec: "Resolved by spec 011 — see `ARCHITECTURE.md` → Substitution Conventions and `ARCHITECTURE.md` → Logic-Flow Conventions."

### Test runner

**`skills/meta-test/scripts/run.sh`** — Exists. Aggregate runner; sources `tests/*.sh` from repo root.

**`tests/jimconf.sh`**, **`tests/jimfile.sh`**, **`tests/metatest.sh`** — All three present in `tests/`. These are the test files the spec requires to pass without modification.

## Local Patterns

### Exhaustive historical artifact survey

Grep for `IF (!` across `docs/specs/**/*.md`, `docs/specs/**/*.md` (plan + research included), and `docs/brainstorms/**/*.md`:

**Copy-from examples (must be rewritten to directive vocabulary):**

- `docs/specs/jim/010-build-hooks/plan.md:110` — Inside a fenced `text` block under `### skills/build/SKILL.md — gate block template`. The section heading at line 105 says "Both gates share this exact shape"; the block is the prescriptive pattern used to build the current `build/SKILL.md` gates. This is an instructional pattern reference, not a forensic record; it must be rewritten to `DO_IF_EXISTS` syntax.
- `docs/brainstorms/20260505-file-resolver-conventions-audit.md:86` — Inside a fenced code block under `**Rewrite — single-action, inline (`skills/spec/SKILL.md:34-38`):**`. This is a proposed example from the design phase of spec 009. It illustrates the (now-broken) idiom as the intended fix. Must be rewritten to `READ_IF_EXISTS`.
- `docs/brainstorms/20260505-file-resolver-conventions-audit.md:94` — Inside a fenced code block under `**Rewrite — multi-step + ELSE (`skills/build/SKILL.md:92`, after D4):**`. Same classification as line 86. Must be rewritten to `DO_IF_EXISTS`.

**Forensic record (body preserved, annotation only):**

- `docs/debug/20260512-skill-bash-substitution-wrappers.md:16` — Reproduction literal in the Error Analysis section.
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:21` — Observed behavior description.
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:40–42` — Reproduction table rows C_WRAPPED, D_FULL, E_JIMLIKE.
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:275,279` — Migration example "Before" block (Example 1).
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:298` — Migration example "Before" block (Example 2).
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:319` — Migration example "Before" block (Example 3).
- `docs/debug/20260512-skill-bash-substitution-wrappers.md:347,351` — Migration example "Before" block (Example 4).

All debug-doc occurrences are inside fenced code blocks or inline-code spans that document the bug; they are the forensic record. The spec requires the body to be preserved verbatim and only a footer appended.

No hits found in `docs/specs/jim/*/spec.md` or `docs/specs/jim/*/research.md` other than the single plan.md hit above.

### Inventory blind-spot: substitution-safe paren-wrap (added 2026-05-12)

The debug report's twelve-slot inventory (rows #3–#14) was assembled by grepping for `IF (!` — `!`-injection inside parens specifically. Any BASIC `IF (X) EXISTS THEN ... END IF` block whose `X` is *prose* (not an `!`-injection slot) was invisible to that grep. One production site fell into this blind spot:

- `skills/arch/SKILL.md:43–47` — `IF (the target path from §1) EXISTS THEN ... END IF`. The paren contents reference a name resolved in step 1, not a `!`-injection. Substitution-safe (no defect fires), but uses the retired BASIC form (parens + two-word `END IF`) that the post-011 directive vocabulary replaces.

The convention codification ACs covered this implicitly (the directive table at `ARCHITECTURE.md:283–289` does not include `IF (X) EXISTS THEN ... END IF` in any form, so its use is outside the post-011 convention regardless of the paren contents). The repro-spot-check AC at `spec.md:64` did not — it greps only for `IF (!\`bash …\`)`. The extended AC adds an `arch/SKILL.md` paren-free check (`grep -nE 'IF \(|END IF'` returns zero) to close the gap.

### Annotation gap in historical artifacts

Original spec 011 tasks 18 and 19 migrated the two "Rewrite" examples in `docs/brainstorms/20260505-file-resolver-conventions-audit.md` (lines 86 + 94). The same brainstorm's D1 decision body (lines 43–47) and Gate-convention keyword table (lines 67–81), the sibling brainstorm `docs/brainstorms/20260505-bash-scripts-in-meta.md` (lines 76, 189), and `docs/specs/jim/001-meta/spec.md:123` were left without the "superseded by spec 011" annotation that spec 011's "Historical artifacts" AC calls for. These are forensic mentions (descriptions of historical decisions / planning prescriptions), not active prescriptions, so the body is preserved — but the annotation closes the AC.

### Test framework conventions

The project uses a plain-bash test framework defined in `skills/meta-test/scripts/testlib.sh`. Test files live in `tests/`. Each file defines `case_<name>_<scenario>()` functions. The runner at `skills/meta-test/scripts/run.sh` globs `tests/*.sh` and runs all cases. This refactor touches no bash scripts (per the spec's Out of Scope), so no new tests are written. The acceptance criterion is that the existing three test files (`tests/jimconf.sh`, `tests/jimfile.sh`, `tests/metatest.sh`) pass without modification.

## Security & Performance

**No fenced-code structural risk at `build/SKILL.md:73,106` (reframed 2026-05-12).** Matrix N ✅ (2026-05-12 rerun) and matrix O ✅ confirmed that ` ``` ` fenced code blocks and 4-space indented blocks do **not** suppress `!`-injection. Only inline backticks (matrix P ❌) literal-quote a slot. The two production slots inside the `text`-fenced blocks were singly broken — the `IF (...)` paren-wrap was the only defect. Removing the paren-wrap via the lean form (`SET` + paren-free `IF … THEN … ELSE IF … == "true" THEN … ENDIF`) is sufficient to make both slots substitute correctly. The fences are visual-rendering choices, not structural; the user chose to drop them during the lean-form refinement session for consistency with the surrounding skill body. Either form (with or without fence) would be correct.

**Numbered-list nesting at `research/SKILL.md:99,103`.** The two IND-IF slots are indented 3 spaces under step `1.` The migration keeps them indented (matrix Z confirms indented directives substitute). However, the `READ_IF_EXISTS` lines will appear as continuation-paragraph content of the numbered step, not as a sub-list. If the architect keeps the 3-space indent, the visual structure is preserved. If the indent is removed, step 1's body becomes "Read strategic constraints, if present:" followed by two bare-line directives — visually a step with no indented continuation. Either is semantically valid per the spec; note this as a stylistic choice for the plan.

**No automated static enforcement.** The spec explicitly rejects `/jim:meta-lint`. The four manual enforcement surfaces (ARCHITECTURE.md guidance, meta-skill/meta-agent checklists, clean historical examples, manual `meta-matrix` rerun) are the full coverage. Any regression must be caught by a human author re-running `meta-matrix` after touching the convention.

**Validation checklists actively enforce the broken idiom.** Until `meta-skill/SKILL.md:104` and `meta-agent/SKILL.md:125` are updated, any new skill authored between today and commit will be validated against the broken convention. The convention update and the checklist update must land in the same commit.

## Recommendations

This is a refactor with no external dependencies. Phase 1 (external intelligence) is not triggered.

Key observations for the architect:

1. **The build/SKILL.md fenced-block problem is the highest structural risk.** The spec references "NUM-IF" at lines 73 and 106, but the actual slots are inside `` ```text `` fences. If fenced-code suppresses `!`-injection (matrix N ❌), the current slots are doubly broken (paren AND fence). The plan must explicitly remove the fences and replace the entire block with a bare-line `DO_IF_EXISTS` directive (or move the directive outside the fence context). The surrounding prose at lines 70–71 and 82+ can provide context without a fence wrapper.

2. **Five of the 12 slots have ELSE branches; only two require `SET` + paren-free IF.** The two genuine two-branch cases (`vision/SKILL.md:35` and `roadmap/SKILL.md:41`) both carry data-loss risk on re-runs if left broken. These are highest-priority behavioral fixes. The other ELSE branches at `vision:27`, `roadmap:27`, and `arch:37` all have simple "note conversationally" ELSE bodies that can be dropped or kept as plain prose — they don't need the `SET` + paren-free `IF` pattern.

3. **The matrix rename from `subtest` to `meta-matrix` has no code dependencies.** The rename is a directory move plus frontmatter text edit; no script references the path. However, the `ARCHITECTURE.md` reference to the fixture will be a new addition (currently `ARCHITECTURE.md` does not reference the pre-rename `subtest` location under `.claude/`), so the text change is additive. (Spec 014 later relocated the fixture from `.claude/` to the top-level `skills/meta-matrix/` family.)

4. **Historical artifacts: 3 copy-from examples must be rewritten; 8 forensic occurrences preserved.** The only spec/plan hit is `010-build-hooks/plan.md:110`. The two brainstorm hits are both inside fenced code blocks as design examples. None are forensic — all three must be updated to the directive vocabulary.

**Strategic alignment:** This refactor directly serves the Vision's goal of maintaining architectural consistency. Twelve silently-failing gates mean `/jim:plan`, `/jim:spec`, and `/jim:research` routinely skip the locked-constraint reads that keep the LLM grounded. Fixing them restores the SDLC integrity the toolchain is built around. The change aligns with ARCHITECTURE.md's Substitution Conventions "script integrity" rule (every slot must resolve; silent failure violates the intent of that rule even if the letter does not currently catch it).

## Open Questions

- **Matrix pattern N result** — Were the `build/SKILL.md` fenced-code slots already double-broken (paren + fence), or does the `text`-fence label exempt them from code-fence suppression? The plan must specify whether to remove the fences or preserve them in the `DO_IF_EXISTS` migration. If pattern N is ❌, the fences must go. If the `text` label is treated differently from `` ```bash `` (possible — the preprocessor may only suppress language-tagged fences), the fence can stay.

- **`research/SKILL.md:99,103` indentation style** — Matrix Z is ✅ per the spec. Either indented or un-indented is valid. The plan should pick one and state it; this is a stylistic choice, not a correctness issue.

- **`vision/SKILL.md:27` and `roadmap/SKILL.md:27` ELSE bodies** — The ELSE bodies are "note conversationally" instructions that do not depend on file existence. After migrating the IF gate to `READ_IF_EXISTS`, the ELSE body has no home. Options: (a) keep a follow-on `ELSE … END IF` block using the paren-free syntax but with no SET binding (since `READ_IF_EXISTS` doesn't bind a name), or (b) convert the ELSE body to a standalone prose sentence ("If the file is absent, note it conversationally"). The debug doc's migration Example 3 only covers the `SET`-based two-branch case; the single-read-with-fallback-note case needs a canonical form in the plan.
