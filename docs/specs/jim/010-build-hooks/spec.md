---
title: "Configurable build hooks — per-commit and pre-completion gates"
type: feature
group: "jim"
id: "010"
status: approved
---

# 010 Configurable build hooks — per-commit and pre-completion gates

## Overview

Add two cadences of build hooks to `/jim:build` — a per-commit gate that fires at every TDD commit point and a pre-completion gate that fires at the completion-gate step — each backed by an existence-gated configurable script and an optional `require_*` flag for hard enforcement.

## Problem Statement

TDD discipline depends on per-commit quality checks. Today `/jim:build` runs the configured pre-commit script only at the completion gate (after every plan task is marked `[x]`), so quality checks are skipped on every intermediate Red, Green, and Tidy commit. When the final gate fails, broken or sloppy commits have already landed across the build — fixing them produces additional commits that add noise to the history and erode the per-commit testability TDD is supposed to provide.

Running the same script *again* at the completion gate after it just ran on the previous commit is redundant; the completion gate naturally wants a different cadence — typically a full CI suite — that catches integration-level issues a per-commit script wouldn't.

There is also no way today to require that a gate be present rather than silently skipped when its script is absent. That leaves projects in inconsistent states across team members: one engineer's local build runs gates, another's silently skips them, and neither situation surfaces as a configuration error.

## User Stories

- As a developer using `/jim:build`, I can configure a per-commit script that runs before every Red, Green, and Tidy commit, so that broken commits never land in my history.
- As a developer using `/jim:build`, I can configure a separate pre-completion script (e.g., a full CI suite), so that end-of-build verification has a different cadence than per-commit checks.
- As a project maintainer running jim across a team, I can mark either gate as required, so that a missing gate script halts the build instead of silently skipping.
- As a developer with no jim configuration, I can run `/jim:build` without changing anything, so that zero-config behavior is preserved.

## Acceptance Criteria

**Configuration surface**

- [ ] New config key `pre_completion_path` resolves via `bash skills/file/scripts/jimfile.sh get pre_completion`, with default `./pre-completion.sh`.
- [ ] New config key `require_pre_commit` resolves via the same surface, with default `"false"`.
- [ ] New config key `require_pre_completion` resolves via the same surface, with default `"false"`.
- [ ] Each new key is reachable through `/jim:conf get <key>` and appears in `/jim:conf list` output.
- [ ] `jimconf.toml.example` documents all three new keys with their defaults and a short comment naming the gate each governs.
- [ ] Configured override values for any of the three new keys take precedence over defaults (parity with existing keys).
- [ ] `require_*` values are double-quoted strings (`"true"` / `"false"`); the `jimconf.sh` parser surface is unchanged.

**`/jim:build` behavior**

- [ ] `/jim:build` runs the resolved `pre_commit_path` script via Bash immediately before each commit in step 3 — Red, Green, and Tidy phases for feature and bug specs, and structural commits for refactor specs.
- [ ] `/jim:build` runs the resolved `pre_completion_path` script via Bash at step 5 (completion gate), replacing the current pre-commit invocation at that step.
- [ ] On a script's non-zero exit, `/jim:build` halts and reports the script's full output. The current task is not marked `[x]`. The next phase does not begin. The build waits for human guidance.
- [ ] When a gate's script is absent and its `require_*` flag is `"false"`, `/jim:build` skips the gate silently — no warning, no error.
- [ ] When a gate's script is absent and its `require_*` flag is `"true"`, `/jim:build` halts with the message `Required <gate-name> script not found at <path>` and waits for human guidance.
- [ ] Both gates use the canonical `IF (X) EXISTS THEN DO: ... DONE` BASIC idiom (no invented variants).
- [ ] Both gates resolve their script paths via Claude Code's `!`-injection at slash-command load (eager substitution).

**Tests and docs**

- [ ] `tests/jimconf.sh` covers default resolution, configured override, and `-c <path>` behavior for `pre_completion`, `require_pre_commit`, and `require_pre_completion`.
- [ ] `ARCHITECTURE.md` Scripting Layer section names the three new keys alongside the existing seven.

## Out of Scope

- Generalized `workflow.*` config namespace (e.g., `require_research`, `require_plan_approval`, `require_security`). A future spec may introduce these; this spec only adds the two `require_*` keys it needs.
- Bare-boolean TOML parsing (`require_pre_commit = true` without quotes). Boolean values remain double-quoted strings to keep the existing parser surface unchanged.
- Conversational bypass language at gates (e.g., "proceed anyway"). When a gate halts, the human directs the next move; there is no skill-level override.
- Backward-compatibility migration tooling — no existing project config uses these key names.
- New `bin/` helper layer or hook dispatcher (the fork's `bin/jim_run_hook` and `{jim_run_hook}` placeholder pattern is not adopted).
- Per-phase opt-out (e.g., "skip pre-commit on Red commits only"). Pre-commit fires on every commit by design.
- Modifications to `/jim:debug`, `/jim:plan`, or other skills. The change is isolated to `/jim:build`, `/jim:conf`, `jimconf.sh`, and the example/test surfaces.

## Open Questions

None — design decided in spec interview.
