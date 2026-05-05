---
name: debug
description: >
  Structured failure diagnosis. Produces a debug report — does not fix code.
  Use when the user invokes /jim:debug, when a build task fails and needs
  diagnosis, or when an error needs a structured root cause analysis before
  deciding on a fix. Do not use when the fix is already known (/jim:build
  handles it) or when the failure is a spec/plan gap (/jim:spec or /jim:plan).
agent: coder
argument-hint: "[failure-description | error-output | file-path]"
allowed-tools: Bash(bash *)
---

# /jim:debug

Diagnose a failure and produce a structured debug report. Diagnosis only — does NOT fix code. Fixes flow through the spec/plan cycle.

## Argument Routing

Use `$ARGUMENTS` to determine what to diagnose:

| Input | Behavior |
| :--- | :--- |
| Empty | Ask: "What failed? Describe the error, paste the error output, or give me the path to the failing code." |
| Error output or description | Use as the primary failure signal |
| File path | Read the file, then ask: "What failure is associated with this file?" |

## Process

### 1. Gather failure context

Read the error, description, or file provided. If the failure references a spec or plan, find and read those files for context — they clarify the intended behavior.

Look for related files:
- Check existing debug reports for prior diagnoses of the same topic: !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh glob debug`
- Glob and Grep the codebase for the failing component, test file, or error message.

### 2. Diagnose the failure

Analyze in this order:

1. **Reproduce:** Attempt to identify the exact reproduction steps. If the error is a test failure, read the test and the code it exercises. If it is a runtime error, trace the call path.
2. **Locate:** Identify the specific file and line where the failure originates. Distinguish between the symptom (where the error surfaces) and the root cause (where the defect lives).
3. **Hypothesize:** Form one primary root cause hypothesis, supported by evidence from the code or error output. Note alternative hypotheses if they are credible.
4. **Check spec/plan linkage:** If the failure is in code that was implemented from a plan, identify which task in the plan produced the failing code. If the failure suggests the spec requirement itself is wrong or incomplete, note this explicitly — it affects the recommendation.

### 3. Generate the debug report

Determine the report filename: !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh path debug "$ARGUMENTS"`

Read `assets/debug-template.md` and fill every section:

- **Error Analysis** — the error, observed behavior, expected behavior
- **Reproduction Steps** — exact steps; include a shell command if one reproduces the failure
- **Root Cause Hypothesis** — primary hypothesis with evidence; alternative hypotheses if credible; affected code locations
- **Affected Specs/Plans** — any spec or plan linked to the failure (enables `origin:` field in future bug specs)
- **Recommended Next Step** — choose one: direct fix (Option A), plan update (Option B), or spec update via `/jim:spec` (Option C). If the diagnosis reveals a fundamental flaw in the original requirements, Option C is the right choice — advise using `/jim:spec` to open a bug spec capturing the correct behavior.

Write the report to the path resolved above. Create the debug directory if it does not exist.

### 4. Present and stop

Show the completed report. Tell the user:
- The report path (resolved in step 3 via `/jim:file path debug`).
- It can be referenced via the `origin:` field in a future bug spec.
- The recommended next step and why.

STOP. Do not fix the code. Do not open a spec or update a plan. The human decides the next action.

## Scope Discipline

- Does NOT fix code — diagnosis only.
- Does NOT modify spec.md or plan.md files.
- Does NOT open new specs or plans automatically.
- Does NOT run `./pre-commit.sh` or execute tests beyond what is needed to confirm reproduction.
