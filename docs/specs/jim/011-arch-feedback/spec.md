---
title: "Post-build ARCHITECTURE.md feedback loop"
type: feature
group: "jim"
id: "011"
status: approved
---

# 011 Post-build ARCHITECTURE.md feedback loop

## Overview

After `/jim:build`'s pre-completion gate succeeds, automatically invoke `/jim:arch` in differential update mode so ARCHITECTURE.md stays current with what was just built. Add an `auto_arch_feedback` config flag (default `"false"`) that bypasses `/jim:arch`'s user-confirmation gate when projects want hands-off documentation maintenance.

## Problem Statement

ARCHITECTURE.md is treated as a locked constraint by `/jim:spec`, `/jim:plan`, `/jim:research`, and `/jim:vision` — every other skill reads it as the project's technical ground truth. But nothing in the workflow signals when it has drifted from reality. After `/jim:build` changes the codebase, new components, dependencies, entry points, or data flows may exist that ARCHITECTURE.md doesn't mention. Downstream skills then enforce stale constraints or miss new architectural elements entirely.

The gap is silent: no skill fails, no gate catches it. The architecture document degrades gradually until someone notices manually, and the longer the drift goes uncorrected, the larger the eventual reconciliation effort.

`/jim:arch` already supports differential update natively — scan codebase, diff against the existing document, present changes for human approval. What's missing is a workflow trigger that fires automatically when the build that caused the drift is the same build that finishes.

## User Stories

- As a developer using `/jim:build`, I want ARCHITECTURE.md to stay current after each build so the next planning cycle isn't constrained by stale architecture.
- As a developer running fast iterations, I want the option to auto-apply architecture changes without an extra confirmation step, accepting that I'm trading a review gate for speed.
- As a developer with no ARCHITECTURE.md (early-project or intentionally absent), I want `/jim:build` to proceed unchanged — the feedback loop is opt-in via the document's existence.
- As a developer running `/jim:build` against a spec where the architect's review of changes matters, I want the existing user-confirmation gate to run by default.

## Acceptance Criteria

**Configuration surface**

- [ ] New config key `auto_arch_feedback` resolves via `bash skills/file/scripts/jimfile.sh get auto_arch_feedback`, with default `"false"`.
- [ ] Configured override values for the key take precedence over the default (parity with existing keys).
- [ ] The key is reachable through `/jim:conf get auto_arch_feedback` and appears in `/jim:conf list` output.
- [ ] `jimconf.toml.example` documents the key with its default and a short comment naming the gate it governs.
- [ ] In `jimconf.toml`, the key is written as a flat boolean (no `_path` suffix): `auto_arch_feedback = "true"` or `auto_arch_feedback = "false"`.
- [ ] Boolean values are double-quoted strings; `jimconf.sh`'s parser surface is unchanged.

**`/jim:build` behavior**

- [ ] `/jim:build`'s completion gate (step 5) runs an arch feedback step after the pre-completion gate succeeds and before the existing "report results to the user" step.
- [ ] When ARCHITECTURE.md exists at the configured path, the arch step invokes `/jim:arch` via the Skill tool.
- [ ] When ARCHITECTURE.md does not exist at the configured path, the arch step is silently skipped.
- [ ] After the arch step resolves (changes applied, no changes needed, or user declined), `/jim:build` continues to the existing "report / mark complete?" step regardless of arch's outcome.
- [ ] The arch step uses the canonical `IF (X) EXISTS THEN ... ELSE ... END IF` BASIC idiom (no invented variants).
- [ ] Path resolution uses Claude Code's `!`-injection at slash-command load (eager substitution).

**`/jim:arch` behavior**

- [ ] `/jim:arch` reads `auto_arch_feedback` before the present-and-stop step.
- [ ] When `auto_arch_feedback = "true"`, `/jim:arch` writes the proposed update directly, skipping the user-confirmation prompt. Output still summarizes what was applied.
- [ ] When `auto_arch_feedback = "false"` (default), `/jim:arch`'s existing user-confirmation flow runs unchanged.
- [ ] The flag affects only the user-confirmation gate; codebase scan, doc generation, and present-changes-summary behavior are unchanged.

**Tests and docs**

- [ ] `tests/jimconf.sh` covers default resolution, configured override, and `-c <path>` behavior for `auto_arch_feedback`.
- [ ] `ARCHITECTURE.md` Scripting Layer entry names the new key alongside the existing keys.

## Out of Scope

- Generalized `auto_*` config namespace (e.g., `auto_research_approval`, `auto_plan_approval`). This spec only adds the one `auto_*` key it needs; future specs may extend the family.
- `require_arch_feedback` enforcement flag. Design choice is to trust `/jim:arch`'s own gate, not block build completion on user rejection. Easy to add later if needed.
- **Optimizing `/jim:arch` to scan only files changed since the last build** (delta-only mode). Full codebase scan on every build is acceptable for now. **Deferred** — intended for `/jim:backlog` to pick up as a future enhancement when that skill lands.
- Feedback loops for VISION.md or ROADMAP.md. Different concerns; separate specs if needed.
- Creating ARCHITECTURE.md when absent (first-time generation triggered by `/jim:build`). Creating an architecture document is a deliberate `/jim:arch` invocation, not a build side-effect.
- Heuristic-based staleness detection. We use `/jim:arch`'s real codebase scan, not pattern matching.
- Modifications to the `@jim:architect` agent or the architecture template.

## Open Questions

None — design decided in spec interview.
