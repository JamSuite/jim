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

> **2026-05-13 amendment:** Empirical `/jim:build` and `/jim:spec` runs exposed a *semantic-layer* leak in the EXISTS-family directive vocabulary — directive names containing "EXISTS" primed the executing agent to defensively `test -e` / `test -f` on paths the resolver had already verified. The empty-RHS readback under D2's path-or-empty resolver (`SET pre_commit = `) compounded the issue, reading as syntactically incomplete to a human (and potentially to a future LLM). This spec is amended in place to retire the EXISTS-family entirely and adopt a sentinel-based form: `SET <name> = !\`bash …\`` followed by `IF <name> != "NOT_FOUND" THEN … ENDIF`. The resolver (`jimfile.sh get`) now returns the literal string `NOT_FOUND` when a path-typed key resolves to a missing file (reverses commit `3fd1811`'s path-or-empty). See `docs/brainstorms/20260513-directive-vocab-exists-trap.md` for the full design rationale and `docs/brainstorms/20260505-file-resolver-conventions-audit.md` for the predecessor decisions D1/D2/D8 this amendment supersedes. Acceptance criteria below reflect the post-amendment shape; tasks targeting the original `READ_IF_EXISTS`/`RUN_IF_EXISTS`/`DO_IF_EXISTS`/`IF X EXISTS THEN` family are re-executed under the new vocabulary. Status stays `approved` — convention codification AC and migration AC remain load-bearing; only the target shape changes.

## Overview
Retire the BASIC-style `IF (X) EXISTS THEN ... END IF` idiom *and* the interim `READ_IF_EXISTS`/`RUN_IF_EXISTS`/`DO_IF_EXISTS`/`IF X EXISTS THEN` directive family (the 2026-05-13 amendment retires the latter; the original 011 retired the former). The post-amendment convention is a single sentinel-based form: bind any resolver call with `SET <name> = !\`bash …\``, then gate on it with `IF <name> != "NOT_FOUND" THEN … ELSE IF <other> == "value" THEN … ENDIF`. Markdown indentation is the block delimiter; `ENDIF` is one word; implicit fall-through replaces explicit "Otherwise, skip silently" prose. The `!`-injection slot only ever appears as the right-hand side of a `SET` assignment — never inside `(...)`, never inside a predicate. The change eliminates twelve confirmed silent-failure sites (Tier 1, BASIC) plus sixteen EXISTS-family sites (Tier 2, semantic-layer) across eight production skills, and codifies the wrapper-sensitivity rule across plugin conventions.

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

**Production migration (load-bearing — post-amendment shape: every gate is `SET <name> = !\`…\`` + `IF <name> != "NOT_FOUND" THEN … ENDIF`)**
- [ ] All 16 production gate sites migrated to the sentinel form. Slot-by-slot mapping (numbers reflect post-amendment line positions):
  - [ ] `skills/plan/SKILL.md:53` → `SET arch_doc` + `IF arch_doc != "NOT_FOUND" THEN`
  - [ ] `skills/spec/SKILL.md:33,35` → `SET vision_doc` + `IF vision_doc != "NOT_FOUND" THEN`; `SET arch_doc` + `IF arch_doc != "NOT_FOUND" THEN` (two stacked blocks)
  - [ ] `skills/brainstorm/SKILL.md:30,32` → `SET vision_doc` + `IF vision_doc != "NOT_FOUND" THEN`; `SET roadmap_doc` + `IF roadmap_doc != "NOT_FOUND" THEN` (two stacked blocks)
  - [ ] `skills/vision/SKILL.md:27` → `SET arch_doc` + `IF arch_doc != "NOT_FOUND" THEN`; `:38` → `SET vision_doc` + `IF vision_doc != "NOT_FOUND" THEN ... ELSE ... ENDIF`
  - [ ] `skills/roadmap/SKILL.md:27` → `SET vision_doc` + `IF vision_doc != "NOT_FOUND" THEN`; `:44` → `SET roadmap_doc` + `IF roadmap_doc != "NOT_FOUND" THEN ... ELSE ... ENDIF`
  - [ ] `skills/arch/SKILL.md:37` → `SET vision_doc` + `IF vision_doc != "NOT_FOUND" THEN`; `:48` → `SET arch_doc` + `IF arch_doc != "NOT_FOUND" THEN ... ELSE ... ENDIF`
  - [ ] `skills/build/SKILL.md:73,76` → `SET pre_commit` + `SET require_pre_commit` + `IF pre_commit != "NOT_FOUND" THEN ... ELSE IF require_pre_commit == "true" THEN ... ENDIF` (pre-commit gate)
  - [ ] `skills/build/SKILL.md:106,109` → analogous `pre_completion` / `require_pre_completion` gate
  - [ ] `skills/build/SKILL.md:117,119` → `SET arch_doc` + `IF arch_doc != "NOT_FOUND" THEN` (post-build arch refresh)
  - [ ] `skills/research/SKILL.md:99,101` → two stacked `SET + IF != "NOT_FOUND"` blocks at 3-space indent under step 1 (matrix Z ✅ — indented `SET` substitutes)

**Resolver layer (load-bearing — D2-revised)**
- [ ] `skills/file/scripts/jimfile.sh cmd_get` returns the literal string `NOT_FOUND` when the resolved path is missing on disk (reverses commit `3fd1811`'s path-or-empty). Exit code stays `0` for both the resolved-path and `NOT_FOUND` cases; `1` for unknown key; `2` for malformed invocation.
- [ ] `tests/jimfile.sh` covers `NOT_FOUND` semantics for path-typed keys (default config, `-c` override, file-typed and directory-typed keys, `pre_commit` defaulted-but-missing). The 7 D2 cases that asserted empty string are renamed to `_not_found_when_missing` and assert `"NOT_FOUND"`; a new `case_jimfile_get_returns_not_found_when_file_missing` covers the default-config-empty-dir code path.
- [ ] `skills/file/SKILL.md` examples and Convention prose describe the `NOT_FOUND` return shape.

**Convention codification**
- [ ] `ARCHITECTURE.md` → Substitution Conventions keeps the "wrapper sensitivity" rule (still load-bearing — Tier 1 BASIC anti-pattern depends on it).
- [ ] `ARCHITECTURE.md` → Logic-Flow Conventions has the sentinel-based table covering `SET <name> = !\`bash …\`` and `IF <name> != "NOT_FOUND" THEN … ELSE IF <name> == "value" THEN … ENDIF` (markdown indentation as block delimiter, `ENDIF` one word, no `DO:` / `DONE`, implicit fall-through). Two anti-patterns are explicitly called out: **Tier 1** retired BASIC `IF (X) EXISTS THEN` (silent substitution failure); **Tier 2** retired EXISTS-family directive vocabulary (`READ_IF_EXISTS` / `RUN_IF_EXISTS` / `DO_IF_EXISTS` / `IF <name> EXISTS THEN` — semantic-layer EXISTS-trap).
- [ ] ARCHITECTURE.md cites both `docs/debug/20260512-skill-bash-substitution-wrappers.md` (Tier 1 defect record) and `docs/brainstorms/20260513-directive-vocab-exists-trap.md` (Tier 2 defect record).

**Validation surfaces**
- [ ] `skills/meta-skill/SKILL.md` validation checklist line at `:104` reads: gates use `SET <name> = !\`bash …\`` + `IF <name> != "NOT_FOUND" THEN … ENDIF`; `!`-injection slot is always the RHS of a `SET`; both anti-patterns flagged.
- [ ] `skills/meta-agent/SKILL.md` validation checklist line at `:125` mirrors the meta-skill update.

**Regression matrix**
- [ ] `.claude/skills/subtest/` renamed to `.claude/skills/meta-matrix/`; `name:` and `description:` in the SKILL.md frontmatter updated; sentinel rows A–Z preserved verbatim.
- [ ] `ARCHITECTURE.md` → Substitution Conventions (or a sibling subsection) references `.claude/skills/meta-matrix/` as the manual regression fixture to rerun when the substitution convention is touched, with the instruction "quit and relaunch Claude Code from the repo root so the matrix skill is discovered at session start."
- [ ] Matrix patterns U–Z all return ✅ in the post-migration rerun. The dated results are recorded in the plan (or a results file linked from the plan) so future readers can verify the directive vocabulary's status at lock-in time.

**Historical artifacts (instructional/example contexts)**
- [ ] Under `docs/specs/jim/*/spec.md`, `docs/specs/jim/*/plan.md`, `docs/specs/jim/*/research.md`, and `docs/brainstorms/**/*.md`: every example or instruction that quotes the `IF (X) EXISTS THEN` idiom is rewritten to the directive vocabulary. Forensic descriptions of historical decisions (e.g., "we originally used the BASIC IF idiom because …") are preserved with the original shape but flagged as superseded.
- [ ] `docs/debug/20260512-skill-bash-substitution-wrappers.md` body is preserved verbatim (it is the forensic record). A closing "Resolved by spec 011 — see ARCHITECTURE.md → Substitution Conventions and ARCHITECTURE.md → Logic-Flow Conventions" footer is appended.

**Original repro must clear (Tier 1 BASIC) and Tier 2 EXISTS-family fully retired from production**
- [ ] Launching `/jim:plan docs/specs/jim/<any approved spec>/spec.md` in a fresh Claude Code session loads `skills/plan/SKILL.md` with the `!`-injection slot resolved to the real ARCHITECTURE.md path (no literal `IF (!\`bash …\`)` text in the loaded body).
- [ ] Equivalent spot-check for `/jim:spec`, `/jim:research`, `/jim:vision`, `/jim:roadmap`, `/jim:brainstorm`, `/jim:arch`, `/jim:build`: no literal `IF (!\`bash …\`)` text in the loaded skill body.
- [ ] `grep -rnE 'READ_IF_EXISTS|RUN_IF_EXISTS|DO_IF_EXISTS|IF [a-z_]+ EXISTS THEN' skills/` returns zero matches across all production skills (Tier 2 retirement).
- [ ] `grep -nE 'IF \(|END IF' skills/arch/SKILL.md` returns zero matches (Tier 1 prose-in-parens variant — still load-bearing).
- [ ] **Post-amendment EXISTS-trap probe** (not a merge gate; observe-and-decide): in a clean Claude Code session, invoke `/jim:spec` against a project where `VISION.md` and/or `ROADMAP.md` is absent. The agent does NOT perform a defensive `test -e` / `test -f` on the strategic-doc paths after the resolver substitution. If the prose-mention hallucination on `ROADMAP.md` (problem 3 of the 20260513 brainstorm) still reproduces, scope as a follow-up spec per D4.

**Historical-annotation hygiene**
- [ ] `docs/brainstorms/20260505-file-resolver-conventions-audit.md` carries a "Superseded by spec 011 (2026-05-13 amendment)" annotation near the D1 decision body, D2, D8, and the Gate convention keyword table. Body preserved verbatim. (D1's directive vocabulary and D2's path-or-empty semantics are *both* superseded; D8's empty-slot no-op contract is no longer load-bearing.)
- [ ] `docs/brainstorms/20260505-bash-scripts-in-meta.md` carries the same annotation near its references to the BASIC dialect (lines 76, 189). Body preserved verbatim.
- [ ] `docs/specs/jim/001-meta/spec.md` line 123 (or its containing bullet) carries the same annotation. Body preserved verbatim.
- [ ] `docs/debug/20260512-skill-bash-substitution-wrappers.md` footer reads "Resolved by spec 011 — amended 2026-05-13 per `docs/brainstorms/20260513-directive-vocab-exists-trap.md`." Body preserved verbatim.
- [ ] `docs/specs/jim/009-jimfile/spec.md` line 65 describes `get`'s return shape as path-or-`NOT_FOUND`; D8 reference flagged as superseded. `docs/specs/jim/009-jimfile/plan.md` line 61 carries a one-line trailing annotation noting the 2026-05-13 amendment.

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
