---
name: meta-test
description: >
  Scaffold a new bash test file, append a test case, or run jim's bash-script
  test suite. Use when implementing or extending tests for jim's own deterministic
  bash scripts under skills/*/scripts/ (e.g. jimconf.sh, jimfile.sh). Do not use
  for application-code testing or for testing skill/agent prompts (those are
  validated by checklist, not bash assertions).
agent: meta
argument-hint: "<name> | add <name> <case_name> | run [name]"
allowed-tools: Bash(bash *)
---

# /jim:meta-test

Scaffold, extend, and run jim's plain-bash test suite. Sibling to `/jim:meta-skill` and `/jim:meta-agent` — completes the meta-* family for jim's three deterministic artifact types (skills, agents, bash scripts + their tests).

*(The `agent: meta` field in this frontmatter is a jim documentation convention, not a Claude Code routing mechanism.)*

## Action dispatch

Parse `$ARGUMENTS`. The first token determines the action:

| First token | Action | Gating |
| :--- | :--- | :--- |
| `<name>` (anything except `add` or `run`) | **Scaffold** — create `tests/<name>.sh` from the asset template | 3-gate (Spec + Research + Plan for the script-under-test) |
| `add` | **Add-case** — append `case_<name>_<case_name>()` stub to existing `tests/<name>.sh` | None (invoked inside `/jim:build`'s TDD loop, which has already gated) |
| `run` | **Run** — invoke the test runner (all files, or one file) | None (pure pass-through) |

If `$ARGUMENTS` is empty, tell the user the argument shape and stop:

> Usage:
> - `/jim:meta-test <name>` — scaffold tests/<name>.sh
> - `/jim:meta-test add <name> <case_name>` — append a case stub
> - `/jim:meta-test run [name]` — run all tests, or just one file

Then route to the matching section below.

## Scaffold action — `/jim:meta-test <name>`

The scaffold action creates a new test file. **Plan-gating discipline matches `/jim:meta-skill` and `/jim:meta-agent`** — the new test file must trace back to an approved spec and plan for its script-under-test.

### Pass three gates before scaffolding

`<name>` is the basename of both the script-under-test (e.g., `jimsomething` → `skills/<feature>/scripts/jimsomething.sh`) and the test file to scaffold (`tests/jimsomething.sh`).

**Gate 1 — Spec:** Search `!`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get specs`/jim/` for a spec whose plan creates `skills/<feature>/scripts/<name>.sh`. The spec frontmatter must have `status: approved`. If no approved spec exists, spawn `@jim:pm` via the Agent tool to create one (or tell the user to run `/jim:spec` if pm is unavailable). Stop execution.

**Gate 2 — Research:** Read `research.md` from the spec directory. Confirm it exists and `status:` is `Active` (or `Needs PM Review` / `Needs Architect Review` that the user has acknowledged). If research is missing, spawn `@jim:researcher` (or tell the user to run `/jim:research`). Stop execution.

**Gate 3 — Plan:** Read `plan.md` alongside the spec. The plan must have `status: approved` and must list `skills/<feature>/scripts/<name>.sh` in its File Manifest. If plan is missing or doesn't include the script-under-test, spawn `@jim:architect` (or tell the user to run `/jim:plan`). Stop execution.

After all three gates pass, note the spec's acceptance criteria and the plan's file manifest. The first scaffolded `case_<name>_smoke()` is a placeholder — the coder fills in real assertions during `/jim:build`'s TDD loop, mapping each case back to a spec AC.

### Validate name

`<name>` must be a valid bash identifier matching `^[a-zA-Z_][a-zA-Z0-9_]*$`. Hyphens, dots, slashes, leading digits, and empty are all rejected — both for filesystem safety (no path traversal) and for bash correctness (`case_<name>_*` must be a valid identifier). The dispatcher script enforces this; do not bypass.

### Invoke the dispatcher

`!`bash ${CLAUDE_SKILL_DIR}/scripts/metatest.sh scaffold $ARGUMENTS`

Show the dispatcher's stdout to the user. The output names the file created and the placeholders the user must edit (specifically `__SCRIPT_PATH__` defaults to `skills/CHANGEME/scripts/<name>.sh` — the user replaces `CHANGEME` with the actual feature directory).

If the dispatcher exits non-zero, surface the stderr message and stop. Do not retry without user direction.

## Add-case action — `/jim:meta-test add <name> <case_name>`

The add-case action appends a single test-case stub to an existing test file. No 3-gate ceremony — this action is designed to be called inside `/jim:build`'s TDD loop, where the plan has already been gated upstream.

### Validate inputs

- Both `<name>` and `<case_name>` must be valid bash identifiers (`^[a-zA-Z_][a-zA-Z0-9_]*$`). The dispatcher enforces this.
- `tests/<name>.sh` must exist. If it doesn't, the dispatcher exits 1 with an error directing the user to run `/jim:meta-test <name>` first.
- The case function `case_<name>_<case_name>` must not already exist in the file. If it does, the dispatcher exits 2 — surface the conflict to the user and let them either pick a different name or edit the existing case.

### Invoke the dispatcher

`!`bash ${CLAUDE_SKILL_DIR}/scripts/metatest.sh add $ARGUMENTS`

Show the dispatcher's stdout to the user. The appended stub has a `# AC: TODO — describe the spec acceptance criterion this case verifies.` comment — the coder updates this with the matching AC reference before writing real assertions.

## Run action — `/jim:meta-test run [name]`

The run action invokes the test runner. No gating — running tests is read-only and side-effect-free.

### Dispatch

- `/jim:meta-test run` → runs every `tests/*.sh` via the aggregate runner.
- `/jim:meta-test run <name>` → if `tests/<name>.sh` exists, runs it standalone (faster, file-scoped). Otherwise falls back to filter mode (`bash run.sh <name>`).

### Invoke the dispatcher

`!`bash ${CLAUDE_SKILL_DIR}/scripts/metatest.sh run $ARGUMENTS`

Show the dispatcher's stdout to the user verbatim — the runner's PASS/FAIL output is the relevant signal. The exit code propagates from the underlying runner; non-zero means at least one test failed and the user should investigate.

## Convention reference

The canonical conventions for jim's bash test framework live in the `tests/testlib.sh` header docblock (now at `skills/meta-test/scripts/testlib.sh`). The scaffold template embeds the correct conventions in every new file by construction; do not duplicate them in this skill body.

For the deeper "why" behind `BASH_SOURCE`-relative resolution, `set -uo pipefail` (not `-e`), and the standalone-runnable tail idiom, see also `ARCHITECTURE.md` → Plugin Conventions → Scripting Layer and `CLAUDE.md` → Bash scripts.

## Validation Checklist

After scaffolding or adding a case, confirm:

**Scaffold (new file):**
- [ ] `tests/<name>.sh` exists and is executable (`-x`).
- [ ] First content line is `#!/usr/bin/env bash` (no leading H1, no comment block before shebang — bash requires this).
- [ ] Header docblock cites `skills/meta-test/scripts/testlib.sh` as the canonical conventions reference.
- [ ] Source line is `BASH_SOURCE`-relative (not `${CLAUDE_PLUGIN_ROOT}` — substitution doesn't apply inside script bodies).
- [ ] `SCRIPT="$REPO_ROOT/<path>"` placeholder is set; user knows to replace `CHANGEME` with the real feature directory.
- [ ] Per-script invoker `run_<name>()` is defined and captures stdout/stderr/rc into OUT/ERR/RC.
- [ ] Starter case `case_<name>_smoke()` exists with a `# AC:` comment.
- [ ] Standalone-runnable tail uses the exact form `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then` — not `$BASH_SOURCE` (no index) or `${BASH_SOURCE}` (subtle bash version differences).
- [ ] The tail block has the explanatory comment block above it (DO NOT "tidy" the comment away — it is load-bearing context for future readers).

**Add-case (existing file):**
- [ ] New `case_<name>_<case_name>()` function appended at the end (before the standalone-runnable tail, if present at file end — but the dispatcher appends past the tail; if the user wants the tail to remain last, they reorder manually).
- [ ] Stub has a `# AC: TODO` comment as a reminder to map the case to a spec AC.
- [ ] No existing case was modified or removed.

**Run (any invocation):**
- [ ] Runner output (PASS/FAIL lines + summary) is shown to the user verbatim.
- [ ] Exit code is propagated; if non-zero, the user is told which case(s) failed and offered `/jim:debug` for diagnosis.

## Differential update path

There is no "update an existing scaffolded file" mode — once `tests/<name>.sh` exists, further changes happen via `add` (append a case) or direct editing. Scaffold refuses to overwrite. If the user genuinely needs to regenerate, tell them to delete `tests/<name>.sh` first, then re-run scaffold.

## Anti-patterns to flag

If you notice any of these while running this skill, stop and tell the user:

- **Hyphenated `<name>`:** rejected at the dispatcher layer. The user typed something like `meta-test` or `my-script`. Suggest the underscore-or-camel alternative (`metatest`, `myscript`).
- **Scaffold without an approved spec/plan for the script-under-test:** Gate 1 or Gate 3 will fail. Do not bypass — the meta-skill / meta-agent precedent is that scaffolding without spec+plan defeats the SDLC discipline.
- **Adding cases that drift from spec ACs:** the `# AC: TODO` comment is a hint, not a rule. If the coder is repeatedly adding cases without matching them to ACs, surface this — the spec may need an update.
- **Running `/jim:meta-test run` to "see if it works" mid-edit:** fine occasionally, but if the user is using `run` as their primary feedback loop without TDD discipline, point them at `/jim:build` instead.
