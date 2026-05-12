---
title: "Two-family logic-flow convention: directive vocabulary + lean paren-free IF for !-injection gates"
type: refactor
group: "jim"
id: "011"
status: approved
origin:
  - "docs/debug/20260512-skill-bash-substitution-wrappers.md"
---

# 011 Two-family logic-flow convention: directive vocabulary + lean paren-free IF for !-injection gates

## Overview
Retire the BASIC-style `IF (X) EXISTS THEN ... END IF` idiom — which silently suppresses `!`-injection because Claude Code's preprocessor rejects the leading `(` — in favor of a two-family convention: (a) a small directive vocabulary (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`, `SET`) for the common single-action and multi-step gates, and (b) a lean paren-free `IF X EXISTS THEN … ELSE IF X == "value" THEN … ENDIF` block for genuine branching (markdown indentation as the block delimiter, `ENDIF` one word, implicit fall-through, `==` for string-literal comparisons). The post-011 convention is *lighter* than BASIC, not a wholesale BASIC reintroduction. The change eliminates twelve confirmed silent-failure sites across eight production skills and codifies a "no `!`-injection inside parens" rule across plugin conventions.

## Refactor Rationale
- **Motivation:** Twelve `IF (!\`bash …\`) EXISTS THEN` slots across jim's production skills (`docs/debug/20260512-skill-bash-substitution-wrappers.md` → Inventory rows #3–#14) silently fail to substitute. The literal text reaches the LLM's context with backticks intact; bash never runs; downstream behavior hallucinates or asks the user for help. This is a *third* failure mode of `!`-injection — distinct from the angle-bracket parser error (loud) and the `$(...)` permission gate (loud). Severity ranges from Tier-1 locked-constraint violations (every `/jim:plan`, `/jim:spec`, `/jim:research` run silently skips ARCHITECTURE.md / VISION.md reads) to Tier-2 data-loss risk (vision/roadmap differential-update gates silently take the "fresh creation" branch and overwrite existing docs). The current `ARCHITECTURE.md` → Logic-Flow Conventions section and the `meta-skill` / `meta-agent` validation checklists actively *require* the broken idiom — the convention as written produces the bug.

- **Current State:** `ARCHITECTURE.md:281–324` documents `IF (X) EXISTS THEN`/`ELSE`/`END IF` as the locked idiom; `skills/meta-skill/SKILL.md:104` and `skills/meta-agent/SKILL.md:125` enforce it as a validation requirement. Twelve production slots use the broken shape: `skills/plan/SKILL.md:53`, `skills/spec/SKILL.md:33,37`, `skills/brainstorm/SKILL.md:30,34`, `skills/vision/SKILL.md:27,35`, `skills/roadmap/SKILL.md:27,41`, `skills/arch/SKILL.md:37`, `skills/build/SKILL.md:73,106` (numbered+IF), `skills/research/SKILL.md:99,103` (indented IF). No automated check exists. A test scaffold at `.claude/skills/subtest/SKILL.md` characterizes 26 wrapper patterns (A–Z); matrix patterns U–Z verify the proposed directive vocabulary substitutes safely. The matrix has been run; U–Z all return ✅ (record the dated results in the plan).

- **Desired State:** Every `!`-injection slot lives at end-of-line, preceded only by an allowed directive prefix or by nothing at all. Genuine branching uses `SET <name> = !\`bash …\`` to hoist the substitution onto a paren-free surface, then a lean paren-free `IF <bound-name> EXISTS THEN ... ELSE IF <bound-name> == "value" THEN ... ENDIF` block — markdown indentation under each keyword is the block body, `ENDIF` (one word) terminates the chain, and implicit fall-through replaces explicit "Otherwise, skip silently" prose. The four-directive vocabulary covers all current production gate shapes (verified by survey: `READ_IF_EXISTS` covers the 9 single-action reads; the lean `IF`/`ELSE IF` form covers the 2 multi-step pre-commit gates with their `require_*` halt branches; `SET` + paren-free `IF` covers the 2 vision/roadmap differential-update branches; `RUN_IF_EXISTS` is kept for forward symmetry with `DO_IF_EXISTS`). Regression coverage relies on four complementary surfaces: (a) the updated `ARCHITECTURE.md` sections (authoritative reader-time guidance, with the old idiom flagged as anti-pattern); (b) the meta-skill / meta-agent validation checklists (LLM-checked at author time, where new SKILL.md content actually comes from); (c) clean historical examples across specs/plans/research/brainstorms (no broken patterns to copy from); (d) the renamed `meta-matrix` fixture (`.claude/skills/subtest/` → `.claude/skills/meta-matrix/`), manually rerun when the substitution convention is touched. No automated lint is added — the risk surface is fully covered by the above without the maintenance cost of a bash-grep enforcer that has to distinguish inline-code literals from real violations.

- **Affected Systems:**
  - `ARCHITECTURE.md` → Substitution Conventions (add wrapper-sensitivity rule + "no `!`-injection inside parens"), Logic-Flow Conventions (replace BASIC IF idiom with directive table)
  - Eight production skills with confirmed-defective slots: `skills/plan/`, `skills/spec/`, `skills/research/`, `skills/build/`, `skills/vision/`, `skills/roadmap/`, `skills/arch/`, `skills/brainstorm/`
  - Validation surfaces: `skills/meta-skill/SKILL.md:104` (flip checklist), `skills/meta-agent/SKILL.md:125` (flip checklist)
  - Project-local matrix fixture: `.claude/skills/subtest/` → `.claude/skills/meta-matrix/` (rename + retain)
  - Historical artifacts (instructional/example contexts only): `docs/specs/jim/*/spec.md`, `docs/specs/jim/*/plan.md`, `docs/specs/jim/*/research.md`, `docs/brainstorms/**/*.md`
  - Forensic record (annotation only, body preserved): `docs/debug/20260512-skill-bash-substitution-wrappers.md` gets a closing "Resolved by spec 011" footer

## Acceptance Criteria

**Production migration (load-bearing)**
- [ ] All 12 confirmed `IF-WRAP` slots from the debug-report Inventory (rows #3–#14) migrated to a directive form. Slot-by-slot mapping:
  - [ ] `skills/plan/SKILL.md:53` → `READ_IF_EXISTS`
  - [ ] `skills/spec/SKILL.md:33,37` → `READ_IF_EXISTS` (two slots)
  - [ ] `skills/brainstorm/SKILL.md:30,34` → `READ_IF_EXISTS` (two slots)
  - [ ] `skills/vision/SKILL.md:27` → `READ_IF_EXISTS`; `:35` → `SET vision_doc = …` + paren-free `IF vision_doc EXISTS THEN ... ELSE ... ENDIF`
  - [ ] `skills/roadmap/SKILL.md:27` → `READ_IF_EXISTS`; `:41` → `SET roadmap_doc = …` + paren-free `IF roadmap_doc EXISTS THEN ... ELSE ... ENDIF`
  - [ ] `skills/arch/SKILL.md:37` → `READ_IF_EXISTS`
  - [ ] `skills/build/SKILL.md:73,106` → `SET pre_commit` + `SET require_pre_commit` (or `pre_completion` / `require_pre_completion`) + lean `IF pre_commit EXISTS THEN ... ELSE IF require_pre_commit == "true" THEN ... ENDIF` block
  - [ ] `skills/research/SKILL.md:99,103` → `READ_IF_EXISTS` (un-indent under the numbered step or keep indented per matrix Z result)

**Convention codification**
- [ ] `ARCHITECTURE.md` → Substitution Conventions adds a "wrapper sensitivity" rule: `!`-injection slots must not appear inside `(...)` on the same line; the preprocessor silently leaves the literal text in place.
- [ ] `ARCHITECTURE.md` → Logic-Flow Conventions replaces the `IF (X) EXISTS THEN` keyword table with a directive table covering `READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`, `SET`, and the lean paren-free `IF X EXISTS THEN ... ELSE IF X == "value" THEN ... ENDIF` block form (markdown indentation as block delimiter, `ENDIF` one word, no `DO:`/`DONE`, implicit fall-through). The retired `IF (X) EXISTS THEN` BASIC shape is explicitly called out as a documented anti-pattern, alongside the heavier interim form (`DO:`/`DONE`/`END IF` two words, explicit fall-through prose).
- [ ] Both ARCHITECTURE.md sections cite `docs/debug/20260512-skill-bash-substitution-wrappers.md` as the source defect record.

**Validation surfaces**
- [ ] `skills/meta-skill/SKILL.md` validation checklist line at `:104` flips from "use the BASIC IF idiom" to "no `!`-injection slot inside `(...)`; every slot is bare-line, preceded by an allowed directive prefix, or the right-hand side of a `SET` assignment."
- [ ] `skills/meta-agent/SKILL.md` validation checklist line at `:125` mirrors the meta-skill update.

**Regression matrix**
- [ ] `.claude/skills/subtest/` renamed to `.claude/skills/meta-matrix/`; `name:` and `description:` in the SKILL.md frontmatter updated; sentinel rows A–Z preserved verbatim.
- [ ] `ARCHITECTURE.md` → Substitution Conventions (or a sibling subsection) references `.claude/skills/meta-matrix/` as the manual regression fixture to rerun when the substitution convention is touched, with the instruction "quit and relaunch Claude Code from the repo root so the matrix skill is discovered at session start."
- [ ] Matrix patterns U–Z all return ✅ in the post-migration rerun. The dated results are recorded in the plan (or a results file linked from the plan) so future readers can verify the directive vocabulary's status at lock-in time.

**Historical artifacts (instructional/example contexts)**
- [ ] Under `docs/specs/jim/*/spec.md`, `docs/specs/jim/*/plan.md`, `docs/specs/jim/*/research.md`, and `docs/brainstorms/**/*.md`: every example or instruction that quotes the `IF (X) EXISTS THEN` idiom is rewritten to the directive vocabulary. Forensic descriptions of historical decisions (e.g., "we originally used the BASIC IF idiom because …") are preserved with the original shape but flagged as superseded.
- [ ] `docs/debug/20260512-skill-bash-substitution-wrappers.md` body is preserved verbatim (it is the forensic record). A closing "Resolved by spec 011 — see ARCHITECTURE.md → Substitution Conventions and ARCHITECTURE.md → Logic-Flow Conventions" footer is appended.

**Original repro must clear**
- [ ] Launching `/jim:plan docs/specs/jim/<any approved spec>/spec.md` in a fresh Claude Code session loads `skills/plan/SKILL.md` with the `!`-injection slot at line 53 resolved to the real ARCHITECTURE.md path (no literal `IF (!\`bash …\`)` text in the loaded body).
- [ ] Equivalent spot-check for `/jim:spec`, `/jim:research`, `/jim:vision`, `/jim:roadmap`, `/jim:brainstorm`, `/jim:arch`, `/jim:build`: no literal `IF (!\`bash …\`)` text in the loaded skill body. (One-line grep against the loaded transcript suffices.)

**Mandatory for refactor type**
- [ ] Existing tests pass without modification (`bash skills/meta-test/scripts/run.sh` exits zero on `jimconf.sh`, `jimfile.sh`, `metatest.sh`).

**Delivery shape**
- [ ] All convention, checklist, skill-migration, matrix-rename, and history-migration changes land in **one bundled commit** (or one bundled PR with internal commits if the architect's plan separates structural from behavioral changes per Tidy First — convention/checklist update first, behavioral migrations after, in the same PR). No partial rollout.

## Out of Scope
- **Claude Code's preprocessor itself.** This spec changes the convention skill authors follow, not Anthropic's parser behavior. If Anthropic later relaxes the leading-`(` rejection, the directive vocabulary remains valid — it's a stricter discipline.
- **Bash scripts under `skills/*/scripts/`.** Inert with respect to `!`-injection (the script bodies are not LLM-loaded). The `bash` invocation references inside `!`…`` slots in SKILL.md *do* get migrated as part of the slot rewrite, but the scripts themselves are untouched.
- **`docs/debug/**` body content other than the appended resolution footer.** Forensic records preserved as written.
- **Generalizing the directive vocabulary beyond `!`-injection gates.** No new directives for non-`!`-injection control flow. No `WHEN`, `ASSERT_EXISTS`, `STOP_IF_MISSING`, `WRITE_TO` — survey confirmed zero existing usage and no current need.
- **Migrating documentation references in inline-code (e.g., `` `!`-injection inputs` `` in `skills/meta-skill/SKILL.md:104–106`).** These depend on inline-code suppression (matrix pattern P) and are intentional literals. They are *not* slots and should remain as inline-code references in the post-migration tree.
- **Automated static enforcement (e.g. a `/jim:meta-lint` slash command or pre-commit bash-grep).** Considered and rejected. The four enforcement surfaces above (ARCHITECTURE.md guidance, meta-skill/meta-agent author-time checklists, clean historical examples, manual `meta-matrix` rerun) cover the risk surface without the maintenance cost of a bash linter that has to distinguish inline-code literals from real `IF (!\`bash …\`)` violations. If a regression ever slips through despite these surfaces, this exclusion can be revisited as a follow-up spec — it is not a one-way door.

## Open Questions
- [ ] Matrix pattern Z (indented directive under a numbered step) — confirm with the user whether the post-migration `skills/research/SKILL.md:99,103` slots stay indented or un-indent to top-level. The migration shape depends on Z's outcome; if Z is ✅ either form is valid and the choice is stylistic.
