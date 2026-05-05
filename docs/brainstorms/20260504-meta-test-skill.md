# Brainstorm: A `/jim:meta-test` skill?

*2026-05-04*

## Seed (user)

We're about to implement spec 009 (the test runner modularization from
`20260504-tests-runner-modularization.md`) — `tests/run.sh` splits into
`tests/testlib.sh` + per-script files (`tests/jimconf.sh`, `tests/jimfile.sh`),
with `case_*` discovery and standalone-runnable per-file execution.

That raises an adjacent question: should jim have a **meta skill for
authoring tests** of jim's own bash scripts (siblings to `/jim:meta-skill` and
`/jim:meta-agent`)?

User wants three things made explicit before deciding:
1. Is it actually **needed**?
2. What is its **boundary** — what does it do, what does it not do?
3. How would **`@jim:coder`** use it (and would `@jim:researcher` /
   `@jim:architect` / `@jim:pm` ever use it)?

Plus: where do the **conventions** for "how jim tests its bash scripts" live
— `ARCHITECTURE.md`? `CLAUDE.md`? Inside `testlib.sh`? Inside the skill?

## Framing — what kind of jim-asset is being tested?

Important distinction up-front: `/jim:meta-test` (if it exists) is **only**
about testing **jim's own deterministic bash scripts** (`jimconf.sh`,
`jimfile.sh`, future siblings). It is NOT about:

- Testing user application code (`@jim:coder` already does TDD on app code via
  `/jim:build` — that test code is whatever the project's test framework is).
- Testing LLM-prompt-shaped artifacts (skills, agents) — those are validated
  by checklist, not bash assertions.

So the universe of things `/jim:meta-test` would touch is small and bounded:
the contents of `tests/` for `tests/jim*.sh` files.

## Symmetry argument — does the "meta-X" pattern hold?

The two existing meta skills:

| Skill              | Scaffolds          | Why it's a skill (not just a template) |
|:------------------ |:------------------ |:-------------------------------------- |
| `/jim:meta-skill`  | `skills/X/SKILL.md`| Frontmatter trigger-description is high-judgment; agent binding is jim-specific; progressive-disclosure rules apply |
| `/jim:meta-agent`  | `agents/X.md`      | Tool-permission shape, model selection, subagent restrictions are jim-specific reasoning |

The reasoning that makes those skills earn their keep is: **non-trivial
authorial judgment that the generic coder doesn't carry**. Frontmatter design,
description triggering, agent boundaries — these are platform-shaped and
easy to get subtly wrong.

The honest test for `/jim:meta-test`: **what authorial judgment does it
codify that the coder doesn't already have?**

Candidates for jim-specific knowledge a meta-test skill might encode:

- The `case_*` (or `case_jim<feature>_*`) naming convention as the
  registration mechanism — discovery, not `TESTS=()`.
- Standalone-runnable tail (`[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"`).
- The `testlib.sh` source pattern — `source "$(dirname "$0")/testlib.sh"`.
- Per-test mktemp sandbox; no shared state; no third-party deps.
- Heredoc fixtures inline; no external fixture files.
- `run` / `run_jimfile`-style invokers live IN the per-script test file, not
  the lib (per the brainstorm's resolved shape).
- Per-script header docblock with the maintenance-notes discipline (mirrors
  the `jimconf.sh` / `jimfile.sh` script header convention).

That's a real list. The question is: does that list need a *skill*, or is it
captured well enough by reading `testlib.sh` + an existing test file as a
template?

## Three honest options

### Option 1 — No skill. Conventions live in code + docs.

- `tests/testlib.sh` header docblock = the canonical convention reference
  (just like `jimconf.sh` itself is the reference for the resolver).
- `ARCHITECTURE.md → Development & Testing` already names the runner; expand
  it slightly post-009 to point at the convention file.
- Coder's recipe for "add tests for new bash script `jimX.sh`": copy the
  existing `tests/jimconf.sh` as a template, replace the cases. Two-step.

**Why this might be enough:** the test file IS the template. Bash conventions
in jim are "look at the working file next to yours" — same way new skills
look at existing skills. There's already 1:1 file mapping
(script-under-test ↔ test file), so "find the example" is trivially
discoverable.

### Option 2 — Thin scaffolding skill (`/jim:meta-test`).

Scope: takes the name of a script-under-test (e.g., `jimsomething`) and
scaffolds `tests/jimsomething.sh` from a template (header docblock, source
of testlib.sh, an invoker stub, one starter `case_jimsomething_smoke`
function, the standalone-runnable tail). That's it.

**Does NOT:**
- Write actual test cases (coder writes those via TDD).
- Run tests (`bash tests/run.sh` does that — no skill needed).
- Validate convention compliance (testlib.sh enforces by being the only API).
- Touch app code (out of scope; that's `/jim:build`).

**Symmetric with:** `/jim:meta-skill` scaffolds SKILL.md, `/jim:meta-agent`
scaffolds an agent file, `/jim:meta-test` scaffolds a test file. The shape
matches.

**Honest weakness:** the scaffolding itself is ~30 lines of bash header +
~10 lines of body. A user (or the coder) typing `cp tests/jimconf.sh
tests/jimsomething.sh && $EDITOR tests/jimsomething.sh` does the same thing
in 2 seconds. The skill would mostly carry the "reference doc" weight, not
the scaffolding weight.

### Option 3 — Reference-only skill (no scaffolding, just docs).

A `/jim:meta-test` skill that's purely a SKILL.md describing the conventions
— no Bash, no scaffolding. It's invoked by `@jim:coder` (or `@jim:researcher`
/ `@jim:architect`) when they need to author or audit a jim test file.

**This is essentially what `references/` directories are for inside other
skills.** Could live as `skills/build/references/jim-bash-tests.md` and
be loaded only when coder is doing TDD on a jim bash script.

## Where do conventions actually belong?

Three possible homes, ranked:

1. **`tests/testlib.sh` header docblock** (canonical, code-adjacent). This
   is where the brainstorm 009 already proposes putting framework-level
   gotchas. Strongest signal because it can't drift from the code.
2. **`ARCHITECTURE.md → Development & Testing`** (high-level pointer).
   Already exists in light form; should update post-009 to name the new
   shape (`testlib.sh` + per-script files + `case_*` discovery).
3. **A skill or `references/` doc** (deeper detail / authoring guidance).
   Only if the conventions are too long for a header docblock — currently
   they aren't.

**Not `CLAUDE.md`.** That file is project rules for Claude Code's behavior
(WebFetch policy, etc.), not testing conventions. Putting test conventions
there would be category-confused.

## How would each agent actually use this?

| Agent              | Need                                                    | Best surface                  |
|:------------------ |:------------------------------------------------------- |:----------------------------- |
| `@jim:coder`       | Author new test cases; understand the case-discovery + standalone-runnable idiom while doing TDD on a new jim bash script | `testlib.sh` header + existing test file as template; possibly a `references/jim-bash-tests.md` loaded by `/jim:build` when the spec touches `skills/*/scripts/` |
| `@jim:researcher`  | Audit existing tests for coverage gaps / patterns       | Reads `tests/*.sh` directly. No skill needed — the convention IS visible in the code. |
| `@jim:architect`   | Reference test conventions when planning a new bash script + its tests | `ARCHITECTURE.md` pointer to `testlib.sh`; reads test files for examples. |
| `@jim:pm`          | Probably never. Test conventions are implementation-level. | n/a |

The strongest user is the coder, and the coder's need is mostly satisfied
by "the existing test files are the template."

## User direction (2026-05-04)

After reviewing the strawperson, user's reaction:

1. **Build it — Option 2 wins on symmetry.** "/jim:meta-skill scaffolds SKILL.md,
   /jim:meta-agent scaffolds an agent file, /jim:meta-test scaffolds a test
   file. The shape matches." The family-naming and the predictability of the
   `meta-*` surface for `@jim:meta` consumers is worth the small skill.
2. **Sequencing in the spec queue.** User wants `/jim:meta-test` to come
   *before* the testlib modularization in the spec sequence — meta-test as
   spec 009, testlib refactor pushed to spec 010. (Note: 007-conf and
   008-file are already merged; renumbering them is not on the table —
   "moving up" applies only to the *upcoming* unspec'd work.) **Confirm
   this read with the user before routing to `/jim:spec`.**
3. **Conventions home — still `tests/testlib.sh` header docblock**, but now
   the meta-test skill becomes the *authoring* surface that references
   those conventions (skill body + the docblock stay in sync).

### Why sequencing matters

If meta-test ships *before* the testlib refactor, then the refactor itself
can be implemented via `/jim:meta-test` (dogfooding from day one). If it
ships *after*, the refactor is the last thing built without the skill —
which is fine, just less elegant.

But there's a tension: meta-test needs the *target shape* (`testlib.sh` +
`case_*` discovery + standalone-runnable tail) to know what to scaffold.
That shape is what spec 009-as-currently-drafted (the testlib refactor)
would produce. Two ways to resolve:

- **Order A: meta-test first (009), testlib refactor second (010).** The
  meta-test scaffolding template *is* the canonical shape — writing the
  template forces the design choice. The refactor then implements the
  shape into `tests/testlib.sh` + retrofits `tests/jimconf.sh` and
  `tests/jimfile.sh`. Risk: meta-test scaffolds against a `testlib.sh`
  that doesn't exist yet — its template is aspirational until 010 lands.
- **Order B: testlib refactor first (009), meta-test second (010).** The
  refactor establishes `testlib.sh` and the file shape; meta-test then
  scaffolds new files against a real, working library. Lower risk but the
  refactor doesn't get to dogfood the skill.

User's stated preference (meta-test first) = Order A. Workable if spec 009
(meta-test) explicitly defines the target shape that spec 010 (testlib)
must implement. Spec 009 essentially encodes the brainstorm 009 outcomes
into a template; spec 010 then materializes that template into real lib
+ test files.

## Q&A — answering user's reactions

### "What is the docblock update?"

The "docblock" = a header comment block at the top of `tests/testlib.sh`
(the new shared lib file). It mirrors how `skills/conf/scripts/jimconf.sh`
and `skills/file/scripts/jimfile.sh` open with a substantial `#`-prefixed
header that documents:

- CLI surface (commands, flags)
- Conventions and gotchas (e.g., "never `source` user TOML")
- Maintenance discipline ("update this header when you change the CLI")

For `tests/testlib.sh` the docblock would document the *test framework*
conventions:

- The `case_*` (or `case_jim<feature>_*`) naming convention as the
  registration mechanism (no `TESTS=()`).
- The standalone-runnable tail idiom
  (`[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"`).
- Source pattern: `source "$(dirname "${BASH_SOURCE[0]}")/testlib.sh"`.
- Per-test mktemp sandbox; no shared state between cases.
- Heredoc fixtures inline; no external fixture files.
- Zero third-party deps (inherits from spec 007 §4).
- Recipe: "to add tests for a new bash script, copy `tests/jimconf.sh`,
  rename `case_*` functions, add `run_<scriptname>` invoker." (3 bullets.)

This is the canonical reference. It can't drift from the code because it
sits at the top of the code. The `/jim:meta-test` skill body then *cites*
this docblock rather than duplicating it, the way `/jim:conf` cites
`jimconf.sh`'s header rather than re-explaining the resolver internals.

### "Any future coder use case where loadable conventions (vs. inline in
testlib.sh) would actually change behavior?" — I DONT KNOW WHAT THIS MEANS

Fair — that question was awkwardly worded and is now **moot** since you're
choosing to build the skill. The question was: "if we DON'T build the
skill, would coder ever need conventions in some loadable form (e.g.,
`skills/build/references/jim-bash-tests.md`) that the inline docblock
in `testlib.sh` couldn't provide?" My answer was leaning "no" — but
since we're building `/jim:meta-test`, the skill IS the loadable surface,
so the question doesn't apply. Skip it.

## Revised strawperson recommendation

**Build `/jim:meta-test`.** Reasoning (post-user-direction):

1. **Family symmetry has real value.** `meta-skill` / `meta-agent` /
   `meta-test` is a predictable surface that `@jim:meta` consumers (and
   the user) can reason about as a unit. "If you're building a jim
   plugin component, there's a `meta-*` skill for it." Cleaner mental
   model than "two meta skills + 'go look at an existing test file.'"
2. **The skill encodes the convention authoritatively.** Even with the
   `testlib.sh` docblock as the canonical reference, the *act* of
   scaffolding is itself a convention-enforcing event — every new
   `tests/jim<x>.sh` born via `/jim:meta-test` starts with the right
   shape, so drift can't accumulate file-by-file.
3. **Discoverability for `@jim:coder`.** When `/jim:build` is implementing
   a new jim bash script, the coder's recipe becomes "use `/jim:meta-test`
   to scaffold the test file, then TDD the cases inside it." Cleaner than
   "find the nearest sibling and copy it."

### Boundary (firm)

**`/jim:meta-test` DOES:**
- Scaffold `tests/jim<x>.sh` from a template, given a script-under-test
  name (e.g., `/jim:meta-test jimsomething`).
- The scaffold includes: header docblock (citing the `testlib.sh`
  conventions), `source` of `testlib.sh`, a `run_<x>()` invoker stub
  pointing at `skills/<feature>/scripts/jim<x>.sh`, one starter
  `case_<x>_smoke` function, the standalone-runnable tail.
- Optionally: an "update" mode for adding new `case_*` functions to an
  existing test file (lower priority — coder can do this directly via
  Edit once the file exists).

**`/jim:meta-test` DOES NOT:**
- Write actual test cases (coder does this via TDD inside `/jim:build`).
- Run tests (`bash tests/run.sh` or `bash tests/jim<x>.sh` does this —
  no skill wrapper needed).
- Validate convention compliance (testlib.sh enforces this by being the
  only API; cases that misuse it just fail).
- Touch app code or non-jim test files.
- Create new bash scripts to test (that's `/jim:build` implementing the
  spec's source-of-truth artifact).

### How each agent uses it

| Agent             | Usage                                                              |
|:----------------- |:------------------------------------------------------------------ |
| `@jim:meta`       | **Primary owner.** Same pattern as `meta-skill` / `meta-agent` — meta delegates to coder, but the scaffolding skill itself runs in meta's domain. |
| `@jim:coder`      | Invoked from `/jim:build` when the spec creates a new jim bash script. Coder calls `/jim:meta-test <name>` once to get the test file shell, then TDD's cases inside it. |
| `@jim:architect`  | Reads the skill's `references/` (or the testlib docblock) when planning a new bash script + its tests — to know the test surface exists and how it's shaped. |
| `@jim:researcher` | Probably never — researcher reads `tests/*.sh` directly to understand coverage; doesn't need to scaffold. |
| `@jim:pm`         | Never — implementation-level. |

### Sequencing decision (revised)

User wants meta-test before testlib refactor. Confirm with user, then:

- **Spec 009 = `/jim:meta-test`** (this brainstorm → `/jim:spec`).
  Defines the skill, its template, the `testlib.sh` docblock content
  (as a `references/` doc that the testlib refactor will materialize).
- **Spec 010 = testlib refactor** (the existing `20260504-tests-runner-modularization.md`
  brainstorm → `/jim:spec`). Materializes `tests/testlib.sh`, retrofits
  `tests/jimconf.sh` and `tests/jimfile.sh` to the new shape, and the
  meta-test skill's template becomes the canonical reference for both.

Spec 009's plan must include the full `testlib.sh` header content as a
reference asset (e.g., `skills/meta-test/references/testlib-conventions.md`),
because spec 010 needs to write that exact content into the lib file.

## Things to flag in the spec

- **Naming of the script-under-test arg.** `/jim:meta-test jimsomething`
  vs. `/jim:meta-test something` — the `jim` prefix is the pattern for
  bash scripts under jim, but the arg shape needs a decision.
- **Where the template lives.** Likely `skills/meta-test/assets/test-file.sh.tmpl`
  (mirrors `meta-skill`'s `assets/` pattern).
- **Conflict handling.** What if `tests/jim<x>.sh` already exists? Probably
  refuse and ask user to delete or use update-mode.
- **Update-mode scope.** Defer or include? If included, it's roughly:
  given an existing `tests/jim<x>.sh` and a case name, append a
  `case_<x>_<name>()` stub. Low complexity but adds surface area.
- **Symmetry with `meta-skill` / `meta-agent`'s plan-gating discipline.**
  Both existing meta skills require an approved spec + plan before
  scaffolding. Does meta-test require the same, or is it a one-shot
  scaffolder (no spec gate)? Argument either way; recommend the same
  gating for consistency.

## Things that would still change the recommendation

- If we end up with only one or two jim bash scripts ever (i.e., the
  surface stops growing). Then the skill is overhead. Current trajectory
  (jimconf, jimfile, plausible future jimspec / jimplan / etc.) suggests
  we'll keep adding, so this is unlikely.
- If `/jim:meta-test` ends up duplicating large chunks of the `testlib.sh`
  docblock content. Should be avoided by referencing the docblock from the
  skill, not restating it.

## Naming candidates (if we ever do build it)

- `/jim:meta-test` — symmetric with meta-skill / meta-agent. Clearest.
- `/jim:meta-tests` (plural) — matches `tests/` directory. Slightly off-rhythm.
- `/jim:test-scaffold` — narrower, more honest about what it does, but
  breaks the meta-* family naming.
- `/jim:meta-script-test` — explicit but verbose.

If we build it, **`/jim:meta-test`** wins on symmetry.

## Resolved decisions (2026-05-04, second pass)

User confirmed all five questions. Captured here as the spec-routing brief.

### 1. Sequencing — `/jim:meta-test` = spec **007**

- The testlib refactor (the other 2026-05-04 brainstorm,
  `20260504-tests-runner-modularization.md`) was **already implemented
  without a spec** — `tests/testlib.sh`, `tests/jimconf.sh`, and
  `tests/jimfile.sh` already exist on disk and `ARCHITECTURE.md` reflects
  the new shape. So there is no testlib spec to sequence against.
- `/jim:meta-test` slots in as **spec 007**. The currently-merged
  `007-jimconf` and `008-jimfile` get **renumbered**:
  - `docs/specs/jim/007-jimconf/` → `docs/specs/jim/008-jimconf/`
  - `docs/specs/jim/008-jimfile/` → `docs/specs/jim/009-jimfile/`
- **Renumbering is out-of-scope for spec 007.** User will renumber the
  existing `007-jimconf` and `008-jimfile` directories (and any inbound
  references) **manually**, outside the meta-test spec/plan/build flow.
  Spec 007 should assume the renumber has happened by the time it lands
  — i.e., it can freely take the `007-meta-test` slot without including
  the rename work in its plan.

### 2. Skill argument shape — `/jim:meta-test {name}`

- The arg is a free-form name. **No enforced `jim` prefix** — `jimconf`,
  `jimfile` are conventional but `something-else` is allowed.
- Implication: the scaffolder writes `tests/{name}.sh` literally
  (whatever the user passes). No name-mangling, no prefix-injection.
  The convention "jim bash scripts get `jim*` filenames" stays a
  *convention enforced by the human*, not by the skill.

### 3. Update mode — **in-scope**

- `/jim:meta-test {name}` (no further args) — scaffold a new file
  (refuse if `tests/{name}.sh` already exists; surface the conflict).
- `/jim:meta-test {name} {case_name}` (or similar) — append a new
  `case_{name}_{case_name}()` stub to the existing file. Spec to
  decide exact arg shape; the *capability* is in-scope.

### 4. Plan-gating — **required**

- Same discipline as `/jim:meta-skill` and `/jim:meta-agent`: an approved
  `spec.md` and `plan.md` must exist before `@jim:coder` runs the skill.
- Rationale (user): "jim:coder relies on the plan and spec." This keeps
  meta-test inside the SDLC discipline rather than being a one-shot
  scaffolder that bypasses the spec→plan→build flow.

### 5. Doc updates — **part of spec 007's scope**

The meta-test spec must consider updates to:

- **`ARCHITECTURE.md`** — add `meta-test/` to the skills tree, add it
  to the "Meta Skills" subgraph in the mermaid diagram, mention it in
  Plugin Conventions if any new convention is introduced (e.g.,
  `tests/{name}.sh` provenance via `/jim:meta-test`).
- **`README.md`** — surface `/jim:meta-test` in whatever command-overview
  table or skills list lives there; align with how `/jim:meta-skill` and
  `/jim:meta-agent` are presented.
- **`WORKFLOW.md`** — meta-test fits into the "building jim itself"
  section alongside `meta-skill` / `meta-agent`. Add it to the meta
  workflow narrative and to any agent-skill composition tables.
- ~~**Renumbering follow-on**~~ — handled manually by the user outside
  this spec; not part of meta-test scope.

## Routing brief for `/jim:spec`

When ready to spec:

- **ID:** 007
- **Group:** jim
- **Slug suggestion:** `meta-test` (mirrors `meta-skill`, `meta-agent`)
- **Origin:** this brainstorm
  (`docs/brainstorms/20260504-meta-test-skill.md`)
- **Type:** feature
- **Owning agent:** `@jim:meta` (skill primary), `@jim:coder` (consumer
  via `/jim:build` when implementing new jim bash scripts)
- **Scope reminders:** scaffold-only (no test-running, no case-writing,
  no app code); plan-gated; arg is free-form name; update-mode in-scope;
  doc updates required across ARCHITECTURE.md / README.md / WORKFLOW.md.
  Renumbering of prior `007-jimconf` / `008-jimfile` is **out-of-scope**
  — handled manually by the user.

Ready to route to `/jim:spec` whenever you are.
