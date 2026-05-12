---
name: build
description: >
  Instructs the @coder to implement a spec from an approved plan using TDD.
  Use when the user invokes /jim:build or asks to implement, execute, or build
  from a spec or plan. Do not use for spec creation (/jim:spec), research
  (/jim:research), or planning (/jim:plan).
agent: coder
argument-hint: "[spec-directory-path]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)
---

# /jim:build

Execute an approved plan task-by-task using Red-Green-Refactor and Tidy First commit discipline. One task at a time, tests before code, no extras beyond the plan.

See `references/tdd-guide.md` for detailed methodology (TDD cycle, implementation gears, Tidy First, type-specific TDD, commit discipline, troubleshooting).

## Argument Routing

Use `$ARGUMENTS` to determine the spec directory:

| Input | Behavior |
| :--- | :--- |
| Empty | Ask: "Which spec should I build? Provide the path to the spec directory." |
| Directory path | Use as the spec directory — look for `plan.md`, `spec.md`, and `research.md` inside it |
| Path ending in `spec.md` or `plan.md` | Use the containing directory |

## Process

### 1. Gate the plan

Read `plan.md` from the spec directory. Check frontmatter `status:`.

- `status: draft` — Stop. Tell the user: "This plan is still in draft. Approve it first, then re-run /jim:build."
- `status: approved` or `status: complete` with unchecked tasks — Continue.

If `plan.md` is missing, stop and tell the user: "No plan.md found in [path]. Run /jim:plan first."

### 2. Load context

Read `spec.md` and `research.md` from the same directory. These provide the intent and constraints behind each task — the plan tells you *what*, the spec and research tell you *why*. Note the spec type (`feature`, `bug`, or `refactor`) — it governs Red phase behavior.

If the plan is ambiguous (a task's intent is unclear or its Verify command is malformed), STOP. Report the ambiguous task and what's unclear. Wait for the human to update the plan before continuing.

### 3. Execute the TDD loop

For each unchecked `[ ]` task in `plan.md`, in order:

**Red phase**
- Write one failing test for the specific behavior this task requires.
- Run the test via Bash. Show the output.
- Do NOT proceed to Green until test failure is confirmed via Bash output.
- If the test passes immediately: STOP. Report which task, that the test passed unexpectedly on Red, and suggest: (a) the behavior may already exist, (b) the test may be wrong. Wait for human guidance.

**Green phase**
- Write the minimum code to make the failing test pass. Fake it if needed.
- Run all tests via Bash. Show the output.
- If tests do not pass: retry with a smaller or different implementation.
- After 3 consecutive failed Green attempts on the same task: STOP. Report which task, each attempt made, what failed, and suggest: (a) update the plan, (b) run /jim:debug, or (c) adjust the approach. Wait for human guidance.

**Tidy phase**
- Refactor production and test code. One structural move at a time.
- Run all tests via Bash after each move before making the next.
- If any tidy move breaks tests: revert that move immediately. Do not fix broken tests during tidy — that is a behavioral change and belongs in a new task.

**Commit**
- Follow Tidy First: one commit per logical unit, structural OR behavioral, never mixed.
- Use conventional prefixes: `test:` (Red), `feat:` / `fix:` (Green), `refactor:` (Tidy).
- See `references/tdd-guide.md` — Commit Discipline section.
- Run the pre-commit gate before the commit lands:

  SET pre_commit = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_commit`
  SET require_pre_commit = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get require_pre_commit`

  IF pre_commit EXISTS THEN
    1. Run the script via Bash and show the full output.
    2. STOP and wait for human guidance if the exit code is non-zero.
  ELSE IF require_pre_commit == "true" THEN
    STOP with: "Required pre-commit script not found at pre_commit."
  ENDIF

**Verify**
- Run the task's `**Verify:**` command from the plan via Bash. Show the output.
- If Verify fails: STOP. Report which task, the Verify command, and its output. Wait for human guidance.

**Mark**
- Update the task to `[x]` in `plan.md`. This is the only modification you make to plan.md or spec.md.

Then read the next unchecked task and repeat.

### 4. Type-specific behavior

**Feature:** Standard Red-Green-Refactor. Red writes a new test for new behavior.

**Bug:** Red writes a reproduction test — a test that MUST fail, confirming the defect exists. Do NOT proceed to Green until the reproduction test fails via Bash output. The reproduction test becomes the regression guard after the fix.

**Refactor:** No Red phase. Existing tests must pass before AND after each structural change. One move at a time; re-run all tests between moves. If any move breaks tests, revert immediately.

### 5. Completion gate

After all tasks are marked `[x]`:

1. Run the pre-completion gate:

   SET pre_completion = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get pre_completion`
   SET require_pre_completion = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get require_pre_completion`

   IF pre_completion EXISTS THEN
     1. Run the script via Bash and show the full output.
     2. STOP and wait for human guidance if the exit code is non-zero.
   ELSE IF require_pre_completion == "true" THEN
     STOP with: "Required pre-completion script not found at pre_completion."
   ENDIF
2. Report results to the user and ask: "Should I mark the plan status as `complete`?"
3. STOP. Wait for the human to confirm. Do not proceed to the next SDLC phase, do not auto-invoke review. Update the plan frontmatter to `status: complete` only after explicit confirmation.

## Scope Discipline

- Do NOT add functionality, error handling, or optimizations beyond what the plan tasks specify.
- Do NOT modify `spec.md` or `plan.md` content — the only allowed change is marking tasks `[x]`.
- Do NOT proceed to the next SDLC phase (no auto-review, no auto-ship).
- If stuck and none of the above STOP conditions apply: STOP anyway. Report the task, what was attempted, and what is blocking. The human decides.

## Validation Checklist

Before beginning execution, confirm:

- [ ] `plan.md` exists and `status:` is not `draft`
- [ ] `spec.md` and `research.md` were read for context
- [ ] Spec type is noted (feature / bug / refactor)
- [ ] No ambiguous tasks in the unchecked portion of the plan
