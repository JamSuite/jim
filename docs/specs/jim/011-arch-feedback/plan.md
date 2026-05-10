---
title: "Post-build ARCHITECTURE.md feedback loop"
spec: "docs/specs/jim/011-arch-feedback/spec.md"
type: feature
status: complete
---

# 011 Post-build ARCHITECTURE.md feedback loop — Plan

## Overview

Insert a single inline `IF EXISTS THEN` step into `/jim:build`'s completion gate that invokes `/jim:arch` via prose ("Invoke `/jim:arch` …") — the LLM uses the built-in Skill tool to load and execute it. `/jim:arch` reads a new `auto_arch_feedback` config flag at its present-and-stop step; when `"true"`, it applies updates without prompting. Schema additions follow the prefix-dispatch convention established in PR #8.

## Design Decisions

### 1. Skill-to-skill invocation mechanism — prose, not a special syntax

- **Chosen:** `/jim:build`'s new step uses English prose: "Invoke `/jim:arch` to run a differential update." The LLM running the build skill uses Claude Code's Skill tool to load `/jim:arch`'s body in the same session.
- **Why:** This is the exact form used by the fork's commit `9039461` (the original arch-feedback implementation), and the pattern was working in practice. No special syntax exists in jim or Claude Code for "skill calls skill"; the Skill tool is the documented way the LLM brings other skills into the conversation. Per research, this pattern works because ARCHITECTURE.md L239 already establishes `agent:` as documentation rather than runtime routing — the agent that invoked the parent skill executes the invoked skill's body.
- **Rejected:** Inlining `/jim:arch`'s differential-update logic into `/jim:build` — duplicates ~50 lines of arch's skill body and creates drift risk over time.
- **Rejected:** User handoff ("Run `/jim:arch` next") — defeats the spec's auto-feedback intent.

### 2. `auto_arch_feedback` lives in `/jim:arch`, not `/jim:build`

- **Chosen:** `/jim:build` doesn't read or pass `auto_arch_feedback`. `/jim:arch` reads it at the top of step 6 (Present and stop) and branches on its value.
- **Why:** Single source of truth — `/jim:arch` decides whether to apply automatically based on its own config read. `/jim:build` stays agnostic; its only job is to invoke `/jim:arch` when ARCHITECTURE.md exists. Keeps coupling between the two skills minimal.
- **Rejected:** `/jim:build` reads the flag and passes it via `$ARGUMENTS` — would force `/jim:arch`'s argument-routing to grow a new mode and tie the two skills together unnecessarily.

### 3. `resolve()` prefix-dispatch shape — disjunction, not generalized predicate

- **Chosen:** Extend the existing `resolve()` block with a disjunction: `if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then`.
- **Why:** Two-line change to an already-existing dispatch block. Explicit list of flag prefixes; easy to read; easy to extend. Matches the spec's intent of treating `auto_*` as a flag family alongside `require_*`.
- **Rejected:** Generalized predicate — `FLAG_PREFIXES=(require_ auto_)` plus a loop. Over-engineered for two prefixes; revisit when a third lands.

### 4. BASIC form for the build step — inline single-action, unfenced

- **Chosen:** The new step in `/jim:build` step 5 uses the inline `IF EXISTS THEN <action> END IF` form, not the multi-step `THEN DO: ... DONE` form. No fenced text block. No ELSE branch.
- **Why:** The action is a single statement ("Invoke `/jim:arch` …"). Per ARCHITECTURE.md §Logic-Flow Conventions, inline single-action form is the right variant for this case; multi-step `THEN DO:` adds ceremony without payoff. ELSE is omitted because the absent-architecture-doc case is implicit-skip — no behavior needed.
- **Rejected:** `THEN DO:` block with ELSE for symmetry with PR #8's gates — wastes ceremony for one-action content; the ELSE branch would be a no-op.

### 5. `/jim:arch` step-6 modification — plain English, not BASIC

- **Chosen:** `/jim:arch` step 6 uses plain English to branch on the resolved `auto_arch_feedback` value: "When the flag resolves to `\"true\"`, apply the proposed update via Edit … Otherwise, show the completed document …"
- **Why:** BASIC's keyword set (`IF (X) EXISTS THEN`, `IF (X) ABSENT THEN`) is path-existence only. Comparing a string value to `"true"` is not a path-existence check, so BASIC doesn't apply per ARCHITECTURE.md §Logic-Flow Conventions ("Where it does not help: Multi-condition logic … revert to English"). The flag value resolves via `!`-injection at slash-command load; the branching prose follows.
- **Rejected:** Inventing a `IF (X) IS "true" THEN` construct — explicitly forbidden ("invented variants are a validation failure").

### 6. New Plugin Convention entry in ARCHITECTURE.md

- **Chosen:** Add a "Skill-to-Skill Invocation" subsection to ARCHITECTURE.md's Plugin Conventions, placed after Subagent Delegation. Describes the prose-invocation pattern, notes that the parent agent executes the invoked skill, flags it as appropriate-but-not-default.
- **Why:** Per research Peer Feedback signal #1: the fork's pattern was working but is undocumented in upstream. Future ports shouldn't have to re-derive the question. Documenting the convention now closes that gap.
- **Rejected:** Leave undocumented — fragile; the next port to face this question would re-do the same investigation.

### 7. Domain-boundary acceptance

- **Chosen:** Accept the soft tension. Constitution Check below cites ARCHITECTURE.md L239 as already establishing `agent:` as documentation rather than enforcement.
- **Why:** Per research Peer Feedback signal #2. The boundary principle ("coder does not modify specs / cross domain") is a guideline; the auto-feedback feature is the spec's whole point. Restructuring to keep the boundary intact would require manual user invocation and contradict the design intent.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint | Honored? | Notes |
| :--- | :--- | :--- |
| BASIC keyword set is locked (no invented variants) — §Logic-Flow Conventions | Yes | Build step uses inline single-action form; arch step uses plain English (BASIC doesn't apply to value comparisons) |
| Multi-step `THEN DO:` body ≤ ~3 numbered steps | N/A | Neither modification uses `THEN DO:` |
| Substitution sigils strict (no mixing) | Yes | All `!`-injection; no `<lower>` or `{lower}` in skill bodies |
| `!`-injection eager at slash-command load | Yes | Architecture path resolution and `auto_arch_feedback` value resolution both have stable inputs at load |
| Skills always call `jimfile.sh`, never `jimconf.sh` directly | Yes | Build and arch use `jimfile.sh get <key>` |
| Scripting layer: `set -uo pipefail`, no `set -e`, no `source`/`eval`, BASH_SOURCE-relative composition | Yes | `jimconf.sh` changes follow existing conventions; no new scripts |
| SKILL.md ≤ 500 lines (progressive disclosure) | Yes | `build/SKILL.md` grows ~6 lines; `arch/SKILL.md` grows ~5 lines |
| Agent domain boundaries (soft) | Acknowledged | Per Decision 7: ARCHITECTURE.md L239 establishes `agent:` as documentation; cross-skill invocation is permitted by that framing |
| `parse_value` regex unchanged (top-level `KEY = "value"` only) | Yes | New TOML key (`auto_arch_feedback`) matches existing regex without modification |

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Config schema | `skills/conf/scripts/jimconf.sh` | Update | Append `auto_arch_feedback` to `KEYS`; add `default_for()` arm; extend `resolve()` prefix dispatch with `auto_*` |
| Tests | `tests/jimconf.sh` | Update | Add 2 new `case_*` (default + override); update 5 hardcoded-count cases (`"10"` → `"11"`) |
| Example doc | `jimconf.toml.example` | Update | Add documented `auto_arch_feedback` key after the existing `require_*` block |
| Architecture (config) | `ARCHITECTURE.md` | Update | Extend Scripting Layer entry from "ten configurable keys" to "eleven" with `auto_arch_feedback` named |
| Architecture (convention) | `ARCHITECTURE.md` | Update | Add "Skill-to-Skill Invocation" subsection under Plugin Conventions |
| Arch skill | `skills/arch/SKILL.md` | Update | Modify step 6 (Present and stop): read `auto_arch_feedback`; branch on `"true"` to apply, else existing flow |
| Build skill | `skills/build/SKILL.md` | Update | Insert new arch-feedback step in step 5 (Completion gate), after pre-completion gate (line 113) and before "Report results" (line 114) |

## Interface Contracts

### `jimconf.sh` — schema and resolution

```bash
# KEYS extended (line 42):
readonly KEYS=(specs architecture vision roadmap brainstorms debug \
               pre_commit pre_completion require_pre_commit require_pre_completion \
               auto_arch_feedback)

# default_for() new arm:
case "$1" in
  ...existing...
  auto_arch_feedback) echo "false" ;;
esac

# resolve() prefix dispatch (existing lines 92–96, modify the condition):
if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then
  toml_key="$cli_key"
else
  toml_key="${cli_key}_path"
fi
```

### `skills/build/SKILL.md` — new step 2 of completion gate

Inline BASIC, unfenced (single-action form). Inserts after the existing pre-completion gate (current step 1, ending at line 113) and before the existing "Report results" step. Surrounding numbered steps shift: existing step 2 becomes step 3, existing step 3 becomes step 4.

```text
2. Run the arch feedback step:

   IF (!`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`) EXISTS THEN
     Invoke `/jim:arch` to run a differential update.
   END IF
```

### `skills/arch/SKILL.md` — modified step 6

Plain-English conditional, not BASIC (since the test is value comparison, not path existence). Replaces the existing 3-paragraph step-6 body.

```markdown
### 6. Present and stop

Resolve the auto-apply flag: !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get auto_arch_feedback`.

When the flag resolves to `"true"`, apply the proposed update via Edit and summarize what was applied. Do not prompt for confirmation.

Otherwise, show the completed document (or summarize changes for a differential update). List which sections changed and which sections had no findings. Ask: "Does this look accurate? Any sections to refine?"

Do not proceed to the next phase.
```

### `ARCHITECTURE.md` — new Plugin Convention subsection

Inserts after the existing "Subagent Delegation" subsection. Three short bullets:

```markdown
### Skill-to-Skill Invocation

Skills can invoke other skills by name in their prose body. The LLM running the parent skill uses Claude Code's built-in `Skill` tool to load and execute the named skill within the same conversation.

- **Same-agent execution.** The agent that invoked the parent skill executes the invoked skill's body. The `agent:` frontmatter on the invoked skill is documentation (per "Skill Invocation"), not runtime routing.
- **Use sparingly.** Skill-to-skill invocation crosses domain framings (e.g., the coder's `/jim:build` invoking the architect's `/jim:arch`). Appropriate when the work flows naturally — post-build documentation refresh, post-spec research kickoff. Not a substitute for explicit user handoffs when domain separation matters more than convenience.
- **Anchor by name.** Use the full `/jim:<skill>` form in prose. Don't inline the invoked skill's logic.
```

## Data Flow

```mermaid
flowchart TD
    A([All tasks marked x]) --> B[Pre-completion gate fires]
    B --> C{Pre-completion passed?}
    C -- No --> H1([STOP — wait for human])
    C -- Yes --> D{ARCHITECTURE.md exists?}
    D -- No --> F[Report results, ask 'mark complete?']
    D -- Yes --> E[/jim:build prose: 'Invoke /jim:arch']
    E --> SKILL[LLM uses Skill tool to load /jim:arch]
    SKILL --> SCAN[/jim:arch scans codebase, diffs against doc]
    SCAN --> FLAG{auto_arch_feedback}
    FLAG -- "true" --> AUTO[Apply via Edit, summarize, no prompt]
    FLAG -- "false" --> ASK[Show changes, ask 'looks accurate?']
    ASK --> APPROVE{User approves?}
    APPROVE -- Yes --> WRITE[Edit applied]
    APPROVE -- No --> SKIP[No changes written]
    AUTO --> F
    WRITE --> F
    SKIP --> F
    F --> Z([STOP — wait for confirmation])
```

## Task Breakdown

1. [x] **Add `auto_arch_feedback` to `jimconf.sh` and `tests/jimconf.sh`.** Append `auto_arch_feedback` to `KEYS` (line 42). Add the `default_for()` arm (`auto_arch_feedback) echo "false" ;;`). Extend `resolve()` prefix dispatch (lines 92–96) to recognize `auto_*` alongside `require_*` per Interface Contracts. Add Red-phase test cases `case_auto_arch_feedback_default()` and `case_auto_arch_feedback_overridden()` mirroring the `require_pre_commit` pattern at `tests/jimconf.sh:237–250`. Update hardcoded counts in `case_list_outputs_all_keys` (line 113, `"10"` → `"11"`) and `case_malformed_lines_are_ignored` (line 169, `"10"` → `"11"`); add the `auto_arch_feedback:false` pair to `case_no_config_returns_defaults`; add `auto_arch_feedback = "true"` line + assertion to `case_full_config_returns_overrides`; add `assert_match` line to `case_list_outputs_all_keys`; extend the expected string in `case_keys_outputs_valid_keys`.
   **Verify:** `bash tests/jimconf.sh`

2. [x] **Document `auto_arch_feedback` in `jimconf.toml.example`.** After the existing `require_pre_completion` line (line 40), add the new key with a 2–4 line comment explaining the auto-apply behavior (when `"true"`, `/jim:arch` skips its user-confirmation prompt and applies updates directly). Match the alignment style of the existing `require_*` block.
   **Verify:** `grep -c '^auto_arch_feedback' jimconf.toml.example` returns `1`

3. [x] **Extend ARCHITECTURE.md Scripting Layer entry.** Update line 261's parenthetical from "ten configurable keys" to "eleven configurable keys"; add `auto_arch_feedback` to the inline list of flag keys (alongside `require_pre_commit` and `require_pre_completion`); update the prefix-convention sentence to mention that flag keys may start with `require_` or `auto_`.
   **Verify:** `grep -c 'auto_arch_feedback' ARCHITECTURE.md` returns `1` or higher

4. [x] **Add "Skill-to-Skill Invocation" Plugin Convention to ARCHITECTURE.md.** Insert a new `### Skill-to-Skill Invocation` subsection under "Plugin Conventions", placed after the existing "Subagent Delegation" subsection. Three bullets per Interface Contracts: same-agent execution, use sparingly, anchor by name.
   **Verify:** `grep -c '^### Skill-to-Skill Invocation' ARCHITECTURE.md` returns `1`

5. [x] **Modify `/jim:arch` step 6 to honor `auto_arch_feedback`.** Replace the current step-6 body (lines 80–84 — the "Show … Ask … Do not proceed" three-paragraph block) with the prose from Interface Contracts: resolve the flag via `!`-injection, branch on `"true"` to apply via Edit and summarize without prompting, else run the existing show-and-ask flow, then "Do not proceed."
   **Verify:** `grep -c 'get auto_arch_feedback' skills/arch/SKILL.md` returns `1` or higher

6. [x] **Insert arch feedback step into `/jim:build` completion gate.** In `skills/build/SKILL.md` step 5, insert a new step 2 ("Run the arch feedback step") between the existing pre-completion gate (current step 1, ending at line 113 with `END IF`) and the existing "Report results to the user…" step (currently line 114). The new step uses the inline single-action BASIC form per Interface Contracts. The existing step 2 becomes step 3; existing step 3 becomes step 4.
   **Verify:** Both `grep -c 'get architecture' skills/build/SKILL.md` returns `1` or higher AND `grep -c '/jim:arch' skills/build/SKILL.md` returns `1` or higher

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| `auto_arch_feedback` resolves via `jimfile.sh get auto_arch_feedback`, default `"false"` | 1 |
| Configured override values take precedence over the default | 1 |
| Key reachable via `/jim:conf get` and appears in `/jim:conf list` output | 1 (`case_list_outputs_all_keys` and `case_keys_outputs_valid_keys` cover the surface) |
| `jimconf.toml.example` documents the key with default and explanatory comment | 2 |
| TOML form is flat boolean (no `_path` suffix) | 1 (`resolve()` prefix dispatch + tests verify) |
| Boolean values are double-quoted strings; parser surface unchanged | 1 (no `parse_value` changes) |
| `/jim:build` runs arch step at completion gate after pre-completion, before report | 6 |
| When ARCHITECTURE.md exists, arch step invokes `/jim:arch` via Skill tool | 6 |
| When ARCHITECTURE.md absent, arch step is silently skipped | 6 (BASIC `IF EXISTS` handles implicit skip) |
| Build continues to "report / mark complete" regardless of arch outcome | 6 (no halt language; control returns to next step) |
| Arch step uses canonical `IF (X) EXISTS THEN ... END IF` BASIC idiom | 6 |
| Path resolution via `!`-injection at slash-command load (eager) | 6 |
| `/jim:arch` reads `auto_arch_feedback` before present-and-stop | 5 |
| When `auto_arch_feedback = "true"`, `/jim:arch` applies via Edit, summarizes, no prompt | 5 |
| When `auto_arch_feedback = "false"` (default), existing flow unchanged | 5 |
| Flag affects only user-confirmation gate; scan/generation/summary unchanged | 5 (modification limited to step 6 body) |
| `tests/jimconf.sh` covers default + override for new key | 1 |
| `ARCHITECTURE.md` Scripting Layer names the new key | 3 |

Plus research-driven addition (not an AC): **Skill-to-Skill Invocation Plugin Convention** in ARCHITECTURE.md → Task 4. Addresses Peer Feedback signal #1.

## Out of Scope

(Carried from spec.md.)

- Generalized `auto_*` namespace expansion — only `auto_arch_feedback` in this spec.
- `require_arch_feedback` enforcement flag.
- Optimizing `/jim:arch` for delta-only scan — deferred for `/jim:backlog` to pick up.
- Feedback loops for VISION.md or ROADMAP.md.
- First-time ARCHITECTURE.md creation triggered by `/jim:build`.
- Heuristic-based staleness detection.
- Modifications to the `@jim:architect` agent or the architecture template.

## Open Questions

None — all design decisions resolved via research + design analysis.
