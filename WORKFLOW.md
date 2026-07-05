# Development Workflow: The "Jim" Plugin

This document defines the agentic development workflow for projects using Jim. "Jim" is a **Claude Code plugin** that provides a command-driven SDLC through namespaced skills and specialized agents. You talk to Jim like a person: `/jim:spec`, `/jim:plan`, `/jim:build`.

---

## Agentic SDLC Overview

```
[ BRAINSTORM ] <──────────────────────────────────┐
      │                                           │
      ▼                                           │
  [ SPEC ] <───┐                                  │
      │        │ (Feedback Loop)                  │ (Strategic Loop)
      ▼        │                                  │
  [ PLAN ] <───┘                                  │
      │                                           │
      ▼                                           │
  [ BUILD ] ───► [ REVIEW* ] ───► [ SHIP* ] ──────┘

  * = not yet implemented
```

### The Feedback Loop

This is not waterfall. Any downstream phase can send you back upstream:

- During **plan** you discover the spec is wrong → update the spec.
- During **build** you discover the plan missed something → update the plan.
- During **build** a failing test reveals a spec gap → update the spec, then the plan.

**No ghost tasks:** if a code change is needed that isn't in the plan, the plan must be updated before the code is touched. The artifacts are living documents, not approval gates you pass through once.

### The Research Engine

Research is not a gated phase; it is an agile service that grounds the SDLC in reality.

1. **Pre-Spec (Exploratory):** PM invokes `/jim:research` to explore libraries or codebase
   feasibility before committing to a spec.
2. **In-Plan (Autonomous):** If `/jim:plan` is run and no `research.md` exists (or it's
   insufficient), the Architect automatically spawns the Researcher.
3. **The Feedback Loop:**
   - **Research → Spec:** If research reveals a requirement is technically impossible, it
     signals the PM to update the spec.
   - **Research → Plan:** If research is updated after a plan exists, it signals the
     Architect to re-validate the implementation anchors.

---

## Command Reference

| Command | What It Does | Agent | Output |
|---------|-------------|-------|--------|
| `/jim:spec` | Define the work — feature, bug, or refactor | `@jim:pm` | `spec.md` |
| `/jim:plan` | Research codebase + break into atomic tasks | `@jim:architect` | `plan.md` |
| `/jim:research` | Investigate codebase, external docs, and technical landscape | `@jim:researcher` | `research.md` |
| `/jim:build` | TDD red-green-refactor + commit per task | `@jim:coder` | Tests + code |
| `/jim:sec` | Design-time security analysis (hybrid freeform + STRIDE, conditional LINDDUN on PII) | `@jim:security` | `security.md` |
| `/jim:review` | Depth-aware post-build review — drift vs spec/plan/architecture (investigator fan-out), code + process metrics, security regressions, and living-intent sensing against the group blueprint | `@jim:reviewer` | `review.md` |
| `/jim:ship` | PR, deploy, update roadmap *(not yet implemented)* | TBD | Merged PR |
| `/jim:vision` | Create/update project vision and strategy | `@jim:pm` | `VISION.md` |
| `/jim:roadmap` | Create/update execution milestones and phase sequence | `@jim:pm` | `ROADMAP.md` |
| `/jim:arch` | Create/update technical architecture | `@jim:architect` | `ARCHITECTURE.md` |
| `/jim:blueprint` | Create/update a group's current-state blueprint spec (`<group>`), or — invoked bare — the project-tier context map | `@jim:architect` | `docs/specs/{group}/000-blueprint/spec.md` · `BLUEPRINT.md` |
| `/jim:verify` | Check a group's code against its `000-blueprint` invariants — zero-config mechanical floor, operator-configured registry, criticality-gated read-only judge; per-invariant outcomes, violations offered as issues. Scoped adapter modes `--from-review` / `--since` (spec 036) ground the fold-back loop; **contract mode `--contracts [<group>]` (spec 037)** checks the cross-group contract graph's edges against code on both sides — a territory cross-reference floor plus per-side judges, blast-radius-scoped by the graph and the existing appetite knobs (no new config), with two grains (whole-graph incl. dead-surface, or edges touching one group) and change-driven triggers at the review sensor and the blueprint boundary-change; `/jim:review` and `/jim:blueprint` are its first programmatic callers | `@jim:reviewer` | Report + ledger event (no persisted verdict) |
| `/jim:debug` | Diagnose failures, produce report for spec/plan cycle | `@jim:coder` | `debug/{YYYYMMDD}-{topic}.md` |
| `/jim:brainstorm` | Freeform ideation — exploratory notes | `@jim:pm` | `brainstorms/{YYYYMMDD}-{topic}.md` |
| `/jim:issue` | Capture a discovery (`add <subject>`) or review the collection (`list [filter]` / `stats` / `show <id>`; bare → help) | `@jim:pm` | `issues/{YYYYMMDD}-{slug}.md` + `INDEX.md` |
| `/jim:meta-skill` | Create/update a jim plugin skill from spec | `@jim:meta` | `jim/skills/{name}/SKILL.md` |
| `/jim:meta-agent` | Create/update a jim plugin agent from spec | `@jim:meta` | `jim/agents/{name}.md` |
| `/jim:meta-test` | Scaffold a bash test file, append a case, or run the suite | `@jim:meta` | `jim/tests/{name}.sh` |

---

## Artifacts

### Project Artifacts

| Artifact | Location | What It Is | Managed By |
|----------|----------|------------|------------|
| Vision | `VISION.md` (project root) | Big picture — problem statement, value prop, target audience, competitive landscape | `/jim:vision` |
| Architecture | `ARCHITECTURE.md` (project root) | Technical foundation — codemap, system diagram, tech stack, data structures, architectural invariants | `/jim:arch` |
| Blueprint | `docs/specs/{group}/000-blueprint/spec.md` | A group's current, present-tense spec — responsibility, provides/requires surface, structure, load-bearing invariants; amalgamated from the group's specs, ARCHITECTURE.md, and code | `/jim:blueprint <group>` |
| Context map | `BLUEPRINT.md` (project root, `blueprint_path`) | The project-tier context map — the declared partition into spec groups, each with a purpose, role (`domain`/`platform`/`layer`), boundary rationale, relations, and (mode-dependent) code territory; consumed by `/jim:spec`'s assignment advisor; sole authority for the partition | `/jim:blueprint` (bare) |
| Roadmap | `ROADMAP.md` (project root) | Execution sequence — milestones, phase breakdowns, links to numbered specs with status | `/jim:roadmap` |
| Spec | `docs/specs/{group}/{00X}-{name}/spec.md` | Work definition — requirements, acceptance criteria, spec type (feature/bug/refactor) | `/jim:spec` |
| Plan | `docs/specs/{group}/{00X}-{name}/plan.md` | Implementation path — codebase research, atomic tasks, dependencies | `/jim:plan` |
| Security Review | `docs/specs/{group}/{00X}-{name}/security.md` (spec-scoped) or `{security_adhoc_path}/{YYYYMMDD}-{slug}.md` (ad-hoc opt-in) | Design-time findings — severity, route, phase coverage; gates `/jim:plan` and `/jim:build` start when `require_security` / `auto_security` is set | `/jim:sec` |
| Review Report | `docs/specs/{group}/{00X}-{name}/review.md` | Post-build findings — drift vs spec/plan/architecture, code + process metrics, security regressions, alignment verdict; mineable frontmatter + narrative | `/jim:review` |
| Stage Ledger | `docs/specs/{group}/{00X}-{name}/ledger.md` | Append-only event log of SDLC stage boundaries (baseline/head SHAs, per-stage start/finish, interruptions, re-runs); `/jim:build` records the build range and SHAs, and `/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:sec`, and `/jim:review` each record their own start/finish — `/jim:review` also appends its validated alignment verdict and self-commits `review.md` + `ledger.md` (spec 028); `/jim:verify` records its per-invariant outcome counts on the group's `000-blueprint/ledger.md` and self-commits that ledger alone via `commit-verify` (spec 035, its only durable trace — no verdict artifact is persisted) — the reviewer's process-metric source | `/jim:build` (+ spec/research/plan/sec/review/verify) |
| Debug Report | `docs/debug/{YYYYMMDD}-{topic}.md` | Diagnosis — error analysis, root cause, references to affected specs | `/jim:debug` |
| Brainstorm | `docs/brainstorms/{YYYYMMDD}-{topic}.md` | Exploratory notes — ideas, risks, options, may feed into specs | `/jim:brainstorm` |
| Issue | `docs/issues/{YYYYMMDD}-{slug}.md` + `INDEX.md` (configurable via `issues_path`) | Discovery artifacts surfaced during the workflow — one markdown file per issue with a display ordinal (`num`), `open`/`closed` status, typed relations, and an auto-generated index | `/jim:issue` |

### Discovery capture (`/jim:issue`)

`/jim:issue` is a single command with subcommands:

- **`add <subject>`** — capture one discovery from the current conversation as a structured markdown file (single confirm-or-edit moment with a sensitive-content scrub reminder). New issues get a `num:` display ordinal automatically.
- **`list [filter]`** — terse, grouped, configurable enumeration; an optional `open`/`closed`/`critical`/`high`/`medium`/`low` filter scopes the view. Closed issues are hidden from the default and priority-filtered views unless `issue_list_closed = "true"`; `list closed` is the ad-hoc closed view. Other defaults are set via the `issue_list_group` / `issue_list_sort` / `issue_list_cols` / `issue_list_order` keys in `jimconf.toml`.
- **`stats`** — counts (open/closed, by priority, by label, by origin) plus blocking analysis.
- **`show <id>`** — open one issue by its ordinal number, slug, or a slug prefix.
- bare **`/jim:issue`** — print the subcommand help.

Issues are also surfaced automatically at the end of each SDLC phase as a candidate batch (per spec 018), gated by `issue_capture`. Close an issue by editing its `status:` field directly.

**One-time migration (`backfill.sh`).** Spec 019 added the `num:` ordinal. Existing collections created before 019 are numbered once by running `bash skills/issue/scripts/backfill.sh` against the issues directory — it assigns ordinals in `created:`-date order, is idempotent, and writes each file atomically. Run it once, up-front, before creating new issues. New issues never need it.

### Plugin Artifacts (Jim developing Jim)

| Artifact | Location | What It Is | Managed By |
|----------|----------|------------|------------|
| Plugin Vision | `jim/VISION.md` | Why Jim exists, what problem it solves | `/jim:vision` (from within jim/) |
| Plugin Architecture | `jim/ARCHITECTURE.md` | Plugin structure, agent-skill composition, naming conventions | `/jim:arch` (from within jim/) |
| Plugin Roadmap | `jim/ROADMAP.md` | Which skills/agents to build in what order | `/jim:roadmap` (from within jim/) |
| Plugin Workflow | `jim/docs/workflow.md` | This file — the SDLC process itself | Manual or `/jim:meta-skill` |
| Skill | `jim/skills/{name}/SKILL.md` | A jim plugin skill — instructions, templates, references | `/jim:meta-skill` |
| Agent | `jim/agents/{name}.md` | A jim plugin agent — persona, tools, skill composition | `/jim:meta-agent` |

---

## Philosophy

**Spec-Driven Development:** We separate thinking from doing. Requirements, research, and plans are defined and approved before implementation begins.

**Strategic Alignment:** Every spec traces back to the project's vision (why), architecture (how), and roadmap (when).

**Test-Driven Development:** Following Kent Beck's TDD — one task, one failing test, minimum code to pass, tidy, commit, next. Structural changes (refactors) are always separate from behavioral changes.

**Human-in-the-Loop:** Agents STOP and wait for approval after completing each phase gate or atomic task. No autonomous multi-phase execution.

**Differential Updates:** Running any `/jim:` command on an existing artifact refines it based on new context, never overwrites blindly.

---

## Plugin Architecture

"Jim" is a Claude Code plugin. All skills are namespaced as `/jim:{verb}`, all agents as `@jim:{role}`.

### Plugin Directory

```
jim/
├── .claude-plugin/
│   └── plugin.json              # { "name": "jim", "version": "1.0.0" }
│
├── VISION.md                    # Why Jim exists (Jim's own strategic docs)
├── ARCHITECTURE.md              # How Jim is structured
├── ROADMAP.md                   # What to build next for Jim
│
├── agents/
│   ├── pm.md                    # → @jim:pm
│   ├── architect.md             # → @jim:architect
│   ├── researcher.md            # → @jim:researcher
│   ├── coder.md                 # → @jim:coder
│   ├── security.md              # → @jim:security
│   ├── reviewer.md              # → @jim:reviewer
│   └── meta.md                  # → @jim:meta
│
├── skills/
│   │
│   │  # ── SDLC Lifecycle ──
│   ├── spec/
│   │   ├── SKILL.md             # → /jim:spec
│   │   ├── assets/
│   │   │   └── spec-template.md
│   │   └── references/
│   │       └── spec-types.md
│   │
│   ├── plan/
│   │   ├── SKILL.md             # → /jim:plan
│   │   └── assets/
│   │       └── plan-template.md
│   │
│   ├── research/
│   │   └── SKILL.md             # → /jim:research
│   │
│   ├── build/
│   │   ├── SKILL.md             # → /jim:build
│   │   └── references/
│   │       └── tdd-guide.md
│   │
│   ├── review/
│   │   └── SKILL.md             # → /jim:review
│   │
│   ├── ship/
│   │   └── SKILL.md             # → /jim:ship (not yet implemented)
│   │
│   │  # ── Strategic ──
│   ├── vision/
│   │   ├── SKILL.md             # → /jim:vision
│   │   └── assets/
│   │       └── vision-template.md
│   │
│   ├── roadmap/
│   │   ├── SKILL.md             # → /jim:roadmap
│   │   └── assets/
│   │       └── roadmap-template.md
│   │
│   ├── arch/
│   │   ├── SKILL.md             # → /jim:arch
│   │   └── assets/
│   │       └── architecture-template.md
│   │
│   │  # ── Utilities ──
│   ├── debug/
│   │   ├── SKILL.md             # → /jim:debug
│   │   └── assets/
│   │       └── debug-template.md
│   │
│   ├── sec/
│   │   ├── SKILL.md             # → /jim:sec
│   │   ├── assets/
│   │   │   └── security-template.md
│   │   └── references/
│   │       └── security-dod.md
│   │
│   ├── brainstorm/
│   │   └── SKILL.md             # → /jim:brainstorm
│   │
│   │  # ── Meta (Jim building Jim) ──
│   ├── meta-skill/
│   │   ├── SKILL.md             # → /jim:meta-skill
│   │   └── references/
│   │       └── skill-standards.md
│   │
│   ├── meta-agent/
│   │   ├── SKILL.md             # → /jim:meta-agent
│   │   └── references/
│   │       └── agent-standards.md
│   │
│   └── meta-test/
│       ├── SKILL.md             # → /jim:meta-test
│       ├── assets/
│       │   └── test-file.sh.tmpl
│       └── scripts/
│           ├── testlib.sh       # Shared test framework (asserts, fixtures, reporter)
│           ├── run.sh           # Aggregate runner (sources testlib + every tests/*.sh)
│           └── metatest.sh      # Dispatcher (scaffold | add | run subcommands)
│
├── docs/
│   └── workflow.md              # This file — the SDLC process itself
│
└── README.md
```

### Agents

| Agent | Role | Used By |
|-------|------|---------|
| `@jim:pm` | Product strategy, specs, vision, roadmap | `/jim:spec`, `/jim:vision`, `/jim:roadmap`, `/jim:brainstorm` |
| `@jim:architect` | Technical planning, architecture | `/jim:plan`, `/jim:arch` |
| `@jim:researcher` | Codebase investigation and technical landscape research | `/jim:research`, invoked by PM or architect |
| `@jim:coder` | TDD implementation, debugging | `/jim:build`, `/jim:debug` |
| `@jim:reviewer` | Post-build review — drift, metrics, security regressions | `/jim:review` |
| `@jim:meta` | Plugin development — builds skills, agents, and bash tests | `/jim:meta-skill`, `/jim:meta-agent`, `/jim:meta-test` |

### Agent ↔ Skill Composition

Agents declare which skills they compose in their frontmatter. Skills declare which agent runs them.

```yaml
# jim/agents/pm.md
---
name: pm
description: Product manager. Defines specs and maintains strategic alignment.
skills:
  - spec
  - vision
  - roadmap
  - brainstorm
---
```

```yaml
# jim/agents/architect.md
---
name: architect
description: Technical architect. Plans implementation and maintains
  the technical architecture. Delegates codebase investigation to
  @jim:researcher subagent.
skills:
  - plan
  - arch
---
```

```yaml
# jim/agents/researcher.md
---
name: researcher
description: Codebase investigator. Explores existing code patterns,
  integration points, and blast radius. Read-only. Reports findings
  back to the architect.
tools: Read, Grep, Glob
---
```

```yaml
# jim/agents/coder.md
---
name: coder
description: Developer. Builds via TDD and debugs failures.
skills:
  - build
  - debug
---
```

```yaml
# jim/agents/reviewer.md
---
name: reviewer
description: Post-build reviewer. Drift, metrics, security regressions.
skills:
  - review
---
```

```yaml
# jim/agents/meta.md
---
name: meta
description: Plugin developer. Creates and updates jim skills and agents
  from specs. Reads workflow.md for SDLC context and enforces plugin
  conventions (frontmatter, naming, progressive disclosure).
skills:
  - meta-skill
  - meta-agent
  - meta-test
tools: Read, Write, Edit, Glob, Grep
---
```

Skills specify their agent in frontmatter:

```yaml
# jim/skills/spec/SKILL.md
---
name: spec
description: Create, update, or validate feature/bug/refactor specs.
  Use when the user wants to scope work, write a spec, or define requirements.
agent: pm
---
```

```yaml
# jim/skills/arch/SKILL.md
---
name: arch
description: Create or update the project ARCHITECTURE.md following
  the architecture.md standard. Use when discussing tech stack, system
  design, codemap, or architectural decisions.
agent: architect
---
```

```yaml
# jim/skills/meta-skill/SKILL.md
---
name: meta-skill
description: Create or update a jim plugin skill. Reads workflow.md
  and spec to generate SKILL.md with proper frontmatter, directory
  structure (assets/, references/), and agent binding.
agent: meta
---
```

---

## The Lifecycle in Detail

### `/jim:spec`

**Purpose:** Turn a rough idea into a clear, actionable spec.

**Process:**
1. Describe your idea, bug report, or refactor motivation
2. PM determines spec type (`feature`, `bug`, `refactor`) and asks clarifying questions (1-2 at a time)
3. Checks alignment against VISION.md and ARCHITECTURE.md; when `BLUEPRINT.md` exists, the assignment advisor consumes the context map to recommend the target group (role-aware reasoning, genuine pushback, developer final authority — mint-new routes through the blueprint surface inline)
4. Generates spec using template from `spec/assets/spec-template.md`
5. You review and approve or request changes

**Output:** `docs/specs/{group}/{00X}-{name}/spec.md`

**Gate:** Human approves the spec. Status changes from `draft` to `approved`.

### `/jim:plan`

**Purpose:** Research the codebase and create an implementation plan.

**Process:**
1. Reads the approved spec
2. Delegates codebase investigation to `@jim:researcher` subagent — integration points, fault locations (bugs), blast radius (refactors)
3. Reviews research findings
4. Checks ARCHITECTURE.md for architectural constraints
5. Breaks work into atomic, checkable tasks
6. You review and approve

**Output:** `docs/specs/{group}/{00X}-{name}/plan.md`

**Gate:** Human approves the plan. Build cannot begin without it.

### `/jim:build`

**Purpose:** Implement the plan using TDD, one task at a time.

**Process:** For each task in `plan.md`:
1. **Red** — Write a failing test (bug: reproduction test; refactor: skip if covered)
2. **Green** — Write minimum code to make it pass
3. **Refactor** — Tidy structural changes (separate from behavioral)
4. Run all tests, confirm green
5. Commit with conventional message
6. Mark task complete, move to next

**Tidy First:** Structural changes (renames, extractions, moves) are never mixed with behavioral changes (new functionality) in the same commit.

**Gate:** All tests pass. The configured `pre_commit` script (default `./pre-commit.sh`, configurable via `jimconf.toml`) is green if present; absent means the gate is a no-op.

### `/jim:review`

**Purpose:** Verify what `/jim:build` actually shipped against its spec, plan, and architecture — catching drift before it compounds — and record how the build measured up.

`@jim:reviewer` fuses three inputs: the **stage ledger** (`ledger.md` — a trusted metrics channel via `jimledger.sh`: a fixed key set carrying trusted-origin, shape-validated values, never free-form ingested text; `/jim:build` records the build range and SHAs, while `/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:sec`, and `/jim:review` each record their own start/finish for per-stage durations and re-runs — `/jim:review` also appends its validated alignment verdict and commits `review.md` + `ledger.md`, spec 028), the **git diff** for the build range, and the **spec / plan / `ARCHITECTURE.md`** ground truth. It reports drift against each, code + process metrics, and any security regressions (optionally invoking `/jim:sec` ad-hoc), then writes `review.md` with a mineable frontmatter summary, a single alignment verdict (`aligned` / `minor-drift` / `major-drift`), and a narrative. Findings can be captured as issues. Ingested commit/diff/ledger content is treated as untrusted; the verdict is the reviewer's judgment, never a value read from that content.

The review is **depth-aware** (spec 027): it triages the build's diff and fans out read-only `investigator` subagents on the high-stakes changes to verify each acceptance criterion for *complete* satisfaction (including code the build did not touch), recording the evidence in `review.md`. Depth is configurable — `review_depth` (default `thorough`; `lean` for trivial changes; `--depth lean|thorough` overrides per run), `review_model` (the investigator model; default `inherit`), and `review_fanout_cap` (max investigators; default `10`).

The review is also a **living-intent sensor** (spec 036): for a group that has a `000-blueprint`, it invokes `/jim:verify --from-review` to check the group's code against its recorded invariants as part of every review — the mechanical floor and registry whole-group, LLM judges scoped to the build's change and gated by `verify_appetite`. Results land as their own `## Living intent` dimension in `review.md`, distinct from the alignment verdict and never setting it (the two signals stay clean). Sensed violations route by two channels: those intersecting the build's change feed the blueprint update's violation fork as engine-grounded divergences; pre-existing drift (and any unlocalized violation) is reported and offered as tracked issues, never folded into the update. A blueprint-less group skips the sensor silently, and a check that fails to run is contained and reported — never aborting the review.

`/jim:build` offers the review at its completion gate by default, or runs it automatically under the `require_review` / `auto_review` knobs. Two axes that don't conflate: the review's **findings** are advisory — a report, never a veto, and they never auto-reject the build. `require_review`, by contrast, makes the review a **required, blocking phase**: the build's completion gate is held until the review has run to completion, so the build cannot be marked complete without it. It is the uncompleted phase that blocks, not the findings.

### `/jim:blueprint`

**Purpose:** Keep the living blueprints current at both tiers — each group's `000-blueprint` (the build-grade map of one group) and the project-tier context map (`BLUEPRINT.md`, the declared partition itself).

**Group tier** (`/jim:blueprint <group>`, specs 029–032):
1. **Generate** — full scan of the group's specs, ARCHITECTURE.md, and code → `000-blueprint/spec.md` (responsibility, provides/requires faces, structure, invariants); stamps the `last_full_generate` watermark
2. **Update** — targeted section-diff from a change diff: `--from-review <spec-dir> <group>` (fed by the review's verdict ledger, consuming the review sensor's engine outcomes — no double-run) or `--since <ref> <group>` (ad-hoc git range, invoking the engine itself over the range to ground the fork)
3. **Guard** — the violation fork is grounded in `/jim:verify` engine outcomes on both adapters (spec 036), with an inline fallback sweep for invariants the engine did not cover and fail-closed precedence; violations still fork per-item to *fix the code* or *fold the intent*, the fix-vs-fold semantics unchanged from spec 031
4. **Cadence** — accumulated targeted updates since the last full generate are counted and reported; the opt-in `blueprint_regen_threshold` swaps a stale enough targeted update for a full regeneration (spec 032)

**Project tier** (`/jim:blueprint`, bare — spec 033):
1. **Create** — no map yet: a both-directions flow reads the strategic context *and* interviews for domain knowledge, proposes a partition of deliberate bounded contexts (vertical-first doctrine; `group_axis` escape hatch; roles `domain`/`platform`/`layer`; territory per `group_territory`), and writes `BLUEPRINT.md` only on explicit approval
2. **Update** — differential diff against the current map, graded by the shared Step-4a rule: additive changes may auto-write under `auto_blueprint`; partition downgrades always prompt per-item
3. **Consumption** — `/jim:spec`'s assignment advisor reads the map on every spec; a new group can only be minted through this surface

**Reconcile** (`/jim:blueprint --reconcile`, and fired by every blueprint write — spec 034):
1. **Graph** — joins each group's `requires` face against the other groups' `provides` faces into the derived `## Contract Graph` section of `BLUEPRINT.md`; re-derived after every write through the blueprint surface (fix-only guard runs skip — no face changed), runnable on demand via `--reconcile`, and a one-line no-op note when fewer than two groups have blueprints
2. **Findings** — declaration-level mismatches (faces reconcile, never "contracts verified") classified as leak / breaking / dead-surface / unresolved-require / undeclared-relation / stale-relation, each with its remedy; reported at detection time, offered as captured issues, and durably counted on the specs-root ledger (`op=reconcile`, all seven counters)
3. **Blast radius** — a Provides weakening/removal names every dependent consumer group from the pre-write graph ("graph as of *Last reconciled*") in the Step-4a grading and violation-fork prompts — informational, never a veto

**Gate:** Human approval on every write (the `auto_blueprint` knob relaxes group-tier folds and additive map changes only). Both tiers self-commit path-scoped via `jimledger.sh` (`commit-blueprint` / `commit-map`) and record `blueprint` stage events on their ledgers. The derived contract-graph rewrite is mechanical content — exempt from Step-4a grading, committed via `commit-map` only.

### `/jim:ship` *(not yet implemented)*

**Purpose:** Create PR, deploy, update roadmap status.

---

## Building Jim with Jim

Jim can develop itself through its own SDLC. Skills and agents for the plugin are specs like any other — the "feature" is a plugin component.

```
/jim:spec          → spec out what a skill should do (reads workflow.md)
/jim:plan          → plan the skill's structure and content (optional)
/jim:meta-skill    → build the skill from spec + plan
/jim:meta-agent    → build the agent from spec + plan
/jim:meta-test     → scaffold tests for a new jim bash script, append cases, or run the suite
```

For jim's deterministic bash scripts (`skills/*/scripts/*.sh`), `/jim:meta-test scaffold <name>` produces `tests/<name>.sh` from a template that already encodes every framework convention (case-naming, source pattern, mktemp sandbox, standalone-runnable tail). Add new cases via `/jim:meta-test add <name> <case_name>` and run via `/jim:meta-test run [name]`. Plan-gating mirrors `/jim:meta-skill` and `/jim:meta-agent` — scaffold requires an approved spec+plan for the script-under-test; add and run are ungated.

Jim's own specs live in `docs/specs/jim/` as a group. Jim's strategic docs (`VISION.md`, `ARCHITECTURE.md`, `ROADMAP.md`) live at the plugin root.

---

## Skipping Phases

Not every change needs the full lifecycle:

| Change Type | Start At | Skip |
|-------------|----------|------|
| New feature | `/jim:spec` | — |
| Bug | `/jim:spec` | — |
| Refactor | `/jim:spec` | — |
| Exploratory research | `/jim:research` | Spec, Plan |
| Strategic change | `/jim:vision` or `/jim:arch` | — |
| Hotfix (urgent) | `/jim:build` | Spec, Plan |
| Typo/docs | Direct commit | Everything |

---

## Rules of Engagement

1. **Human-in-the-Loop:** Agents STOP after each phase gate or atomic task. No autonomous multi-phase execution.

2. **Differential Updates:** Every `/jim:` command creates if the artifact doesn't exist, refines based on new context if it does. Never overwrites blindly.

3. **No Ghost Tasks:** If a code change isn't in the plan, update the plan first.

4. **Strategic Alignment:** Specs reference the vision and architecture. The PM checks this during `/jim:spec`.

5. **Verification Loops:** Every code change is verified by test, linter, or type checker.

6. **Progressive Disclosure:** SKILL.md stays under 500 lines. Templates in `assets/`, reference docs in `references/`.
