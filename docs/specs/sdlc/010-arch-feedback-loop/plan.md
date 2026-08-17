---
title: "Post-build ARCHITECTURE.md feedback loop"
spec: "spec.md"
type: feature
status: complete
---

# 013 Post-build ARCHITECTURE.md feedback loop — Plan

## Overview

Extend the `jimconf.sh` resolver to recognize an `auto_*` flag-prefix family (one new key, `auto_arch_feedback`, default `"false"`), then wire two prompt-level gates: `/jim:build` step 5 invokes `/jim:arch` via the Skill tool when the configured architecture path exists, and `/jim:arch` step 6 branches on `auto_arch_feedback` to either auto-write or run its existing user-confirmation flow.

## Design Decisions

### 1. Flag-prefix dispatcher — single condition vs. separate arm

- **Chosen:** Widen the existing `require_*` branch in `resolve()` (`skills/conf/scripts/jimconf.sh:92`) to `[[ "$cli_key" == require_* || "$cli_key" == auto_* ]]`.
- **Why:** Matches the research recommendation. Reads as one flag-key family in `ARCHITECTURE.md:261` ("CLI keys starting with `require_` or `auto_`"); minimal diff; no duplicate logic.
- **Rejected:** Add a separate `elif [[ "$cli_key" == auto_* ]]` arm — duplicates the toml-key assignment, costs an extra branch for no semantic gain.

### 2. Build step shape — implicit fall-through, no `ELSE`

- **Chosen:** `SET arch_doc = …` then `IF arch_doc EXISTS THEN … ENDIF` with no `ELSE`.
- **Why:** Spec AC mandates *silent* skip when the architecture path is absent (no warning, no prompt). Directive vocabulary documents implicit fall-through as the canonical shape for single-branch existence gates.
- **Rejected:** `IF … THEN … ELSE (do nothing) ENDIF` — extra branch with no body violates the lean form documented in `ARCHITECTURE.md:318`.

### 3. Arch step shape — explicit two-branch `IF … ELSE … ENDIF`

- **Chosen:** `SET auto_arch_feedback = …` then `IF auto_arch_feedback == "true" THEN … ELSE … ENDIF` with both branches named.
- **Why:** Spec AC explicitly requires both branches to be named (both `"true"` and `"false"` paths have distinct, mandatory behavior). The `"false"` path is the default and the user-confirmation flow downstream skills currently rely on — making it implicit fall-through would obscure the more important branch.
- **Rejected:** Implicit fall-through after a single-branch `IF == "true" THEN`. — Conceals the default path; harder to audit when reading the SKILL.md cold.

### 4. Permission token — `Skill(jim:arch)`, not bare `Skill`

- **Chosen:** Add `Skill(jim:arch)` to `/jim:build`'s `allowed-tools` as a second clause alongside the existing `Bash(... jimfile.sh *)` clause.
- **Why:** Per `docs/research/20260512-001-meta-skill-invocation-freshness.md:53` the permission rule syntax is `Skill(name)` and follows least-privilege per Permission Conventions (`ARCHITECTURE.md:372`). First skill-to-skill invocation in jim — sets the precedent for future cross-skill calls. The Skill-tool invocation runs inline in the main thread (no fork), so the existing `allowed-tools` semantics cover the nested body.
- **Rejected:** Bare `Skill` wildcard — violates Permission Creep anti-pattern (`ARCHITECTURE.md:417`).

### 5. `/jim:arch` `allowed-tools` — no frontmatter change required

- **Chosen:** Leave `/jim:arch`'s frontmatter clause as-is. The existing `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)` already covers `bash jimfile.sh get auto_arch_feedback` (the `*` glob spans the entire argument list).
- **Why:** Spec AC reads "extended to permit reading via the same clause already present" — i.e., the same clause shape, no new clause. Coverage is automatic; touching the frontmatter would add noise without changing behavior.
- **Rejected:** Add a redundant explicit clause — would violate the "mirror actual call sites verbatim" rule in `ARCHITECTURE.md:388`.

### 6. Test enumeration cases — additive row extensions, not refactored

- **Chosen:** Extend the five enumeration cases (`case_no_config_returns_defaults`, `case_full_config_returns_overrides`, `case_list_outputs_all_keys`, `case_keys_outputs_valid_keys`, `case_malformed_lines_are_ignored`) by adding `auto_arch_feedback` rows to their hardcoded pair lists / fixtures / assertions and bumping the hardcoded `"10"` line-count literals to `"11"`. Keep the case structure and assertion shape unchanged.
- **Why:** Spec AC explicitly requires this shape — "additive row additions… case structure, assertions, and behavioral semantics are unchanged." Preserves the "existing tests pass without modification" semantics (no behavioral regression, only expected-set growth).
- **Rejected:** Refactor the five cases to iterate over `KEYS` dynamically — out of scope; would touch unrelated assertions and risk regressions in unrelated cases.

### 7. No synthetic dispatcher-contract fixture key

- **Chosen:** Use the two per-key `case_auto_arch_feedback_*` tests as the end-to-end dispatcher-contract test for the new `auto_*` prefix; do not add a synthetic `auto_*` key to `KEYS`.
- **Why:** Spec AC closes this explicitly. `auto_arch_feedback` is currently the only `auto_*` key, so the per-key cases already exercise the dispatcher branch end-to-end. A synthetic fixture key would pollute production `KEYS` for a redundant test.
- **Rejected:** Add `auto_test_fixture` or similar to `KEYS` — pollutes the production CLI surface for test convenience.

### 8. Flag ownership — `/jim:arch` reads `auto_arch_feedback`, `/jim:build` stays agnostic

- **Chosen:** `/jim:build` does not read or pass `auto_arch_feedback`. Its only job is to bind `arch_doc` and invoke `/jim:arch` via the Skill tool when the path exists. `/jim:arch` reads the flag at the head of step 6 and branches on its value.
- **Why:** Single source of truth — `/jim:arch` owns the decision about how to present its own output (auto-write vs. confirm). Keeps the coupling between the two skills minimal: `/jim:build` only needs to know whether the document exists; `/jim:arch` knows everything about its own gate. Mirrors how `/jim:build`'s pre-commit/pre-completion gates handle their own `require_*` flags rather than letting callers pass them in.
- **Rejected:** `/jim:build` reads the flag and passes it via `$ARGUMENTS` to `/jim:arch` — would force `/jim:arch`'s Argument Routing table to grow a new "flag mode" and tightly couple the two skills. Any future change to the flag's semantics would require touching both skills instead of one.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| SKILL.md ≤ 500 lines (`:408`) | Yes | `/jim:build` 133 → ~145; `/jim:arch` 97 → ~110. Both well under cap. |
| Logic-Flow Conventions: SET + paren-free IF; no slot inside `(...)` (`:281`) | Yes | Both new directives use `SET … = !` then paren-free `IF … THEN … ENDIF`; no `!`-slot inside parens. |
| Retired BASIC `IF (X) EXISTS THEN` idiom forbidden (`:346`) | Yes | Neither new directive uses the BASIC shape. |
| Permission Conventions: `allowed-tools` mirrors actual call sites (`:372`) | Yes | `Skill(jim:arch)` clause matches the body's Skill-tool call; no bare `Skill` wildcard. |
| Substitution Conventions: `!`-injection slot at rightmost token, outside parens (`:352`) | Yes | Each `SET <name> = !\`bash …\`` places the slot at line end. |
| Bash-vs-Prompt rule (`:266`) | Yes | Deterministic value lookup (`get auto_arch_feedback`) is bash; gate semantics (write-vs-confirm) live in the prompt. |
| Skill body runs inline; no fork (`:239`) | Yes | `/jim:build` invokes `/jim:arch` via the Skill tool inline — `allowed-tools` from `/jim:build` covers the nested body. |
| Resolver security model: no `source`/`eval`, pure parse (`jimconf.sh` header) | Yes | Only `KEYS`, `default_for`, and `resolve()`'s prefix dispatcher are touched. `parse_value()` is unchanged. |
| `set -uo pipefail`, no third-party deps (`CLAUDE.md`) | Yes | No new shell idioms; resolver remains bash + POSIX. |

**Soft constraint:** `@coder` (via `/jim:build`) now invokes `/jim:arch` (architect's skill). `ARCHITECTURE.md:239` states `agent:` frontmatter is documentation, not runtime routing — non-blocking, but it sets a precedent worth one Plugin Conventions note (covered by spec AC and Task 14).

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Resolver | `skills/conf/scripts/jimconf.sh` | Update | Append `auto_arch_feedback` to `KEYS` (`:42`); add `auto_arch_feedback) echo "false" ;;` arm to `default_for()` (`:48–62`); widen `resolve()` prefix check (`:92`) to `require_* || auto_*`. |
| Build skill | `skills/build/SKILL.md` | Update | Add `Skill(jim:arch)` to `allowed-tools` (`:10`); insert arch-feedback substep in step 5 between substep 1 (pre-completion gate, `:104–114`) and substep 2 (report results, `:115`). |
| Arch skill | `skills/arch/SKILL.md` | Update | Replace step 6 body (`:78–84`) with: existing summarize-changes line, then `SET auto_arch_feedback = …` + `IF == "true" THEN … ELSE … ENDIF` gate, then the existing "Do not proceed" terminal line. Frontmatter unchanged. |
| Config example | `jimconf.toml.example` | Update | Add `auto_arch_feedback = "false"` line plus 2–4-line comment block (mirrors the `require_*` block at `:35–40`). |
| Tests | `tests/jimconf.sh` | Update | (1) Add `case_auto_arch_feedback_default` and `case_auto_arch_feedback_overridden` mirroring `case_require_pre_commit_*` (`:237–249`). (2) Extend `case_no_config_returns_defaults` pair list (`:43–52`) with `auto_arch_feedback:false`. (3) Extend `case_full_config_returns_overrides` fixture (`:64–73`) and assertions (`:74–83`). (4) Bump `case_list_outputs_all_keys` line count `"10"→"11"` (`:113`) and add `auto_arch_feedback` `assert_match` (`:124`). (5) Extend `case_keys_outputs_valid_keys` expected printf (`:131`). (6) Bump `case_malformed_lines_are_ignored` line count `"10"→"11"` (`:169`). |
| Architecture doc | `ARCHITECTURE.md` | Update | (a) Scripting Layer "Config file" bullet (`:261`): widen prefix doc to `require_*` or `auto_*`; bump count "ten" → "eleven" and "two enforcement flags" → "two enforcement flags and one feedback-loop flag (`auto_arch_feedback`)"; restate the prefix-dispatch convention to name both prefixes. (b) Plugin Conventions → Skill Invocation: add one-liner naming `Skill(jim:arch)` as the permission token syntax for skill-to-skill invocation. (c) Core Components: add one short paragraph to the Skills component covering the post-build arch-feedback loop, the flag, and the existence-conditioned trigger. |

## Interface Contracts

**Resolver dispatch contract** (`skills/conf/scripts/jimconf.sh::resolve`):

```bash
# resolve <config-file> <cli-key>
#   - If cli_key matches require_* OR auto_*: toml_key = cli_key (no suffix).
#   - Otherwise:                                toml_key = "${cli_key}_path".
#   - Configured value (if non-empty) wins; otherwise default_for(cli_key).
#   - Unknown cli_key → exit 1 with stderr error (caller-side validity check).
```

**New CLI surface** (no new subcommand — extends existing `get`/`list`/`keys`):

```text
bash jimconf.sh get auto_arch_feedback     → "false" (default) or configured value
bash jimconf.sh list                        → 11 KEY=VALUE lines (was 10)
bash jimconf.sh keys                        → 11 lines (was 10), auto_arch_feedback appended
bash jimfile.sh get auto_arch_feedback      → same as jimconf.sh (pass-through, unchanged)
```

**`/jim:build` step 5 directive** (inserted between substep 1 and substep 2):

```text
2. Refresh ARCHITECTURE.md against the just-built code:

   SET arch_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`

   IF arch_doc EXISTS THEN
     Invoke /jim:arch via the Skill tool to refresh ARCHITECTURE.md against the just-built code.
   ENDIF
```

(Renumber the existing "Report results" and "STOP" substeps to 3 and 4.)

**`/jim:arch` step 6 directive** (replaces the current "Show… Ask… Do not proceed" body):

```text
Show the completed document (or summarize changes for a differential update). List which sections changed and which sections had no findings.

SET auto_arch_feedback = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get auto_arch_feedback`

IF auto_arch_feedback == "true" THEN
  Write the proposed update directly to the configured architecture path. Summarize which sections were added, changed, or preserved.
ELSE
  Present the diff and ask: "Does this look accurate? Any sections to refine?" Wait for confirmation.
ENDIF

Do not proceed to the next phase.
```

**`/jim:build` `allowed-tools` clause** (single frontmatter line, two clauses):

```yaml
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Skill(jim:arch)
```

## Data Flow

```mermaid
flowchart TD
    A[/jim:build: all tasks complete] --> B[Step 5.1: pre-completion gate]
    B -->|exit 0| C[Step 5.2: SET arch_doc]
    C --> D{arch_doc EXISTS?}
    D -->|no| F[Step 5.3: report and ask 'mark complete?']
    D -->|yes| E[Invoke Skill(jim:arch)]
    E --> G[/jim:arch steps 1–5: scan, generate]
    G --> H[Step 6: SET auto_arch_feedback]
    H --> I{== 'true'?}
    I -->|yes| J[Write update directly,<br/>summarize sections]
    I -->|no| K[Present diff,<br/>wait for confirmation]
    J --> F
    K --> F
```

## Task Breakdown

1. [x] **[Red]** Add `case_auto_arch_feedback_default` to `tests/jimconf.sh` (mirror `case_require_pre_commit_default` at `:237–242`, swap the key name). Place it adjacent to the existing `require_*` cases.
   **Verify:** `bash tests/jimconf.sh auto_arch_feedback_default 2>&1 | grep -E "(FAIL|unknown key)"` exits 0 (case fails on the existing `unknown key 'auto_arch_feedback'` error).

2. [x] **[Green]** Register the new key in `skills/conf/scripts/jimconf.sh`: append `auto_arch_feedback` to the `KEYS` array (`:42`); add `auto_arch_feedback) echo "false" ;;` arm to `default_for()` (`:48–62`).
   **Verify:** `bash tests/jimconf.sh auto_arch_feedback_default` exits 0.

3. [x] **[Green cascade]** Extend the three enumeration cases that now break: `case_list_outputs_all_keys` (bump `"10"→"11"` at `:113`, add `assert_match "auto_arch_feedback line" '^auto_arch_feedback=false$' "$OUT"` after the existing `require_pre_completion line` assertion at `:123`); `case_keys_outputs_valid_keys` (append `\nauto_arch_feedback` to the `expected=$(printf …)` literal at `:131`); `case_malformed_lines_are_ignored` (bump `"10"→"11"` at `:169`).
   **Verify:** `bash tests/jimconf.sh` exits 0.

4. [x] **[Red]** Add `case_auto_arch_feedback_overridden` to `tests/jimconf.sh` (mirror `case_require_pre_commit_overridden` at `:245–249`, swap the key name). Asserts `"true"` after `run -c "$cfg" get auto_arch_feedback`.
   **Verify:** `bash tests/jimconf.sh auto_arch_feedback_overridden 2>&1 | grep "FAIL"` exits 0 (case fails: resolver looks up `auto_arch_feedback_path`, gets nothing, falls through to default `"false"` — assertion expects `"true"`).

5. [x] **[Green]** Widen `resolve()`'s prefix dispatcher in `skills/conf/scripts/jimconf.sh` (`:92`): change `if [[ "$cli_key" == require_* ]]; then` to `if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then`.
   **Verify:** `bash tests/jimconf.sh auto_arch_feedback_overridden` exits 0.

6. [x] **[Lockstep]** Extend the two remaining enumeration cases for end-to-end dispatcher-contract coverage: `case_no_config_returns_defaults` (add `"auto_arch_feedback:false"` to the `for pair in …` list at `:43–52`); `case_full_config_returns_overrides` (add `auto_arch_feedback = "true"` to the heredoc fixture at `:64–73`, and add `run -c "$cfg" get auto_arch_feedback; assert_eq "auto_arch_feedback" "true" "$OUT"` after the last existing assertion at `:83`).
   **Verify:** `bash tests/jimconf.sh` exits 0.

7. [x] **[Doc]** Update `jimconf.toml.example`: append a 2–4-line comment block after the `require_pre_completion` line (`:40`) explaining the feedback-loop gate, then add `auto_arch_feedback = "false"`.
   **Verify:** `grep -E '^auto_arch_feedback = "false"$' jimconf.toml.example` exits 0.

8. [x] **[Behavior — /jim:arch]** Update `skills/arch/SKILL.md` step 6 (`:78–84`): keep the existing "Show the completed document…" line; after it, insert the `SET auto_arch_feedback = !…` binding and the explicit `IF == "true" THEN … ELSE … ENDIF` gate (see Interface Contracts → `/jim:arch` step 6 directive); keep the existing "Do not proceed to the next phase." line as the terminal sentence. Do not touch the frontmatter, the Argument Routing table, or steps 1–5.
   **Verify:** `grep -cF 'SET auto_arch_feedback' skills/arch/SKILL.md` prints `1`, AND `grep -F 'IF auto_arch_feedback == "true" THEN' skills/arch/SKILL.md` exits 0, AND `grep -E 'IF \(' skills/arch/SKILL.md` exits 1 (no BASIC idiom regression).

9. [x] **[Behavior — /jim:build]** Insert the arch-feedback substep in `skills/build/SKILL.md` step 5 between the existing pre-completion gate substep (`:104–114`) and the existing "Report results" substep (`:115`). The new substep contains the `SET arch_doc = !…` binding and a single-branch `IF arch_doc EXISTS THEN … ENDIF` (no `ELSE`). Renumber the existing "Report results" and "STOP" lines from `2.` / `3.` to `3.` / `4.`.
   **Verify:** `grep -cF 'SET arch_doc' skills/build/SKILL.md` prints `1`, AND `grep -F 'IF arch_doc EXISTS THEN' skills/build/SKILL.md` exits 0, AND `grep -E '^3\. Report results' skills/build/SKILL.md` exits 0 (renumber landed), AND `grep -E 'IF \(' skills/build/SKILL.md` exits 1.

10. [x] **[Frontmatter — /jim:build]** Extend the `allowed-tools` line in `skills/build/SKILL.md` (`:10`) by appending ` Skill(jim:arch)` after the existing `Bash(...)` clause (space-separated; no comma).
    **Verify:** `grep -E '^allowed-tools: Bash\(bash \$\{CLAUDE_PLUGIN_ROOT\}/skills/file/scripts/jimfile\.sh \*\) Skill\(jim:arch\)$' skills/build/SKILL.md` exits 0.

11. [x] **[Doc — ARCHITECTURE.md Scripting Layer]** Update the "Config file" bullet in `ARCHITECTURE.md` (`:261`): widen the prefix description so it reads "(CLI keys starting with `require_` or `auto_`)"; bump the key count from "ten" to "eleven"; replace "and two enforcement flags (`require_pre_commit`, `require_pre_completion`)" with "two enforcement flags (`require_pre_commit`, `require_pre_completion`) and one feedback-loop flag (`auto_arch_feedback`)".
    **Verify:** `grep -E '(CLI keys starting with `?require_`? or `?auto_`?)' ARCHITECTURE.md` exits 0, AND `grep -c 'auto_arch_feedback' ARCHITECTURE.md` returns at least `1`, AND `grep -E 'eleven configurable keys' ARCHITECTURE.md` exits 0.

12. [x] **[Doc — ARCHITECTURE.md Core Components]** Append one short paragraph to the Skills component section (or the matching component bullet block — see `:150–158`) describing the post-build arch-feedback loop: name the gate (post-build step 5.2 in `/jim:build`), the flag (`auto_arch_feedback`, default `"false"`), and the existence-conditioned trigger (silently skipped when the configured architecture path is absent).
    **Verify:** `grep -E 'post-build (arch-)?feedback loop' ARCHITECTURE.md` exits 0, AND `grep -E 'auto_arch_feedback' ARCHITECTURE.md` exits 0.

13. [x] **[Doc — ARCHITECTURE.md Skill Invocation]** Add a one-line note under Plugin Conventions → Skill Invocation (`:235–239`) naming `Skill(jim:arch)` as the permission-token syntax for skill-to-skill invocation, and noting that the called skill's body runs inline in the main thread (so the caller's `allowed-tools` covers nested calls).
    **Verify:** `grep -E 'Skill\(jim:arch\)' ARCHITECTURE.md` exits 0.

14. [x] **[Regression]** Run the full bash suite and confirm zero behavioral regressions in unrelated cases.
    **Verify:** `bash skills/meta-test/scripts/run.sh` exits 0.

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| `resolve()` recognizes `auto_*` as flag-prefix alongside `require_*` | 5 |
| `auto_arch_feedback` in `KEYS` + default `"false"` | 2 |
| `jimfile.sh get auto_arch_feedback` resolves via same dispatch path (no `_path` suffix) | 2, 5 (resolver) — covered end-to-end by tests in 1, 4 |
| Configured override takes precedence over default | 4, 5 |
| Key reachable via `/jim:conf get` / `/jim:conf list` | 2 (auto via `KEYS`), 3 (list assertion) |
| `jimconf.toml.example` documents the key with default and short comment | 7 |
| TOML format: flat boolean string `auto_arch_feedback = "true"\|"false"`, no `_path` suffix | 5, 7 |
| `jimconf.sh` parser surface unchanged (no `source`/`eval`, no third-party deps) | 2, 5 (scope discipline — verified by 14 regression run) |
| `/jim:build` step 5 runs arch-feedback after pre-completion, before "report results" | 9 |
| Arch-feedback step uses post-011 directive vocabulary | 9 |
| Retired BASIC `IF (X) EXISTS THEN` idiom not used | 8, 9 (Verify greps for `IF \(`) |
| Silent skip when architecture path is absent | 9 (no `ELSE` branch) |
| `/jim:build` continues to "report results" regardless of `/jim:arch` outcome | 9 (substep ordering — `IF…ENDIF` then renumbered substep 3) |
| `/jim:build` `allowed-tools` extended to permit `Skill(jim:arch)` | 10 |
| `/jim:arch` reads `auto_arch_feedback` before step 6 present-and-stop | 8 |
| Read uses `SET auto_arch_feedback = !…` (no `!`-injection inside parens) | 8 |
| Explicit two-branch `IF … ELSE … ENDIF` — both branches named | 8 |
| `"true"`: write directly + summarize sections | 8 |
| `"false"` (default): existing user-confirmation flow unchanged | 8 |
| Flag affects only step 6 (scan, generate, summary content unchanged) | 8 (scope discipline — steps 1–5 untouched) |
| `/jim:arch` `allowed-tools` covers `get auto_arch_feedback` via existing clause | Design Decision 5 — no task needed; verified by 14 regression run |
| `ARCHITECTURE.md:261` documents `auto_*` prefix alongside `require_*` | 11 |
| Post-build arch-feedback loop described in relevant component section | 12 |
| Plugin Conventions → Skill Invocation: `Skill(jim:arch)` one-liner | 13 |
| `tests/jimconf.sh` adds default + override + `-c` cases for `auto_arch_feedback` | 1, 4 (`_overridden` uses `run -c "$cfg"` — covers `-c` path) |
| Five enumeration cases extended additively; literals `"10"→"11"` | 3, 6 |
| No new test surface for `/jim:build` → `/jim:arch` invocation | (Confirmed — no task added; covered by Out-of-Scope discipline) |
| Existing test semantics preserved; `run.sh` exits 0 | 14 |

## Out of Scope

- **Change-detection heuristics inside `/jim:build`.** No git-diff inspection, no new-file counting, no pre-judgment of whether `/jim:arch` is "worth" invoking. The single authority on drift remains `/jim:arch`.
- **Auto-commit of ARCHITECTURE.md updates.** Even when `auto_arch_feedback = "true"`, `/jim:arch` writes the file but never commits.
- **`require_arch_feedback` enforcement flag.** This spec adds the opt-in convenience flag only. `/jim:build` never blocks completion on a declined arch update.
- **Delta-only `/jim:arch` mode** (scan only files changed since the last build). Full codebase scan on every post-build invocation is acceptable for this spec.
- **First-time ARCHITECTURE.md generation from `/jim:build`.** When the configured architecture path does not exist, the arch-feedback step is silently skipped. Bootstrapping a fresh architecture document remains a deliberate `/jim:arch` invocation.
- **Modifications to `@jim:architect` or `assets/architecture-template.md`.** This spec changes when/how `/jim:arch` is invoked and gated; it does not change what the architect produces.
- **A third top-level flag prefix beyond `require_*` and `auto_*`.** This spec adds exactly one prefix; it does not generalize to `enable_*`, `skip_*`, or arbitrary author-chosen prefixes.
- **Automated lint enforcing the post-011 directive shape.** Already excluded by spec 011; meta-skill / meta-agent author-time checklists cover this spec's gate as well.
- **Refactoring `tests/jimconf.sh` enumeration cases to iterate over `KEYS` dynamically.** Spec mandates additive row extensions; structural refactoring is deferred.
- **Frontmatter change on `/jim:arch`'s `allowed-tools`.** No change needed — the existing `Bash(... jimfile.sh *)` clause already covers the new `get auto_arch_feedback` call (see Design Decision 5).

## Open Questions

- [x] ~Should `/jim:arch`'s auto-apply path emit a "no drift detected" summary when there are no changes?~ → **No** (resolved in spec).
- [x] ~Should `/jim:build` log a declined `/jim:arch` outcome into `plan.md`?~ → **No** (resolved in spec).
- [x] ~Does `/jim:arch`'s existing `Bash(... jimfile.sh *)` clause cover the new `get auto_arch_feedback` call?~ → **Yes** (Design Decision 5; verified by regression run in Task 14).

No `[NEEDS CLARIFICATION]` markers — every spec AC maps to a task or is documented in Design Decisions / Out of Scope.
