---
spec: "docs/specs/jim/007-meta-test/spec.md"
status: Needs Architect Review
date: "2026-05-05"
---

# Research: Meta skill for authoring and running jim's bash-script tests

## Anchors

**Direct precedent — the two existing meta skills (the shape to mirror):**

- `skills/meta-skill/SKILL.md` (~470 lines) — frontmatter `name`, `description`, `agent: meta`, `argument-hint`, `allowed-tools: Bash(bash *)`. Body: 3-gate discipline (Spec → Research → Plan), then a 19-point Validation Checklist. No `assets/`, no `references/`.
- `skills/meta-agent/SKILL.md` (~480 lines) — identical frontmatter shape, identical 3-gate gating. Differs only in artifact type and example block format.
- `agents/meta.md` (L1–64) — `tools: [Agent(pm, architect, researcher), Read, Write, Edit, Glob, Grep]`, `model: sonnet`, `skills: [meta-skill, meta-agent]`. **No direct Bash permission** on the agent. Body explicitly: *"No Code Execution — You build markdown artifacts only."*

**Test infrastructure (the system meta-test wraps):**

- `tests/testlib.sh:3-44` — header docblock; canonical conventions reference. Documents: `case_*` discovery, source pattern, mktemp sandbox, standalone-runnable idiom, no-deps discipline, fixture/inline heredoc rule.
- `tests/testlib.sh:58-59` — `TMP_BASE="$(mktemp -d -t jim-tests.XXXXXX)"` + trap cleanup. Per-test sandbox.
- `tests/run.sh:43-50` — entry-point logic: globs `tests/*.sh`, excludes `run.sh` and `testlib.sh`, sources each, runs `run_discovered_cases`. `$1` = filter substring.
- `tests/jimconf.sh:16-17, 28-33, 183-189` — per-script template: HERE-relative source, `run()` invoker capturing OUT/ERR/RC, standalone-runnable tail.
- `tests/jimfile.sh:17-18, 27-32, 325-331` — same template, with `run_jimfile()` invoker. Confirms the per-file pattern is now established (two examples).

**Standalone-runnable tail (exact form, both files):**

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ ! -e "$SCRIPT" ]]; then
    echo "NOTE: script under test not found at $SCRIPT — every test will fail."
  fi
  FILTER="${1:-}"
  run_discovered_cases
fi
```

**BASH_SOURCE-relative inter-script call (Option ii precedent):**

- `skills/file/scripts/jimfile.sh:51` — `JIMCONF="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../conf/scripts" && pwd)/jimconf.sh"`. Two levels up + sibling-script descent. Resolves to absolute via `pwd`. Survives plugin relocation to `.agents/skills/`.

**Retrospective-edit anchors (specs 008/009):**

- `docs/specs/jim/008-jimconf/spec.md:75-76` — Open Question on testing strategy, resolved with reference to `tests/run.sh`. Insert "Note (added by spec 007)" forward-reference paragraph after L76.
- `docs/specs/jim/009-jimfile/spec.md:59-60` — AC mentioning "tests/" with "zero-dependency and strict-documentation conventions established by 007". Insert forward-reference paragraph after L60.
- Plan files (`008-jimconf/plan.md` Decision 4 region, `009-jimfile/plan.md` Decision 9 region) — same pattern, additive paragraph in the testing decision section.

**Doc-update anchors (per spec ACs):**

- `ARCHITECTURE.md:23-42` (skills tree, last entry `meta-agent/`), `:84-87` (mermaid Meta Skills subgraph), `:246-255` (Plugin Conventions → Scripting Layer subsection — currently scopes only `jimconf.sh` and `jimfile.sh`).
- `README.md:38-51` (commands table — last meta entry `/jim:meta-agent`), `:138-149` (test running section).
- `WORKFLOW.md:52-66` (command reference table), `:134-202` (plugin directory tree), `:387-398` ("Building Jim with Jim" section).

**New files (paths the architect will ratify):**

- `skills/meta-test/SKILL.md` — user-facing skill body.
- `skills/meta-test/assets/test-file.sh.tmpl` — scaffold template (likely; first meta skill to need an asset because the artifact is a real file copy, not a generated-from-spec markdown body).
- `tests/meta-test.sh` — dogfood test of the skill itself.

## Local Patterns

- **Meta-skill discipline:** plan-gated, 3-gate (Spec → Research → Plan), spawns sub-agents for gate checks, halts on failure. `/jim:meta-test` should adopt the identical pattern (spec ACs already mandate this).
- **`!`-injection composition** (canonical pattern from `/jim:conf` and `/jim:file`): consumer skills declare `allowed-tools: Bash(bash *)` and use `` !`bash <script> $ARGUMENTS` `` in the body. Output replaces the placeholder *before* the LLM reads it. **The agent does not need Bash tool access** because `!`-injection runs at content-render time, not as an agent tool call.
- **Argument dispatch** (verb-first, positional): `jimconf.sh` uses `get|list|path|keys`, `jimfile.sh` uses `exists|slug|date|next-id|path|glob|kinds`. The spec's chosen surface (`<name>` / `add <name> <case>` / `run [name]`) follows this house style.
- **Test template (per `research-dod.md` rule 3):** `tests/jimconf.sh` and `tests/jimfile.sh` are both viable templates for the dogfood `tests/meta-test.sh`. They demonstrate the source line, invoker shape, case-naming, and standalone-runnable tail.
- **Asset directory pattern is novel for meta skills.** Neither `meta-skill` nor `meta-agent` ships an `assets/` directory — both generate target content from spec text. `/jim:meta-test` is the first meta skill that copies a real **file template** (because the target is a bash file with non-trivial structure, not markdown derived from interview content). Architect ratifies the location.
- **Standalone-runnable tail idiom (load-bearing — must ship with explanatory comments in the scaffold template).** Both `tests/jimconf.sh:183-189` and `tests/jimfile.sh:325-331` end with:
  ```bash
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    FILTER="${1:-}"
    run_discovered_cases
  fi
  ```
  `${BASH_SOURCE[0]}` is the file bash is currently reading; `${0}` is the file bash was invoked with. They match only on direct invocation (`bash tests/jimfile.sh`) and diverge when the aggregate runner sources the file (`bash tests/run.sh` sources `jimfile.sh` → inside jimfile.sh, `${BASH_SOURCE[0]}` = jimfile.sh, `${0}` = run.sh). This is the mechanism that makes both standalone (`bash tests/jimfile.sh`) and aggregate (`bash tests/run.sh`) execution work without duplicating dispatch logic. The exact form matters — `$BASH_SOURCE` (no index) or `${BASH_SOURCE}` are subtly different and break in older bash. The scaffold template must include this block **with a comment block above it explaining what it does and why**, so future readers don't "fix" it into something that breaks aggregate runs.

## Security & Performance

- **No new attack surface introduced.** `/jim:meta-test` orchestrates file creation in `tests/` and shells out to the existing test runner. It does not parse user-supplied config, accept network input, or invoke `eval`/`source` on untrusted data. The `<name>` argument flows into a filename — same exposure profile as `/jim:meta-skill <name>` (which writes `skills/<name>/SKILL.md`).
- **Filename validation needed.** `<name>` reaches `tests/<name>.sh`. If left fully free-form, `/jim:meta-test ../../etc/badfile` would write outside `tests/`. Recommended: same kebab-case sanitation rule as `jimfile.sh slug` (reject `..`, `/`, control chars, empty result), but lighter — no length cap needed for filenames since human authors will type a sensible string. Architect to specify.
- **Runner orchestration via `!`-injection is fast.** `bash tests/run.sh` currently runs ~45 cases in under 2 seconds; well within `!`-injection's per-invocation budget. No caching needed.
- **No-TTY hygiene** (inherited from 007/008/009): the scaffold template must produce files that don't assume a TTY (no `read -p`, no terminal colors). Existing test files already follow this.
- **Permission boundary.** The `/jim:meta-test` skill's `allowed-tools: Bash(bash *)` restricts `!`-injection to bash invocations only. The `Write` and `Edit` tools (for scaffolding and add-case) come from the agent's tool list — `@jim:meta` already has both.

## Recommendations

Decisions belong to the architect; this section frames trade-offs.

### Lib + runner location (spec Open Question, architect to decide)

The spec asked for the architect's read on three options. Research surfaces one new constraint that affects the call: **`!`-injection works the same regardless of where the runner lives**, because `${CLAUDE_PLUGIN_ROOT}` resolves the path before bash runs. So the choice is layout/symmetry, not runtime.

- **Option (i) status quo** (`tests/run.sh` + `tests/testlib.sh` stay): zero churn. The runner is "jim's test infrastructure," and `tests/` is where bash conventions put it. Soft separation: meta-test owns *running* but not the *runner file*.
- **Option (ii) move runner-and-lib into skill** (`skills/meta-test/scripts/run.sh` + `testlib.sh`): symmetric with `skills/conf/scripts/jimconf.sh` and `skills/file/scripts/jimfile.sh`. Clean ownership — the skill that runs the suite owns the runner. Per-script files at `tests/jim<x>.sh` source the lib via the same BASH_SOURCE-relative trick `jimfile.sh` already uses (`source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/meta-test/scripts" && pwd)/testlib.sh"`). Standalone-runnability survives. One-time move + four file edits (`tests/jimconf.sh`, `tests/jimfile.sh`, the new `tests/meta-test.sh`, the source line in each).
- **Option (iii) move both runner and cases into skill**: rejected by research — flatly conflicts with the established `tests/` conventions and forces every future jim feature's tests to live under one skill's directory. Cite for completeness only.

User's lean (recorded in spec): **option (ii)**. Research finds no runtime blocker. The standalone-execution path becomes `bash tests/jimfile.sh` → sources `skills/meta-test/scripts/testlib.sh` via BASH_SOURCE-relative path. Identical UX to today.

### Frontmatter and skill body shape

Mirror `meta-skill`/`meta-agent` exactly:

```yaml
---
name: meta-test
description: >
  Scaffold a new bash test file, append a case to an existing file, or run jim's test suite.
  Use when ...
agent: meta
argument-hint: "<name> | add <name> <case_name> | run [name]"
allowed-tools: Bash(bash *)
---
```

Body adopts the 3-gate (Spec → Research → Plan) discipline if the action is `<name>` (scaffold) or `add` — both create persistent artifacts. The `run` action **bypasses gating** (no plan involved; just invoke the runner via `!`-injection). Architect to confirm.

### Scaffold template location

Two candidates:
- `skills/meta-test/assets/test-file.sh.tmpl` — mirrors agentskills.io convention; standard `assets/` location even though no other meta skill uses it yet. Recommended.
- Inline in the SKILL.md body (heredoc): tighter coupling, but pollutes the SKILL.md with bash content and pushes body length toward the 500-line ceiling.

### Header docblock content

Per the spec's "cite-only" decision: the scaffold template's header docblock should be ~10–15 lines that **cite** `tests/testlib.sh:3-44` as the canonical conventions reference, plus per-script specifics (which script-under-test, the sibling location). Don't restate the 40-line testlib header in every per-script file.

### `run` action implementation

Per the spec's Open Question: prefer the standalone-execution path when a `<name>` is given (`bash tests/<name>.sh`), with fallback to `bash tests/run.sh <name>` (filter mode) if the file doesn't exist. The standalone path is faster (no glob, no source-everything) and reinforces the "filename is a runnable target" DX. With `!`-injection: `` !`bash tests/<name>.sh` `` or `` !`bash tests/run.sh` `` — the LLM sees the test output as part of the rendered skill body.

### Update-mode argument validation

The spec asks the architect to specify exact exit code and stderr message for "case already exists." Recommend:
- Exit code **2** (matches `jimconf.sh`'s "malformed invocation" semantics — invalid input, not script error).
- Stderr message: `Error: case_<name>_<case_name> already exists in tests/<name>.sh` (parseable, names the conflict).

## Peer Feedback

→ **For Architect:** **Three-gate discipline applies cleanly to `<name>` and `add` actions; `run` is a pass-through and shouldn't be gated.** `<name>` (scaffold) and `add <name> <case>` both create persistent artifacts — the existing meta-skill / meta-agent gating discipline (Spec → Research → Plan) maps cleanly. The `run` action invokes the existing runner with no spec/plan tie — gating it would create awkward "is there a plan for running tests?" checks. Plan should specify gating **per-action**, not skill-wide.

→ **For Architect (lib-location precedent):** If you choose Option (ii), the `tests/jimconf.sh:16-17` and `tests/jimfile.sh:17-18` source lines need updating in the same PR set. Both currently use `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/testlib.sh"` (sibling-relative). The new path is `../skills/meta-test/scripts/testlib.sh` (one level up, then descend).

→ **For PM (advisory, not blocking):** No spec ACs are invalidated by this research. The architect Open Questions in the spec are well-scoped and answerable from research (lib location, exit codes, run-action implementation, scaffold template location). All four can be resolved in `plan.md` without returning to spec.
