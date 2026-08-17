# Brainstorm: Directive-vocabulary EXISTS-trap & sentinel-based gate convention

*2026-05-13*

## Topic

Spec 011 introduced a directive vocabulary (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`, `SET … = !\`…\``, paren-free `IF X EXISTS THEN … ELSE IF X == "value" THEN … ENDIF`) to retire the silently-failing BASIC paren-wrap idiom (`IF (!\`…\`) EXISTS THEN`). Substitution-layer fix landed; meta-matrix rows U–Z, AA, BB, and CC–FF all ✅. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.) But empirical `/jim:build` and `/jim:spec` runs on 2026-05-13 expose a *semantic-layer* leak: the literal word "EXISTS" in directive names invites the executing agent to re-verify file existence with `test -e` / `test -f`, even after the resolver (post-D2) has already done that check.

This brainstorm resolves the vocabulary to a new shape (`SET <name> = !\`…\`` + `IF <name> != "NOT_FOUND" THEN`), reverses commit `3fd1811`'s D2 path-or-empty in favor of path-or-`NOT_FOUND`, and enumerates every site that needs migration.

## Problem

1. **EXISTS-trap.** Directive names containing "EXISTS" prime the executing agent to defensively re-check file existence on already-resolved paths.
   - `/jim:build` completion gate (2026-05-13): after `SET pre_completion = !\`…jimfile.sh get pre_completion\``, the coder ran `test -e /home/adri/projects/JamSuite/repos/jim/pre-completion.sh` on a *guessed* path instead of trusting the empty SET.
   - `/jim:spec` strategic-context (2026-05-13): after `READ_IF_EXISTS !\`…jimfile.sh get vision\``, the agent ran `test -f /workspaces/korswerk/VISION.md` on the already-resolved path. Redundant but harmless.

2. **Empty-RHS visual ambiguity.** Under D2 (`get` returns path-or-empty), the substituted readback when a path-typed key resolves to a missing file is `SET pre_commit = ` (nothing after the `=`, then newline). Mechanically correct under meta-matrix CC–FF (D8 empty-no-op contract), but visually broken-looking — the line reads as malformed/incomplete to a human, and may read the same way to a future LLM that interprets the SKILL.md text differently. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)

3. **Prose-mention extrapolation.** Same `/jim:spec` run: agent ran `test -f /workspaces/korswerk/ROADMAP.md` despite **no resolver call for roadmap** in `skills/spec/SKILL.md`. Trigger was the prose phrase "vision/roadmap alignment" at line 128 of step 8. May be downstream of (1) — the EXISTS-trap could have primed defensive checks that generalized to all strategic-doc keys — or independent. Empirically separable only after (1) and (2) are fixed.

## Framing insight

**The consumer of the substituted readback is Claude, not bash.** Bash mechanically executes `SET x = ` (empty assignment) correctly forever — deterministic. But the post-substitution text is *read* by an LLM whose interpretation rules aren't versioned. Today's model handles empty-RHS correctly (meta-matrix CC–FF). Tomorrow's model on the same SKILL.md is a separate empirical question. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)

Primary risk axis: **readback robustness against LLM interpretive drift**, not bash mechanical correctness.

| Readback shape | Best case | Worst case |
| :--- | :--- | :--- |
| Empty-RHS (`SET x = `) | No-op'd cleanly (today) | Future model treats broken-looking syntax as malformed; defensively probes |
| Sentinel + `!=` (`SET x = NOT_FOUND` + `IF x != "NOT_FOUND" THEN`) | Sentinel handled cleanly | Literal string compare — bounded interpretive surface |

The sentinel shape's worst case is bounded by what `!= "NOT_FOUND"` can mean across language frames (all of bash/Python/JS evaluate string inequality identically). The empty-RHS shape's worst case is bounded by what an LLM might decide a syntactically-incomplete line means — wider surface.

## Options weighed

| Question | Options | Picked |
| :--- | :--- | :--- |
| Predicate semantics | A. Keep `EXISTS`, add contract preamble. B. Rename to `IS_SET`. C. Sentinel + `!=`. D. Two-resolver decoupling (`has` subcommand + `==`). | **C** — both branches use the proven `==`/`!=` shape already in `build/SKILL.md` (`require_pre_commit == "true"`). No EXISTS, no IS_SET ambiguity, no broken-looking line. |
| Sentinel string | `False` / `NONE` / `MISSING` / `NOT_FOUND` / `__NOT_FOUND__` | **`NOT_FOUND`** — unambiguous English; doesn't collide with actual boolean usage elsewhere (`== "true"`/`"false"`). |
| Prose-mention hygiene (Problem 3) | (i) Fold into 011 amendment. (ii) Split into new spec. (iii) Park; re-observe after the sentinel change lands. | **(iii) Park.** Hallucination may be downstream of EXISTS-trap and resolve as a side effect. Re-observe before scoping a separate fix. |
| Spec routing | S1 amend 011 in-place / S2 follow-up 014 / S3 pause + bundle as 014 | **S1 amend in-place.** Matches the in-place amendment precedent set by 008-jimconf and 009-jimfile (commit `abd85b1`). Forensic trail reads cleanly: "011 was approved with the EXISTS family; mid-flight amended to the sentinel form on 2026-05-13." |

## Decisions

- **D1 (vocab).** Retire the EXISTS directive family entirely. All gates use the explicit `SET` + `!=` form:

  ```
  SET <name> = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get <key>`
  IF <name> != "NOT_FOUND" THEN
    <indented action>
  ELSE IF <other_name> == "true" THEN
    <indented alternative>
  ENDIF
  ```

  `READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS` are removed. The single-action shorthand (`READ_IF_EXISTS !\`…\` — note`) restructures into the explicit SET + IF + ENDIF block — slightly more verbose, fully symmetric, no special-case directives.

- **D2-revised (resolver).** `jimfile.sh get <key>` for path-typed keys returns the resolved path *if it exists on disk*, else the literal string `NOT_FOUND`. **Reverses commit `3fd1811`'s "path-or-empty" semantics.** Acceptable: `3fd1811` is on `refactor/directive-vocab`, nothing released. Bash callers of `get` migrate from `[ -n "$x" ]` / `[ -z "$x" ]` to `[ "$x" != "NOT_FOUND" ]` / `[ "$x" = "NOT_FOUND" ]`.

- **D3 (spec routing).** Amend spec 011 in place per S1. `spec.md`, `plan.md`, and (if needed) `research.md` are revised on the same `refactor/directive-vocab` branch. Already-executed plan tasks that targeted the EXISTS vocab get unchecked and re-migrated under the new shape.

- **D4 (prose-mention hygiene).** Park. After D1 + D2-revised land, rerun `/jim:spec` (with a project that has no `ROADMAP.md`) and observe whether the `test -f` hallucination persists. If yes → scope a follow-up spec. If no → closed by side effect.

- **D5 (meta-matrix probe).** Add a probe row to `.claude/skills/meta-matrix/SKILL.md` (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`) for the new readback shape: `SET x = NOT_FOUND` + `IF x != "NOT_FOUND" THEN … ENDIF`. Confirms the new gate substitutes correctly under all wrappers tested for U–Z and AA/BB. CC–FF empty-substitution rows stay for historical record but are no longer load-bearing (D8 no-op contract is unused under D2-revised).

- **D6 (validation surfaces & canonical convention).** The `ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions section is the canonical source of truth; its directive table is rewritten to the SET + `!=` form. The retired EXISTS family is flagged as a documented anti-pattern alongside the BASIC `IF (X) EXISTS THEN` shape that spec 011 originally retired. The `meta-skill` and `meta-agent` validation checklists are updated to mirror.

## Gate convention (post-D1)

| Form | Meaning |
| :--- | :--- |
| `SET <name> = !\`bash …\`` | Hoist resolver output to a named variable |
| `IF <name> != "NOT_FOUND" THEN` *(indented body)* | Body runs if a path-typed key resolved to a real path |
| `IF <name> == "true" THEN` *(indented body)* | Body runs if a boolean-typed key is true |
| `ELSE IF <name> == "value" THEN` *(indented body)* | Mirror branch |
| `ELSE` *(indented body)* | Fallback |
| `ENDIF` | Closes the chain (one word) |

No `READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`. No `IS_SET`. No bare-token `EXISTS` predicate. No bare `IF <name>:` truthiness. Always explicit string comparison.

**Worked example — single-action read** (replaces today's `READ_IF_EXISTS !\`…vision\` — locked constraint.`):

```
SET vision_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get vision`
IF vision_doc != "NOT_FOUND" THEN
  Read vision_doc — locked constraint. Do not re-litigate strategic decisions.
ENDIF
```

**Worked example — multi-step gate with policy fallback** (replaces today's `SET pre_commit = … / IF pre_commit EXISTS THEN … ELSE IF require_pre_commit == "true" THEN …`):

```
SET pre_commit = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`
SET require_pre_commit = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get require_pre_commit`

IF pre_commit != "NOT_FOUND" THEN
  1. Run pre_commit via Bash and show the full output.
  2. STOP and wait for human guidance if the exit code is non-zero.
ELSE IF require_pre_commit == "true" THEN
  STOP with: "Required pre-commit script not found."
ENDIF
```

## Files to update

### Resolver layer

| File | Action |
| :--- | :--- |
| `skills/file/scripts/jimfile.sh` | In `cmd_get` (or wherever the path-key branch is), return literal `NOT_FOUND` when the resolved path does not exist on disk. Replaces today's empty return for missing paths (commit `3fd1811`). |
| `skills/file/scripts/<jimfile tests>.sh` | Flip test assertions for missing-file cases from empty-string to `NOT_FOUND`. Use `/jim:meta-test scaffold` for any new cases. |
| `skills/file/SKILL.md` | Update prose describing `get`'s return shape: was "path-or-empty for path keys", now "path-or-`NOT_FOUND` for path keys". |
| Any bash caller of `get` under `skills/*/scripts/` | Audit and migrate `[ -n "$x" ]` / `[ -z "$x" ]` patterns to `[ "$x" != "NOT_FOUND" ]` / `[ "$x" = "NOT_FOUND" ]`. Expected to be few or none — most consumption is from SKILL.md. |

### Skill predicates — block form (`IF X EXISTS THEN` → `IF X != "NOT_FOUND" THEN`)

4 skills, 6 sites. The `ELSE IF Y == "true" THEN` mirror branches stay unchanged.

| File | Line | Variable |
| :--- | :--- | :--- |
| `skills/arch/SKILL.md` | 45 | `arch_doc` |
| `skills/build/SKILL.md` | 76 | `pre_commit` |
| `skills/build/SKILL.md` | 109 | `pre_completion` |
| `skills/build/SKILL.md` | 119 | `arch_doc` |
| `skills/vision/SKILL.md` | 35 | `vision_doc` |
| `skills/roadmap/SKILL.md` | 41 | `roadmap_doc` |

### Skill predicates — single-line form (`READ_IF_EXISTS !\`…\` — note` → SET + IF + ENDIF block)

7 skills, 10 sites. Each converts from the one-line shorthand into the explicit three-line block.

| File | Line | Key |
| :--- | :--- | :--- |
| `skills/spec/SKILL.md` | 33 | `vision` |
| `skills/spec/SKILL.md` | 35 | `architecture` |
| `skills/plan/SKILL.md` | 53 | `architecture` |
| `skills/research/SKILL.md` | 99 | `vision` |
| `skills/research/SKILL.md` | 101 | `architecture` |
| `skills/brainstorm/SKILL.md` | 30 | `vision` |
| `skills/brainstorm/SKILL.md` | 32 | `roadmap` |
| `skills/arch/SKILL.md` | 37 | `vision` |
| `skills/vision/SKILL.md` | 27 | `architecture` |
| `skills/roadmap/SKILL.md` | 27 | `vision` |

### Spec amendments

| File | Action |
| :--- | :--- |
| `docs/specs/sdlc/008-directive-vocabulary/spec.md` | Revise Overview, Refactor Rationale, **Acceptance Criteria** (especially the slot-by-slot mapping on lines 35–43), Convention codification AC (lines 45–48), Validation surfaces AC (lines 50–52), Original repro AC (lines 63–66). Replace all references to `READ_IF_EXISTS`/`RUN_IF_EXISTS`/`DO_IF_EXISTS`/`IF X EXISTS THEN` with the new SET + `!=` shape. Keep the spec frontmatter `status: approved`. |
| `docs/specs/sdlc/008-directive-vocabulary/plan.md` | Uncheck any `[x]` task that targeted the now-superseded EXISTS vocab; re-migrate those sites to the SET + `!=` shape. Add new tasks for the D2-revised resolver change and the file-update list above. Keep plan `status: in-progress`. |
| `docs/specs/sdlc/008-directive-vocabulary/research.md` | Review. Annotate any findings whose load-bearing reasoning has shifted (e.g., D8 empty-no-op semantics are no longer relied on). Body preserved otherwise. |
| `docs/specs/platform/002-jimconf/spec.md`, `plan.md`, `research.md` | If they reference D2's path-or-empty semantics, update to path-or-`NOT_FOUND`. Targeted edits — don't rewrite. |
| `docs/specs/platform/003-jimfile/spec.md`, `plan.md`, `research.md` | Same as 008: update D2 references to D2-revised. The `get` semantics description is the primary touchpoint. |

### Validation surfaces

| File | Line | Action |
| :--- | :--- | :--- |
| `skills/meta-skill/SKILL.md` | 104 | Replace EXISTS-family checklist line with the SET + `!=` shape. |
| `skills/meta-agent/SKILL.md` | 125 | Mirror the meta-skill update. |

### Canonical convention source

| File | Action |
| :--- | :--- |
| `ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions | Rewrite the directive table to the SET + `!=` form. Flag the EXISTS family (`READ_IF_EXISTS`, `RUN_IF_EXISTS`, `DO_IF_EXISTS`, `IF X EXISTS THEN`) as a documented anti-pattern alongside the retired BASIC `IF (X) EXISTS THEN` shape. Cite this brainstorm (`docs/brainstorms/20260513-directive-vocab-exists-trap.md`) and `docs/debug/20260512-skill-bash-substitution-wrappers.md` as the defect record. |

### Meta-matrix probe

| File | Action |
| :--- | :--- |
| `.claude/skills/meta-matrix/SKILL.md` (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`) | Add a probe row for the new readback shape: `SET x = NOT_FOUND` + `IF x != "NOT_FOUND" THEN <body> ENDIF`. Verify it substitutes under the same wrapper variations tested for U–Z and AA/BB. Existing CC–FF rows stay for historical record. Manually rerun the matrix once the vocab change lands. |

### Historical artifacts (annotation only — body preserved)

Per spec 011's existing precedent for "Historical artifacts (instructional/example contexts)": one-line "Superseded by 2026-05-13 brainstorm" annotation; body preserved verbatim.

| File | Action |
| :--- | :--- |
| `docs/brainstorms/20260505-file-resolver-conventions-audit.md` | Annotate near the D1 decision body (lines 56–65), the D2 decision (lines 66–69), the D8 decision (lines 114–121), and the Gate convention table (lines 128–142). D1 vocab superseded; D2 semantics changed from path-or-empty to path-or-`NOT_FOUND`; D8 empty-slot contract no longer load-bearing. |
| `docs/brainstorms/20260505-bash-scripts-in-meta.md` | Per spec 011 AC line 70: annotation near references to the BASIC dialect (lines 76, 189). Add the brainstorm-20260513 reference where relevant. |
| `docs/specs/sdlc/001-meta/spec.md:123` | Per spec 011 AC line 71: same annotation pattern. |
| `docs/debug/20260512-skill-bash-substitution-wrappers.md` | Replace the "Resolved by spec 011" footer (or add it if not yet present) with "Resolved by spec 011, amended 2026-05-13 per `docs/brainstorms/20260513-directive-vocab-exists-trap.md`." Body preserved. |
| `docs/brainstorms/20260512-jim-howtos.md` *(uncommitted)* | If it references the EXISTS family or path-or-empty semantics, annotate. Otherwise no action. |
| `docs/research/20260512-jim-prompt-meta-skill.md` *(uncommitted)* | Same — annotate if it references the superseded shapes. |
| `docs/research/20260504-research-plugin-interoperability.md` *(uncommitted)* | Quick scan; likely no action. |
| `docs/research/20260504-research-ui-design.md` *(uncommitted)* | Quick scan; likely no action. |

### Agent prose

| File | Action |
| :--- | :--- |
| `agents/coder.md:82` | Per 20260505 audit (D7 followup): references `./pre-commit.sh` in semantic prose. Already correct under D7(c); verify it's still defensible under D2-revised and rephrase if not. |
| Other `agents/*.md` | Per the 20260505 audit: example-path lists in `agents/pm.md`, `agents/architect.md`, `agents/researcher.md`, `agents/meta.md`. Static prose — no `!`-substitution. Quick scan for references to the EXISTS vocab or empty-resolver semantics. Edit only if they would confuse a reader under D2-revised. |

## Tasks (for the 011 amendment plan)

Execution order:

1. **Extend `jimfile.sh`** to return `NOT_FOUND` for missing path-key targets (D2-revised). Update bash tests (Red: scaffold a failing case asserting `NOT_FOUND`; Green: change `cmd_get`; verify). Audit and migrate bash callers if any use `-n`/`-z` against `get` output.
2. **Update `skills/file/SKILL.md`** prose to describe the new return shape.
3. **Migrate the 10 single-line `READ_IF_EXISTS` sites** to the SET + IF + ENDIF block form.
4. **Migrate the 6 `IF X EXISTS THEN` block sites** to `IF X != "NOT_FOUND" THEN`. Mirror `ELSE IF Y == "true" THEN` branches unchanged.
5. **Update `ARCHITECTURE.md`** Plugin Conventions → Logic-Flow Conventions directive table.
6. **Update validation surfaces** in `skills/meta-skill/SKILL.md:104` and `skills/meta-agent/SKILL.md:125`.
7. **Amend spec 011** (spec.md, plan.md, research.md).
8. **Amend specs 008 and 009** for the D2 revision.
9. **Annotate historical artifacts** (brainstorms, debug, 001-meta) per the table above.
10. **Add the meta-matrix probe row** for the new readback shape; manually rerun the matrix; record results in 011's plan. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)
11. **Verify agent prose** (`agents/coder.md` etc.) doesn't reference superseded shapes.

## Out of scope

- **Prose-mention hygiene (D4 — parked).** Revisit after D1 + D2-revised land; if the `ROADMAP.md`-style hallucination persists, scope as a follow-up spec.
- **Generalized "what if prose mentions reference unresolvable concepts" research.** Future concern; not blocking.
- **Anthropic preprocessor changes.** Out of scope as always.
- **Migrating documentation references in inline-code (e.g., `` `READ_IF_EXISTS` `` discussed as a *thing* in checklists).** Inline-code suppresses substitution and is intentional. If meta-skill/meta-agent checklists discuss the *retired* vocab as anti-patterns, those references stay as inline-code literals.

## Considered and dropped

- **Contract preamble alone (no rename).** Directive name kept winning over a documented contract; observed empirically.
- **Rename `READ_IF_EXISTS` → `READ` and `IF X EXISTS THEN` → `IF X IS_SET THEN`.** Leaves the broken-looking empty-RHS line; loses the asymmetric-risk advantage.
- **Semantic rename (`READ_RESOLVED` / `READ_FROM_RESOLVER`).** Name variant; sub-question internal to a rename-only path, not a distinct design.
- **Punctuation marker (`READ?`).** Terse but untested under any wrapper.
- **`NOT_SET` sentinel with `IS_SET` predicate.** Self-contradictory: a variable bound to the string `"NOT_SET"` *is* set, so naive predicate read fires the wrong branch.
- **Bare `IF False THEN` (no string comparison).** Gambles on the LLM treating `"False"` as falsy. Bash and Python both treat `"False"` as truthy (non-empty string). 3-of-4 interpretive frames evaluate it wrong.
- **`get` returns `False` (boolean-shaped string).** Collides semantically with `== "true"`/`"false"` predicates already used for boolean keys; would confuse a reader.
- **Per-callsite bash fallback (`|| echo "(missing)"`).** Fragments the convention across call sites.
- **Inline `IF !\`bash has x\` THEN` (no SET line).** Empirically untested under any wrapper; deferred.
- **Two-resolver decoupling with `has` subcommand (sibling verb returning `"true"`/`"false"`).** Adds a resolver verb; achieves symmetry with the `require_*` policy branches at the cost of two SET lines per gate. Strictly heavier than the single-resolver sentinel approach (D2-revised) for no clear gain.

## Cross-link

Predecessor: [`20260505-file-resolver-conventions-audit.md`](20260505-file-resolver-conventions-audit.md) — established D1 (directive vocabulary), D2 (path-or-empty), D8 (empty-slot no-op). This brainstorm supersedes D1's directive names and D2's return shape; D8 is no longer load-bearing.

Forensic record: [`docs/debug/20260512-skill-bash-substitution-wrappers.md`](../debug/20260512-skill-bash-substitution-wrappers.md) — the original substitution-layer defect that spec 011 resolved.

Recommendation: enter Claude Code plan mode in a fresh session with this brainstorm as origin. The amendment plan should follow the task order above.
