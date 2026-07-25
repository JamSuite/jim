---
title: "Meta skill for authoring and running jim's bash-script tests"
type: feature
group: "platform"
id: "007"
status: approved
origin:
  - docs/brainstorms/20260504-meta-test-skill.md
  - docs/brainstorms/20260504-tests-runner-modularization.md
---

# 007 Meta skill for authoring and running jim's bash-script tests

## Overview
Introduce `/jim:meta-test` — a meta skill (sibling to `/jim:meta-skill` and `/jim:meta-agent`) that scaffolds new test files, appends new test cases to existing files, and runs the test suite for jim's deterministic bash scripts (currently `jimconf.sh` and `jimfile.sh`, plus future siblings).

## Problem Statement

Jim has two existing meta skills — `/jim:meta-skill` and `/jim:meta-agent` — that scaffold the two artifact types `@jim:meta` produces (skills and agents). Jim's third deterministic artifact type is **bash scripts under `skills/*/scripts/`** (`jimconf.sh`, `jimfile.sh`), and those scripts have a corresponding **test surface** under `tests/` (`tests/run.sh`, `tests/testlib.sh`, `tests/jimconf.sh`, `tests/jimfile.sh`) that was implemented without a spec but established a working multi-file pattern: shared lib + per-script test files + `case_*` discovery + standalone-runnable per-file execution.

Three pains follow:

1. **Family asymmetry.** `meta-skill` scaffolds skills, `meta-agent` scaffolds agents, but there is no `meta-test` to scaffold or run tests. When `@jim:coder` (via `/jim:build`) implements a new jim bash script, the recipe for "now add tests" is "find the nearest sibling test file and copy it" — discoverable but not predictable.
2. **Convention drift risk.** The test conventions (case-naming, standalone-runnable tail, source-pattern, mktemp sandbox, heredoc fixtures, no third-party deps) currently live in `tests/testlib.sh`'s header docblock as the canonical reference. Without a scaffolding skill, every new test file is hand-authored; drift can accumulate file-by-file before anyone notices.
3. **No predictable runner surface.** Tests run via `bash tests/run.sh` (all) or `bash tests/jim<x>.sh` (one file). That works, but the `meta-*` family doesn't currently surface any way to invoke the runner, so coder needs out-of-band knowledge of the test commands.

The precedent is `/jim:meta-skill` (specs 001-006 era) and `/jim:meta-agent`. Both encode "non-trivial authorial judgment that the generic coder doesn't carry" — frontmatter design, agent boundaries, tool permissions. The bash-test equivalent is the case-discovery convention, the standalone-runnable tail idiom, the per-test mktemp sandbox, and the no-deps discipline. Centralizing that in a meta skill keeps the convention enforcement local to the act of file creation.

## User Stories

- As `@jim:coder` implementing a new jim bash script under `/jim:build`, I can call `/jim:meta-test <name>` to scaffold the corresponding test file with the correct header docblock, source pattern, invoker stub, and one starter case — so I can immediately enter the TDD red-green loop without copying a sibling file.
- As `@jim:coder` adding a new test case to an existing jim test file, I can call `/jim:meta-test add <name> <case_name>` to append a `case_<name>_<case_name>()` stub in the conventional shape, so I don't have to remember the function-naming and discovery rules.
- As `@jim:coder` (or any developer) wanting to run jim's test suite, I can call `/jim:meta-test run` to run every test file or `/jim:meta-test run <name>` to run one file, without having to remember the underlying `bash tests/...` commands.
- As `@jim:meta` extending jim's plugin component family, I see a predictable `meta-*` surface: meta-skill scaffolds skills, meta-agent scaffolds agents, meta-test scaffolds and runs tests — so the mental model for "build a new jim plugin component" is uniform.
- As a future contributor reading the codebase, I can find the canonical bash-test conventions in one place (the `tests/testlib.sh` header docblock, cited from `/jim:meta-test`'s body) so I don't have to reverse-engineer them from existing test files.

## Acceptance Criteria

- [ ] A `/jim:meta-test` skill exists at `skills/meta-test/SKILL.md`, owned by `@jim:meta`, with the same plan-gating discipline as `/jim:meta-skill` and `/jim:meta-agent` — an approved `spec.md` and `plan.md` must exist before the skill scaffolds anything.
- [ ] **Scaffold action** (`/jim:meta-test <name>`): creates `tests/<name>.sh` from a template containing — at minimum — a header docblock citing `tests/testlib.sh` conventions, a `source` of `testlib.sh`, a `run_<name>()` invoker stub pointing at `skills/<feature>/scripts/<name>.sh`, one starter `case_<name>_smoke()` function, and the standalone-runnable tail (`[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"`).
- [ ] **Add-case action** (`/jim:meta-test add <name> <case_name>`): appends a `case_<name>_<case_name>()` stub to an existing `tests/<name>.sh` file in the conventional shape. Refuses (with a clear stderr message) if the case function already exists.
- [ ] **Run action** (`/jim:meta-test run [name]`): with no argument, runs every test file (equivalent to `bash tests/run.sh`). With a `<name>` argument, runs only that file's cases (equivalent to `bash tests/<name>.sh` if it exists, or `bash tests/run.sh <name>` filter as a fallback). Exit code propagates from the underlying runner.
- [ ] **Free-form name argument.** The `<name>` argument is passed through literally as the filename. No enforced `jim` prefix, no name-mangling. The convention "jim bash scripts get `jim*` filenames" is enforced by the human, not the skill.
- [ ] **Conflict handling.** Scaffold action refuses (with a clear stderr message) if `tests/<name>.sh` already exists; user must delete or use the add-case action.
- [ ] **Convention authority.** Bash-test conventions are documented in **one canonical location** (`tests/testlib.sh` header docblock). The skill body cites that location; the scaffold template embeds the correct conventions in every new file by construction. No duplication of conventions between skill body and lib header.
- [ ] **Doc updates land in the same PR sequence:**
  - `ARCHITECTURE.md` — add `meta-test/` to the skills tree, add it to the "Meta Skills" subgraph in the mermaid diagram, mention it in Plugin Conventions if any new convention is introduced.
  - `README.md` — surface `/jim:meta-test` in whatever command-overview table or skills list lives there, aligned with how `/jim:meta-skill` and `/jim:meta-agent` are presented.
  - `WORKFLOW.md` — fit `/jim:meta-test` into the "building jim itself" section alongside `/jim:meta-skill` / `/jim:meta-agent`. Add it to the meta workflow narrative and any agent-skill composition tables.
  - `CLAUDE.md` — add a `# Bash scripts` section with the load-bearing conventions for jim's bash scripting layer. Kept tight to preserve context budget (target: ~10–12 lines, index-not-encyclopedia). At minimum cover: (1) no `source`/`eval` of user-supplied data — security boundary; (2) no third-party deps — bash + POSIX tools only (grep, sed, cut, tr, awk, find, sort, head); (3) `set -uo pipefail` (not `set -e` — interacts badly with the `OUT=$(run ...)` output-capture pattern the tests rely on); (4) inter-script composition uses `BASH_SOURCE`-relative paths, not `${CLAUDE_PLUGIN_ROOT}` (the latter only substitutes in skill content, not script bodies); (5) pointers to canonical references — `tests/testlib.sh` header for test conventions, `ARCHITECTURE.md` → Scripting Layer for skill↔script composition. Pointer-only — do not duplicate the referenced content in CLAUDE.md.
- [ ] **Retrospective edits to specs 008 and 009.** Both `spec.md` and `plan.md` for `008-jimconf` and `009-jimfile` get a forward-reference paragraph stating that tests for those features now live under the conventions ratified by spec 007, and that future test additions should be scaffolded via `/jim:meta-test`. The retrospective edits are additive — no existing content is rewritten or removed; a "Note (added by spec 007)" block is appended in the appropriate section of each file.
- [ ] **Test surface for `/jim:meta-test` itself.** New `tests/meta-test.sh` (scaffolded by the skill itself, dogfooding) covers: scaffold action produces a file matching the template; add-case action appends correctly; both actions refuse on conflict with the right exit code and stderr message; run action exits 0 on a passing suite and non-zero on a failing one. Tests follow the existing zero-third-party-dep, hand-rolled-bash conventions.
- [ ] **Existing self-hosted specs (001–006, 008, 009) continue to work** without invoking `/jim:meta-test`. The skill is purely additive; nothing about the existing test files (`tests/run.sh`, `tests/testlib.sh`, `tests/jimconf.sh`, `tests/jimfile.sh`) needs to change for them to keep working.

## UI Mockup

```
$ /jim:meta-test jimsomething
✓ Scaffolded tests/jimsomething.sh
  - Header docblock cites tests/testlib.sh conventions
  - Source pattern: source "$(dirname "$0")/testlib.sh"
  - Invoker stub: run_jimsomething ()
  - Starter case: case_jimsomething_smoke ()
  - Standalone-runnable tail
Next: edit tests/jimsomething.sh and write your TDD red.

$ /jim:meta-test add jimsomething handles_empty_input
✓ Appended case_jimsomething_handles_empty_input() to tests/jimsomething.sh

$ /jim:meta-test run
Running tests/jimconf.sh ............ 12 passed
Running tests/jimfile.sh   ............................. 31 passed
Running tests/jimsomething.sh ..                          2 passed
Total: 45 passed, 0 failed

$ /jim:meta-test run jimsomething
Running tests/jimsomething.sh ..  2 passed
```

## Out of Scope

- **Writing actual test cases.** The scaffold and add-case actions produce stubs; coder fills in the body via TDD inside `/jim:build`. Meta-test is the authoring surface, not the test author.
- **Validating convention compliance of existing files.** The skill enforces conventions by construction (every file it scaffolds is correct); it does not audit existing files for drift.
- **Touching application code or non-jim test files.** The skill operates on `tests/<name>.sh` for jim's own bash scripts only.
- **Creating the bash script under test.** That is `/jim:build`'s job, implementing the spec's source-of-truth artifact.
- **Renumbering of prior `007-jimconf` / `008-jimfile` directories.** Already handled manually by the user — current state has the 007 slot free with `008-jimconf` and `009-jimfile` in place. Spec 007 assumes this renumber.
- **Retrofitting existing tests through the skill.** The four existing test files (`tests/run.sh`, `tests/testlib.sh`, `tests/jimconf.sh`, `tests/jimfile.sh`) stay as-is. Only their containing specs (008, 009) get the additive forward-reference note.
- **Cross-agent (Codex/Gemini/Cursor) consumption.** Inherits 007/008/009's stance: hygiene constraints honored where cheap (no TTY, no PLUGIN_ROOT inside script bodies, YAML-frontmatter-first SKILL.md), but no cross-agent integration code is written.
- **`/jim:meta-test` listing or status surfaces** beyond `run`. No `/jim:meta-test list`, no `/jim:meta-test status`. Coder reads the test files directly if needed.
- **Auto-running tests after scaffold.** Scaffold and run are separate actions; the skill does not chain them.

## Open Questions

- [ ] **(architect)** Lib + runner location. Two candidate shapes — please weigh in before deciding:
  - **(i) Status quo.** `tests/run.sh` and `tests/testlib.sh` stay where they are; meta-test scaffolds *into* `tests/`. The runner-and-lib are jim's test infrastructure; they happen to live in `tests/` because that's where bash conventions put them. Pros: zero churn (lib is already written and tested), per-script files at `tests/jim<x>.sh` keep the 1:1 mapping with scripts-under-test. Cons: meta-test "owns" running tests but doesn't own the runner file — a soft separation.
  - **(ii) Move runner-and-lib into the skill.** `skills/meta-test/scripts/run.sh` and `skills/meta-test/scripts/testlib.sh`; per-feature test cases stay at `tests/jim<x>.sh`. Mirrors the "skill owns its toolchain" pattern that `skills/conf/scripts/jimconf.sh` and `skills/file/scripts/jimfile.sh` already established. Per-script files reference the lib via the same `BASH_SOURCE`-relative trick `jimfile.sh` uses to call `jimconf.sh` (`source "$(dirname "${BASH_SOURCE[0]}")/../skills/meta-test/scripts/testlib.sh"`). Standalone-runnability survives. `/jim:meta-test run` invokes `bash skills/meta-test/scripts/run.sh` directly, giving the skill clean ownership of the runner file. Cons: the standalone-run command for a per-script file becomes longer (the source path is two-deep), and there's a one-time move-and-update of every existing test file.
  - **(iii) Move both runner-and-cases into the skill** (`skills/meta-test/tests/...`). Cleanest "skill owns its toolchain" but odd — every jim feature's tests live under one skill's directory. Flagging for completeness; not strongly considered.
  - User's lean: option (ii) feels right because if the skill runs the suite, the skill should own the runner. Architect to validate or counter.
- [ ] **(architect)** Update-mode argument validation. If `/jim:meta-test add jimconf existing_case_name` is called and the case already exists, the spec says "refuse with stderr message and non-zero exit." Architect to specify exact message and exit code (recommend exit 2, mirroring `jimconf.sh`'s "malformed invocation" code).
- [ ] **(architect)** `run` action: when `<name>` is passed, prefer `bash tests/<name>.sh` (standalone-execution path, faster, file-scoped) or `bash tests/run.sh <name>` (filter path, consistent with run-all)? Both produce the same result for current cases; the standalone path is slightly faster but couples the skill to the standalone-runnable tail being present. Recommend defaulting to standalone-execution with a fallback to the filter if the file doesn't exist.
- [ ] **(architect)** Where the scaffold template lives. Likely `skills/meta-test/assets/test-file.sh.tmpl` (mirrors `meta-skill`'s `assets/` pattern), but architect to ratify in plan.
