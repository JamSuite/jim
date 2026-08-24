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
  [ BUILD ] ───► [ REVIEW ] ───► [ SHIP* ] ───────┘
                     │
                     ▼ (Fold-Back Loop)
               [ BLUEPRINT ] ◄──── grounded by [ VERIFY ]

  * = not yet implemented
```

### The Fold-Back Loop

The living blueprints close a second loop after review: `/jim:review` senses
drift from the group's `000-blueprint` (living intent), the blueprint update
folds confirmed learnings back into it — or forks a violation into "fix the
code" — and `/jim:verify` grounds both moments in engine outcomes instead of
unaided judgment. See `/jim:blueprint` and `/jim:verify` in The Lifecycle in
Detail.

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
| `/jim:spec` | Define the work — feature, bug, or refactor; `reconcile` realizes spec ordinals bound while the coordination point was unreachable | `@jim:pm` | `spec.md` |
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
| `/jim:partition` | Migrate a project onto the blueprint partition doctrine — extract the code's dependency graph, propose a context map, materialize through the blueprint surface after a hard gate; auto-detects greenfield/repartition, `path`/`directory` assess territory-mode readiness, `rename <old> <new>` migrates a group's identity across the partition's artifacts and `split <old> into <new>...` fissions one spec group into N children through one grounded proposal and a single hard gate (surfacing the revealed cross-child `requires` edges and spanning cases a naive split gets wrong, and re-homing spec history per the `spec_migration` preference — `rewrite` rewrites a moved numbered spec's recorded identity, `forward` freezes it behind the ledger alias, `immutable` leaves the source in place, split-native and inapplicable to a rename), `merge <src>... into <target>` collapses N spec groups into one behind an interview and a single hard gate (absorption into an existing group or a fresh target, the same `spec_migration` re-homing, a mechanical collision-resolving fuse of the group blueprints), and `health` runs a read-only, advisory split/merge / name-mismatch read of the reconcile trend | `@jim:architect` | `BLUEPRINT.md` + group blueprints + issues |
| `/jim:verify` | Check a group's code against its `000-blueprint` invariants — mechanical floor, operator registry, criticality-gated read-only judges — plus contract mode (`--contracts`) checking the contract graph's edges against code on both sides; scoped modes (`--from-review` / `--since`) ground the fold-back loop (see The Lifecycle in Detail) | `@jim:reviewer` | Report + ledger event (no persisted verdict) |
| `/jim:debug` | Diagnose failures, produce report for spec/plan cycle | `@jim:coder` | `debug/{YYYYMMDD}-{topic}.md` |
| `/jim:brainstorm` | Freeform ideation — exploratory notes | `@jim:pm` | `brainstorms/{YYYYMMDD}-{topic}.md` |
| `/jim:issue` | Capture a discovery (`add <subject>`), move one through its lifecycle (`claim` / `release` / `start` / `close` / `reopen`), or review the collection (`list [filter]` / `stats` / `show <id>` / `insights`; bare → help); `reconcile` realizes ordinals bound while the coordination point was unreachable | `@jim:pm` | `issues/{YYYYMMDD}-{slug}.md` + `INDEX.md` |
| `/jim:meta-skill` | Create/update a jim plugin skill from spec | `@jim:meta` | `jim/skills/{name}/SKILL.md` |
| `/jim:meta-agent` | Create/update a jim plugin agent from spec | `@jim:meta` | `jim/agents/{name}.md` |
| `/jim:meta-test` | Scaffold a bash test file, append a case, or run the suite | `@jim:meta` | `jim/tests/{name}.sh` |

Registry integrity is a hand-run script surface rather than a skill:

| Command | What It Does | Agent | Output |
| :--- | :--- | :--- | :--- |
| `jimalloc.sh sweep` | Read-only integrity check — tree-vs-registry drift under named classes, plus everything the check did not cover; `0` clean / `3` drift / `4` could-not-check | — (hand-run; `/jim:verify` runs it as the `registry-tree-consistency` check) | report on stdout, no writes |
| `jimalloc.sh catch-up [--apply]` | Preview (or apply) the records a non-empty registry is missing, under the allocation path's compare-and-swap and erosion guard | — (hand-run) | one appended commit on the coordination branch |
| `jimalloc.sh lift [--apply]` | Preview (or record) the rename records a move made before the registry could witness it, corroborated against the ledger's own identity-pair events | — (hand-run) | one appended commit on the coordination branch |

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
| Spec | `docs/specs/{group}/{id}-{name}/spec.md` | Work definition — requirements, acceptance criteria, spec type (feature/bug/refactor). `{id}` is the identity the coordination allocator bound: a 3-digit ordinal unique within the group, or — when the coordination point was unreachable and the project configures `provisional` — a reserved `P-{date}-{slug}` token that IS the whole directory name, pending realization | `/jim:spec` |
| Plan | `docs/specs/{group}/{id}-{name}/plan.md` | Implementation path — codebase research, atomic tasks, dependencies | `/jim:plan` |
| Security Review | `docs/specs/{group}/{id}-{name}/security.md` (spec-scoped) or `{security_adhoc_path}/{YYYYMMDD}-{slug}.md` (ad-hoc opt-in) | Design-time findings — severity, route, phase coverage; gates `/jim:plan` and `/jim:build` start when `require_security` / `auto_security` is set | `/jim:sec` |
| Review Report | `docs/specs/{group}/{id}-{name}/review.md` | Post-build findings — drift vs spec/plan/architecture, code + process metrics, security regressions, alignment verdict; mineable frontmatter + narrative | `/jim:review` |
| Stage Ledger | `docs/specs/{group}/{id}-{name}/ledger.md` | Append-only event log of SDLC stage boundaries (baseline/head SHAs, per-stage start/finish, interruptions, re-runs); `/jim:build` records the build range and SHAs, and `/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:sec`, and `/jim:review` each record their own start/finish — `/jim:review` also appends its validated alignment verdict and self-commits `review.md` + `ledger.md`; `/jim:verify` records its per-invariant outcome counts on the group's `000-blueprint/ledger.md` and self-commits that ledger alone via `commit-verify` — its only durable trace, since no verdict artifact is persisted; map-tier blueprint, reconcile, and contract-mode runs record `tier=project` events on the specs-root `ledger.md` — the reviewer's process-metric source | `/jim:build` (+ spec/research/plan/sec/review/verify) |
| Debug Report | `docs/debug/{YYYYMMDD}-{topic}.md` | Diagnosis — error analysis, root cause, references to affected specs | `/jim:debug` |
| Brainstorm | `docs/brainstorms/{YYYYMMDD}-{topic}.md` | Exploratory notes — ideas, risks, options, may feed into specs | `/jim:brainstorm` |
| Issue | `docs/issues/{YYYYMMDD}-{slug}.md` + `INDEX.md` (path via `issues_path`; branch via `issue_placement`) | Discovery artifacts surfaced during the workflow — one markdown file per issue with a display ordinal (`num`), `open`/`active`/`closed` status, the filer and the current holder it records, the outcome of its most recent finish, typed relations, and an auto-generated index. By default they ride the current working branch; set `issue_placement` to a branch name to give a team one shared collection | `/jim:issue` |

### Discovery capture (`/jim:issue`)

`/jim:issue` is a single command with subcommands:

- **`add <subject>`** — capture one discovery from the current conversation as a structured markdown file (single confirm-or-edit moment with a sensitive-content scrub reminder). New issues get a `num:` display ordinal automatically.
- **`list [filter]`** — terse, grouped, configurable enumeration; an optional `open`/`active`/`closed`/`critical`/`high`/`medium`/`low` filter scopes the view. Closed issues are hidden from the default and priority-filtered views unless `issue_list_closed = "true"`; `list closed` is the ad-hoc closed view. Other defaults are set via the `issue_list_group` / `issue_list_sort` / `issue_list_cols` / `issue_list_order` keys in `jimconf.toml`.
- **`stats`** — counts (open/closed, by priority, by label, by origin) plus blocking analysis.
- **`show <id>`** — open one issue by its ordinal number, slug, or a slug prefix.
- **`insights`** — the LLM-analytical view: convergence on latent capabilities, a sequencing recommendation, and parallel-work candidates. Runs entirely inside the read-only `issue-analyst` subagent; if that agent cannot be dispatched the verb refuses rather than reading issue bodies in the main context.
- **`claim <id>` / `release <id>`** — take an issue, or give it up. One held by someone else is refused, naming the holder; `--force` takes it over. Release is gated the same way and for the same reason: otherwise release-then-claim would be a takeover with no override in it.
- **`start <id>`** — mark an issue underway, claiming it first when it is unheld.
- **`close <id> [--as done|wontfix|duplicate|obsolete]`** — finish it, recording how; a bare close records `done`. Any developer may close any issue, and `claimed-by` is preserved — it says who *held* the issue, not who finished it. Closing `--as duplicate` requires the superseding issue to be named in the record's `duplicates` relation.
- **`reopen <id>`** — return it to not-started and **keep** the outcome, which is what makes a reopen legible: an open issue carrying an outcome was finished before, and the outcome names how.
- **`reconcile`** — realize provisional ordinals bound while the ID-coordination point was unreachable (`id_coordination_unreachable = "provisional"`) into real coordinated ones. Previews the mapping and asks before applying, since realizing rewrites existing issue files.
- bare **`/jim:issue`** — print the subcommand help.

Issues are also surfaced automatically at the end of each SDLC phase as a candidate batch, gated by `issue_capture`. Move an issue with the lifecycle verbs above rather than by editing the file: `close <id>` records the outcome alongside the status and regenerates the index, where a close written by hand leaves `outcome` empty and the index reports that record as closed with no outcome. Those verbs own the placement door themselves, so they are unchanged when the collection lives on a designated branch (`issue_placement`). Editing an issue's *content* is the case that still needs the door — the file is not in your working tree — and goes through the two-step flow described in `skills/issue/SKILL.md` § 6a.

**One-time migration (`backfill.sh`).** A collection that predates the `num:` display ordinal is numbered once by running `bash skills/issue/scripts/backfill.sh num` against the issues directory — it assigns ordinals in `created:`-date order, is idempotent, and writes each file atomically. Run it once, up-front, before creating new issues. New issues never need it.

### Plugin Artifacts (Jim developing Jim)

| Artifact | Location | What It Is | Managed By |
|----------|----------|------------|------------|
| Plugin Vision | `jim/VISION.md` | Why Jim exists, what problem it solves | `/jim:vision` (from within jim/) |
| Plugin Architecture | `jim/ARCHITECTURE.md` | Plugin structure, agent-skill composition, naming conventions | `/jim:arch` (from within jim/) |
| Plugin Roadmap | `jim/ROADMAP.md` | Which skills/agents to build in what order | `/jim:roadmap` (from within jim/) |
| Plugin Workflow | `jim/WORKFLOW.md` | This file — the SDLC process itself | Manual or `/jim:meta-skill` |
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

Summarized layout — the authoritative, file-level tree lives in
`ARCHITECTURE.md` → Project Structure.

```
jim/
├── .claude-plugin/
│   └── plugin.json              # { "name": "jim", "version": "2.0.0" }
│
├── VISION.md                    # Why Jim exists (Jim's own strategic docs)
├── ARCHITECTURE.md              # How Jim is structured
├── ROADMAP.md                   # What to build next for Jim
├── BLUEPRINT.md                 # Jim's own project-tier context map
├── WORKFLOW.md                  # This file — the SDLC process itself
│
├── agents/                      # One .md per persona
│   ├── pm.md                    # → @jim:pm
│   ├── architect.md             # → @jim:architect
│   ├── researcher.md            # → @jim:researcher
│   ├── coder.md                 # → @jim:coder
│   ├── security.md              # → @jim:security
│   ├── reviewer.md              # → @jim:reviewer
│   ├── meta.md                  # → @jim:meta
│   ├── investigator.md          # read-only deep-dive subagent, spawned by /jim:review
│   ├── judge.md                 # read-only invariant/edge judge, spawned by /jim:verify
│   ├── issue-analyst.md         # read-only insights subagent, spawned by /jim:issue insights
│   ├── gatherer.md              # read-only per-group evidence gatherer, spawned by /jim:partition
│   └── meta-matrix-probe.md     # runtime-probe subagent (manual harness)
│
├── skills/                      # One dir per skill: SKILL.md + optional assets/ (templates),
│   │                            # references/ (methodology), scripts/ (deterministic bash)
│   │
│   │  # ── SDLC Lifecycle ──
│   ├── spec/                    # → /jim:spec        assets + references
│   ├── spec-check/              # → /jim:spec-check  Socratic DoD audit (also invoked by /jim:spec)
│   ├── research/                # → /jim:research    assets + references
│   ├── plan/                    # → /jim:plan        assets + references
│   ├── build/                   # → /jim:build       references (TDD guide)
│   ├── sec/                     # → /jim:sec         assets + references
│   ├── review/                  # → /jim:review      assets
│   ├── verify/                  # → /jim:verify      references + scripts (jimverify.sh — the deterministic check floor)
│   ├── debug/                   # → /jim:debug       assets
│   │
│   │  # ── Strategic ──
│   ├── vision/                  # → /jim:vision      assets
│   ├── roadmap/                 # → /jim:roadmap     assets
│   ├── arch/                    # → /jim:arch        assets
│   ├── blueprint/               # → /jim:blueprint   assets (blueprint + map templates) + references
│   ├── partition/               # → /jim:partition   references + scripts (jimpartition.sh — the extraction/coverage substrate)
│   ├── brainstorm/              # → /jim:brainstorm
│   │
│   │  # ── Discovery ──
│   ├── issue/                   # → /jim:issue       assets + scripts (index/new/render/backfill/migrate/reconcile/place)
│   │
│   │  # ── Introspection ──
│   ├── conf/                    # → /jim:conf        scripts (jimconf.sh — the shared config resolver)
│   ├── file/                    # → /jim:file        scripts (jimfile.sh — the shared path/id resolver)
│   ├── ledger/                  # → /jim:ledger      scripts (jimledger.sh — the SDLC stage ledger CLI) + read-only inspector
│   │
│   │  # ── Meta (Jim building Jim) ──
│   ├── meta-skill/              # → /jim:meta-skill
│   ├── meta-agent/              # → /jim:meta-agent
│   ├── meta-test/               # → /jim:meta-test   assets + scripts (testlib/run/metatest)
│   └── meta-matrix*/            # manual runtime-probe skill family (not part of the SDLC)
│
├── tests/                       # Developer-only bash tests — not loaded by Claude Code
├── docs/
│   ├── specs/                   # Jim's own spec groups — partition declared in BLUEPRINT.md
│   ├── issues/                  # Discovery capture + INDEX.md
│   ├── brainstorms/             # Freeform ideation
│   └── debug/                   # Debug reports
├── jimconf.toml.example         # Shipped config template
└── README.md
```

### Agents

| Agent | Role | Used By |
|-------|------|---------|
| `@jim:pm` | Product strategy, specs, vision, roadmap | `/jim:spec`, `/jim:vision`, `/jim:roadmap`, `/jim:brainstorm` |
| `@jim:architect` | Technical planning, architecture, blueprints | `/jim:plan`, `/jim:arch`, `/jim:blueprint` |
| `@jim:researcher` | Codebase investigation and technical landscape research | `/jim:research`, invoked by PM or architect |
| `@jim:coder` | TDD implementation, debugging | `/jim:build`, `/jim:debug` |
| `@jim:reviewer` | Post-build review + invariant/contract verification | `/jim:review`, `/jim:verify` |
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
  - spec-check
  - vision
  - roadmap
  - brainstorm
  - issue
---
```

```yaml
# jim/agents/architect.md
---
name: architect
description: Technical architect. Plans implementation and maintains
  the technical architecture and the living blueprints. Delegates
  codebase investigation to @jim:researcher subagent.
skills:
  - plan
  - arch
  - blueprint
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
description: Post-build reviewer and invariant verifier. Drift, metrics,
  security regressions, blueprint invariants and contracts.
skills:
  - review
  - verify
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
4. Binds the spec's identity through the coordination allocator — never from the tree. A reachable coordination point yields the next 3-digit ordinal for the group; an unreachable one either issues nothing and says so, or (when `id_coordination_unreachable = "provisional"`) binds a reserved `P-{date}-{slug}` token that every later stage runs against unchanged
5. Generates spec using template from `spec/assets/spec-template.md`
6. You review and approve or request changes

**Output:** `docs/specs/{group}/{id}-{name}/spec.md`

**Gate:** Human approves the spec. Status changes from `draft` to `approved`.

### `/jim:plan`

**Purpose:** Research the codebase and create an implementation plan.

**Process:**
1. Reads the approved spec
2. Delegates codebase investigation to `@jim:researcher` subagent — integration points, fault locations (bugs), blast radius (refactors)
3. Reviews research findings
4. Checks ARCHITECTURE.md for architectural constraints
5. Breaks work into atomic, checkable tasks
6. Surfaces a cross-group **blast-radius advisory** — when the plan's group is a provider in the contract graph, mechanically names every dependent group and the entry it relies on (from the derived `## Contract Graph`, `graph as of <Last reconciled>`), so you can weigh the blast radius before approving; non-blocking and silent on single-group projects. The plan-time complement to the reconcile pass's face-change blast radius (below)
7. You review and approve

**Output:** `docs/specs/{group}/{id}-{name}/plan.md`

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

**Process:**
1. Resolves the build range from the spec's `ledger.md` — the baseline and head SHAs `/jim:build` recorded, so the review sees that build's changes even when several specs share a branch
2. Triages the diff by risk and fans out read-only `investigator` subagents across the high-stakes regions and every acceptance criterion, at the depth `review_depth` sets
3. Reports drift against the spec, the plan, and `ARCHITECTURE.md`, plus code and process metrics and any security regressions; findings can be captured as issues
4. Senses living intent where the group has a `000-blueprint`, via `/jim:verify --from-review` — its own dimension in `review.md`, never setting the alignment verdict
5. Writes `review.md` with a single alignment verdict (`aligned` / `minor-drift` / `major-drift`) and self-commits it alongside `ledger.md`

**Output:** `docs/specs/{group}/{id}-{name}/review.md`

**Gate:** Findings are advisory — a report, never a veto. `require_review` is the separate axis: it makes the review a required phase, holding the build's completion gate until the review has run.

See [Review](docs/features/review.md) for the inputs and their trust levels, the triage table, metrics, blueprint integration, and configuration.

### `/jim:blueprint`

**Purpose:** Keep the living blueprints current at both tiers — each group's `000-blueprint` (the build-grade map of one group) and the project-tier context map (`BLUEPRINT.md`, the declared partition itself).

**Process:**
1. **Group tier** (`/jim:blueprint <group>`) — a full generate amalgamates the group's specs, `ARCHITECTURE.md`, and code into `000-blueprint/spec.md` (responsibility, provides/requires faces, structure, invariants); `--from-review <spec-dir> <group>` and `--since <ref> <group>` propose targeted section diffs instead, each guarded by the recorded invariants so a violation forks to *fix the code* or *fold the intent*
2. **Project tier** (`/jim:blueprint`, bare) — creates the context map by reading the strategic docs *and* interviewing for domain knowledge, or updates it differentially; `/jim:spec`'s assignment advisor consumes it on every spec, and a new group can only be minted through this surface
3. **Reconcile** (`--reconcile`, and after every write) — re-derives the contract graph by joining each group's `requires` face against the others' `provides`, reports and offers the mismatches as issues, and records the finding and graph-health counters on the specs-root ledger

**Output:** `docs/specs/{group}/000-blueprint/spec.md` · `BLUEPRINT.md`

**Gate:** Human approval on every write; `auto_blueprint` buys unattended writes for additive and low-criticality edits only — downgrades of load-bearing content always prompt per item. Both tiers self-commit path-scoped and record `blueprint` stage events on their ledgers.

See [Blueprints](docs/features/blueprints.md) for the doctrine, the blueprint's sections, territory modes, the contract-graph finding classes, blast radius and graph health, and configuration.

### `/jim:verify`

**Purpose:** Ask whether a group's code still honors what its `000-blueprint` says must hold — per-invariant outcomes with evidence, violations offered as tracked issues. The engine is read-only toward the project: it reports, never fixes.

**Process** (`/jim:verify [--appetite <level>] <group>`):
1. **Parse** — `jimverify.sh` reads the blueprint's Invariants table (`Id` / criticality / `Check`) and the map's territory declarations; a group with no blueprint, or a blueprint with no invariants, reports that plainly and stops
2. **Check** — every invariant runs on a three-tier ladder: a zero-config mechanical floor (`pattern` / `structure` checks plus territory conformance), the operator's own project tooling through `verify_command_<name>`, and read-only `judge` subagents for what no mechanical check can express, criticality-gated by `verify_appetite` and bounded by `verify_fanout_cap`
3. **Report** — criticality-led per-invariant outcomes (`holds` / `violated` / `failed` / `unconfigured` / `skipped`) with evidence on every non-holding line, so a clean line always means "checked and sound", never "not looked at"; violations are offered as captured issues, and outcome counters self-commit to the group's `000-blueprint/ledger.md`

**Modes:** `--contracts [<group>]` checks the contract graph's edges against the code on both sides of each boundary; `--retirement [<group>]` runs the load-bearing sources in reverse, flagging blueprint entries nothing justifies anymore; `--from-review <spec-dir> <group>` and `--since <ref> <group>` are the scoped runs that ground the fold-back loop, handing their outcomes to the caller rather than making it re-derive them.

**Output:** Report in conversation + outcome counters on the ledger — no verdict artifact persists

**Gate:** None — the run is on-demand and advisory. Its only writes are issue files the developer confirms and the self-committed ledger record.

See [the verification engine](docs/features/blueprints.md#the-verification-engine) for the ladder in full, the trust boundary at the registry rung, outcome precedence, and each mode's grain.

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

Jim's own specs live under `docs/specs/`, partitioned into spec groups declared in `BLUEPRINT.md`. Jim's strategic docs (`VISION.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `BLUEPRINT.md`) live at the plugin root.

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

## Operating Notes

### Authorizing the agent fan-outs

Several jim phases do their real work by delegation: `/jim:review` fans out
`investigator` subagents, `/jim:verify` fans out `judge` subagents,
`/jim:partition` fans out `gatherer` subagents, and `/jim:issue insights` runs
entirely inside the `issue-analyst`. These are not an optimization — they are the
independence the phase's output claims. A review of a commit range by its own
author is a materially weaker instrument than a fan-out over the same range.

Some Claude Code builds inject a system-prompt directive that withholds the Agent
tool unless the user asked for it, on some models and not others. It is not
visible in `CLAUDE.md` or `settings.json`, because it does not come from your
project — from inside a session it is indistinguishable from something you
configured.

**The directive is self-limiting: an explicit request satisfies it.** If you want
the fan-outs, say so once per session:

> invoking a jim skill authorizes the agents that skill prescribes

**What jim does when the fan-out does not run.** Each phase names the gap rather
than passing its own unaided reading off as the delegated one:

| Phase | Behavior when its fan-out cannot be dispatched |
|-------|-----------------------------------------------|
| `/jim:verify` | Affected invariants are `failed` (reason `undelegated`), never `holds`; the report says so and the ledger event carries `undelegated=<n>` |
| `/jim:review` | `review.md` names the undelegated coverage and what rests on spine-level reading only; the ledger event carries `undelegated=<n>` |
| `/jim:partition` | No gatherer-marked invariant is recorded, and the run does not carry ungathered evidence to its human gate |
| `/jim:issue insights` | Refuses and stops — reading issue bodies in the main context is the specific thing the analyst boundary exists to prevent |

A clean report from a phase whose fan-out never ran is the one output these
skills are built not to produce. If you see the degradation named, re-run with
the authorization above rather than trusting the result.

---

## Rules of Engagement

1. **Human-in-the-Loop:** Agents STOP after each phase gate or atomic task. No autonomous multi-phase execution.

2. **Differential Updates:** Every `/jim:` command creates if the artifact doesn't exist, refines based on new context if it does. Never overwrites blindly.

3. **No Ghost Tasks:** If a code change isn't in the plan, update the plan first.

4. **Strategic Alignment:** Specs reference the vision and architecture. The PM checks this during `/jim:spec`.

5. **Verification Loops:** Every code change is verified by test, linter, or type checker.

6. **Progressive Disclosure:** SKILL.md stays under 500 lines. Templates in `assets/`, reference docs in `references/`.
