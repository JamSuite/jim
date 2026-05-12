---
title: "Post-build ARCHITECTURE.md feedback loop"
type: feature
group: "jim"
id: "013"
status: approved
---

# 013 Post-build ARCHITECTURE.md feedback loop

## Overview
After `/jim:build`'s pre-completion gate succeeds, automatically invoke `/jim:arch` in differential update mode so ARCHITECTURE.md stays current with what was just built. A new `auto_arch_feedback` config flag (default `"false"`) bypasses `/jim:arch`'s user-confirmation step for projects that want hands-off documentation maintenance.

## Problem Statement
ARCHITECTURE.md is treated as a locked constraint by `/jim:spec`, `/jim:plan`, `/jim:research`, and `/jim:vision` — every other skill reads it as the project's technical ground truth. But nothing in the workflow signals when it has drifted from reality. After `/jim:build` changes the codebase, new components, dependencies, entry points, or data flows may exist that ARCHITECTURE.md doesn't mention. Downstream skills then enforce stale constraints or miss new architectural elements entirely.

The gap is silent: no skill fails, no gate catches it. The architecture document degrades gradually until someone notices manually, and the longer the drift goes uncorrected, the larger the eventual reconciliation effort.

`/jim:arch` already supports differential update natively — scan codebase, diff against the existing document, present changes for human approval. What's missing is a workflow trigger that fires automatically when the build that caused the drift is the same build that finishes.

## User Stories
- As a developer using `/jim:build`, I can have ARCHITECTURE.md refresh automatically after each build so the next planning cycle isn't constrained by stale architecture.
- As a developer running fast iterations, I can opt in to auto-applying architecture changes without an extra confirmation step, trading the review gate for speed.
- As a developer with no ARCHITECTURE.md (early-project or intentionally absent), I see `/jim:build` proceed unchanged — the feedback loop is opt-in via the document's existence.
- As a developer running `/jim:build` against a spec where the architect's review of changes matters, I get the existing `/jim:arch` user-confirmation gate by default.

## Acceptance Criteria

**Configuration surface — flag dispatch extension**
- [ ] `jimconf.sh`'s `resolve()` dispatcher recognizes `auto_*` as a flag-style key prefix alongside `require_*` — keys matching either prefix are read as flat boolean-shaped strings without a `_path` suffix.
- [ ] `auto_arch_feedback` is added to `jimconf.sh`'s `KEYS=(...)` list and to its defaults switch with default value `"false"`.
- [ ] `bash skills/file/scripts/jimfile.sh get auto_arch_feedback` resolves through the same dispatch path as `require_pre_commit` / `require_pre_completion` (no `_path` suffix appended).
- [ ] A configured override in `jimconf.toml` takes precedence over the default (parity with existing flag keys).
- [ ] The key is reachable through `/jim:conf get auto_arch_feedback` and appears in `/jim:conf list` output.
- [ ] `jimconf.toml.example` documents the key with its default and a short comment naming the gate it governs.
- [ ] In `jimconf.toml`, the key is written as a flat boolean: `auto_arch_feedback = "true"` or `auto_arch_feedback = "false"`. Double-quoted string booleans, no `_path` suffix.
- [ ] `jimconf.sh`'s parser surface (TOML parsing, `set -uo pipefail`, no `source`/`eval`, no third-party deps) is unchanged — only the prefix dispatcher and the keys/defaults tables are touched.

**`/jim:build` behavior**
- [ ] `/jim:build`'s completion gate (step 5) runs an arch-feedback step after the pre-completion gate succeeds and before the existing "report results to the user" step.
- [ ] The arch-feedback step is structured per the post-011 directive vocabulary (`ARCHITECTURE.md` → Logic-Flow Conventions):

      SET arch_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`

      IF arch_doc EXISTS THEN
        Invoke /jim:arch via the Skill tool to refresh ARCHITECTURE.md against the just-built code.
      ENDIF
- [ ] The retired BASIC `IF (X) EXISTS THEN ... END IF` idiom is not used (see `ARCHITECTURE.md:346` anti-pattern note); the `!`-injection slot never appears inside `(...)`.
- [ ] When the architecture path does not exist on disk, the arch-feedback step is silently skipped (no warning, no prompt).
- [ ] After the arch step resolves (changes applied, no changes needed, or user declined), `/jim:build` continues to the existing "report results / mark complete?" step regardless of `/jim:arch`'s outcome.
- [ ] `/jim:build`'s `allowed-tools` frontmatter is extended to permit invoking the `arch` skill via the Skill tool (Skill scoping consistent with spec 012).

**`/jim:arch` behavior**
- [ ] `/jim:arch` reads `auto_arch_feedback` before its present-and-stop step (step 6).
- [ ] The read uses a `SET auto_arch_feedback = !\`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get auto_arch_feedback\`` binding (no `!`-injection inside parens).
- [ ] The gate is an explicit two-branch `IF … ELSE … ENDIF` — both branches are named, not implicit fall-through — because both the `"true"` and `"false"` paths have distinct behavior:

      IF auto_arch_feedback == "true" THEN
        Write the proposed update directly to the configured architecture path. Summarize which sections were added, changed, or preserved.
      ELSE
        Present the diff and ask: "Does this look accurate? Any sections to refine?" Wait for confirmation.
      ENDIF
- [ ] When the bound value is `"true"`, `/jim:arch` writes the proposed update directly to the configured architecture path, skipping the user-confirmation prompt. The post-write output still summarizes which sections were added, changed, or preserved.
- [ ] When the bound value is `"false"` (default), `/jim:arch`'s existing user-confirmation flow runs unchanged (present diff, ask "Does this look accurate? Any sections to refine?", stop).
- [ ] The flag affects only the user-confirmation gate at step 6; the codebase scan (step 4), document generation (step 5), and the change-summary content are unchanged.
- [ ] `/jim:arch`'s `allowed-tools` frontmatter is extended to permit reading `auto_arch_feedback` via the same `jimfile.sh get` clause already present.

**ARCHITECTURE.md updates**
- [ ] `ARCHITECTURE.md` documents the `auto_*` prefix as a recognized flag-key family alongside `require_*` in the jimconf/jimfile section (currently `ARCHITECTURE.md:261`).
- [ ] The post-build arch-feedback loop is described in the relevant component section of `ARCHITECTURE.md` (build skill / arch skill components) — one short paragraph naming the gate, the flag, and the existence-conditioned trigger.
- [ ] `ARCHITECTURE.md` Plugin Conventions → Skill Invocation adds a one-line note naming `Skill(jim:arch)` as the permission token syntax for skill-to-skill invocation — this is the first instance of one jim skill invoking another via the Skill tool and sets the precedent for future cross-skill calls.

**Tests and docs**
- [ ] `tests/jimconf.sh` adds cases covering: default resolution for `auto_arch_feedback` (returns `"false"`), configured-override resolution (returns the value from a sample `jimconf.toml`), and `-c <path>` behavior (returns the value from the supplied config). These per-key cases are the dispatcher-contract test — they exercise the `auto_*` flag-prefix path end-to-end; no separate synthetic fixture key is added to `KEYS`.
- [ ] The five `tests/jimconf.sh` enumeration cases that iterate every key in `KEYS` (`case_no_config_returns_defaults`, `case_full_config_returns_overrides`, `case_list_outputs_all_keys`, `case_keys_outputs_valid_keys`, `case_malformed_lines_are_ignored`) are extended: `auto_arch_feedback` is added to each case's expected set and the hardcoded key-count literals move from `10` to `11`. These are additive row additions — the case structure, assertions, and behavioral semantics are unchanged.
- [ ] No new test surface is added for the `/jim:build` → `/jim:arch` invocation itself (prompt-driven control flow is validated by the meta-skill / meta-agent author-time checklists, not by bash tests — consistent with the convention codified in spec 011).

**Mandatory for feature type**
- [ ] Existing test semantics are preserved: `bash skills/meta-test/scripts/run.sh` exits zero after all enumeration cases are extended per the AC above. "Pass without modification" means no behavioral regressions — the five enumeration cases are extended (same shape, more rows), not structurally changed.

## Data Flow

```mermaid
flowchart TD
    A[/jim:build: all tasks complete] --> B[Step 5.1: pre-completion gate]
    B -->|exit 0| C[Step 5.2: arch-feedback step]
    C --> D{SET arch_doc resolved;<br/>does it exist on disk?}
    D -->|no| F[Step 5.3: report and ask 'mark complete?']
    D -->|yes| E[Invoke /jim:arch via Skill]
    E --> G{auto_arch_feedback == 'true'?}
    G -->|yes| H[Write update directly,<br/>summarize changes]
    G -->|no| I[Present diff,<br/>wait for user confirmation]
    H --> F
    I --> F
```

## Out of Scope
- **Change-detection heuristics inside `/jim:build`.** `/jim:build` does not inspect git diff, count new files, or otherwise pre-judge whether `/jim:arch` is "worth" invoking. `/jim:arch` is the single authority on architectural drift; duplicating that detection would invite divergence.
- **Auto-commit of ARCHITECTURE.md updates.** When `auto_arch_feedback = "true"`, `/jim:arch` writes the file but does not commit it. Committing is a separate user/agent decision.
- **Retroactive sweeps for old builds.** This loop fires only on builds that complete *after* the feature ships. It does not retroactively diff prior plans against the current ARCHITECTURE.md.
- **Other documents in the locked-constraint family.** VISION.md and ROADMAP.md are not refreshed by this loop. The architecture document is the only one downstream skills treat as a *technical* ground truth subject to silent drift; vision/roadmap drift is a strategic concern with different cadence.
- **A new top-level flag namespace beyond `auto_*` and `require_*`.** This spec extends the dispatcher to recognize one additional prefix; it does not generalize to `enable_*`, `skip_*`, or arbitrary author-chosen prefixes.
- **Automated lint enforcing the post-011 directive shape.** Already excluded by spec 011; the four enforcement surfaces from 011 cover this spec's gate as well.
- **`require_arch_feedback` enforcement flag.** This spec adds the opt-in convenience flag only. Design choice is to trust `/jim:arch`'s own user-confirmation gate; `/jim:build` never blocks completion on a declined arch update. A `require_*` counterpart can be added by a future spec if it earns its keep.
- **Delta-only `/jim:arch` mode (scan only files changed since the last build).** Full codebase scan on every post-build invocation is acceptable for this spec. Deferred — a candidate for `/jim:backlog` to pick up as a future enhancement once that skill lands.
- **First-time ARCHITECTURE.md generation from `/jim:build`.** When the configured architecture path does not exist, the arch-feedback step is silently skipped. Creating a fresh architecture document is a deliberate `/jim:arch` invocation, not a build side-effect — the loop refreshes an existing doc, it never bootstraps a new one.
- **Modifications to the `@jim:architect` agent or the `assets/architecture-template.md`.** This spec changes when and how `/jim:arch` is invoked and gated; it does not change what the architect agent produces or the structure of the architecture document.

## Open Questions
- [x] ~Should `/jim:arch`'s auto-apply path emit a one-line "no drift detected" summary when there are no changes?~ → **No.** Silent on no-change is preferred; `/jim:build`'s "mark complete?" step does not need extra noise.
- [x] ~Should `/jim:build` log a declined `/jim:arch` outcome into `plan.md`?~ → **No.** Continue silently. `/jim:build`'s `plan.md` write surface stays limited to marking tasks `[x]`; git history is the implicit audit trail. If repeated re-prompting becomes painful, a future spec can add proper drift-suppression rather than a bare log line.
