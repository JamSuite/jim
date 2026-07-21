# BACKLOG

*Items are `BACK-###`, numbered by priority (`001` = highest). Numbers float on reorder; always reference an item as `BACK-### (title)`.*

# Tier 0: Active Priority Queue (jim-ready for jimui)

Ordered near-term queue to get jim ready for jimui. Work these top-to-bottom; everything below the divider is the standing backlog. `UNBLOCKS-JIMUI` / `SKILL-UPGRADE` tags mark what each unblocks.

## BACK-001 · Reduce "claude-speak" — make jim's prose literal, efficient, specific, concise

**Brainstorm complete:** `docs/brainstorms/20260720-claude-speak.md` (+ `20260720-claude-speak.csv`, `20260720-claude-speak-project-audit.csv`). **Ready to spec or edit surgically.**

**Finding.** jim's prose is precise in *contract-shaped* content (acceptance criteria, schemas, bash/frontmatter) but drifts vague and verbose in *judgment-shaped* content (pm interview, brainstorm, vision, problem statements, user stories). No single dominant defect — broad and shallow across ~30 files, in three clusters: (1) **vague terminal instructions** with no downstream check ("non-obvious choice", "reasonable defaults", "where relevant"); (2) **cross-file constraint restatement** that jim's 3+-places dedup rule misses ("No code writing", "The human decides", "Does NOT fix code"); (3) **undefined terms** used before a gloss (STRIDE, LINDDUN, SDLC, Peer Feedback, Connextra). Metaphor is the smallest category — **no ban needed** (no competitor bans it). A real-project audit of 73 korswerk spec/brainstorm artifacts confirmed the split: ACs strong; narrative bloated, plus a few untestable-AC leaks ("match-the-design" ACs; ACs that defer their value to Open Questions).

**Proposed fix (brainstorm Task 4).** A 6-point writing rule — specific-over-vague · say-it-once · imperative · define-on-first-use · cut rationale that prevents no mistake · literal-by-default — stated **canonically once** in `ARCHITECTURE.md` → Plugin Conventions → Writing Style; **self-propagated** by extending the `meta-skill`/`meta-agent` writing-style checklist (tighten dedup to catch cross-file restatement; bound the current "reasoning beats rigid directives" rule); **reaching artifacts** via a compact form + one validation-checklist item injected into each artifact-producing skill (spec, plan, research, arch, sec, build, debug, issue, vision, roadmap, brainstorm — see brainstorm §4.2 table); plus **two new `spec-check` probes** (external-design-deferral, Open-Question-value) and a narrative cap for spec/brainstorm (§4.5). Then one worst-first cleanup pass off the CSV worklist (§4.4). Prose-only, low risk (no `scripts/` or frontmatter diffs).

**Next step:** a `/jim:spec` for the writing-rule + meta-skill/meta-agent changes + spec-check probes, **or** surgical edits to `ARCHITECTURE.md` and the two meta-skills, **or** a combination. Open decisions (brainstorm Task 5): bound the "explain why" rule? extend dedup to cross-file? rollout order? rule location (ARCHITECTURE.md recommended).

## BACK-002 · jim:review — merge the already-built skill

jim:review is **already built** — on the branch `origin/feat/review`, **73 commits ahead of main**, and
complete: `skills/review/{SKILL.md, assets/review-template.md, scripts/jimledger.sh}` plus
`agents/reviewer.md`. It has a running log of reviews, a `review.md` file with code and process
metrics, and a review life-cycle stage. Its stated purpose (*"review what a build actually shipped
against its spec, plan, and architecture… detecting drift"*) also already covers the check that the
code matches what the spec said. Just merge it: review the branch, run its tests, merge. It feeds BACK-007 (stage/status rule):
a spec that has a `review.md` file is at the "review" stage. **Tracked by jim issue #13**, which is
about *comparing* the skill against the Osmani rubric and assumes the code is available — merging is the
unstated first step. About 15 minutes; nothing else depends on it, so do it at any time.

## BACK-003 · Integrate Joe's blueprint branch (`feat/blueprint`)

Joe's `origin/feat/blueprint` branch (**368 commits ahead of `main`**) adds **`/jim:blueprint`** — a
*project-tier context map* that declares the partition of a project into **spec groups**, each a
deliberate context boundary. It maintains a root `BLUEPRINT.md` (the context map + per-group
provides/requires faces) plus a per-group blueprint spec (`docs/specs/jim/000-blueprint/`), and
**derives** a cross-group contract graph. It ships an **update mode** with guarded invariant folds (a
violated invariant is never silently rewritten; `critical`/`high` downgrades always prompt, even under
`auto_blueprint`), a **gate-presentation rule** for approval gates (spec 040), and companion skills
**`partition`**, **`review`**, and **`verify`** (an invariant/contract/retirement verification engine).
Specs `000`, `029–034` (blueprint), `035–037` (verify), `026–028` (review), `040` (gate presentation).

**Next step:** review the branch, run its tests, and **integrate Joe's blueprint branch** into `main`.
Scope note: this is large and **overlaps `feat/review`** (both carry `review/` + `verify/`) — sequence
the two merges so they don't conflict.

## BACK-004 · /jim:arch upgrade — organize many small architecture docs  

This turns `/jim:arch` into a system that keeps many small architecture documents organized: one short
`ARCHITECTURE.md`, plus topic documents each tagged with a `kind:` field, plus an index, plus
Architecture Decision Records (ADRs). An ADR is a short document that records one design decision and
the reason for it. This replaces the old single large document. **It is ready to spec** — the
architecture brainstorm (`docs/brainstorms/20260717-jim-arch-knowledge-corpus.md`)
already contains its own `/jim:spec` kickoff prompt, so this goes straight to
`/jim:spec → /jim:plan → /jim:build`. This is your headline jim upgrade and the one that most changes
how jim documents itself. jimui's own `docs/arch/` already uses the topic-document shape, so the
upgraded `/jim:arch` fits right in and maintains those documents as jimui grows. **One direct input to
BACK-007 (stage/status rule):** use this skill's **ADR format** as the home for the stage-derivation
rule, so status derivation ships as a proper ADR, not a loose note.

## BACK-005 · jim:issue upgrades — make an issue a tracked unit of work

Make jim:issue a recognized unit of work in the jim workflow

per the issues-and-specs brainstorm docs/brainstorms/20260719-issues-vs-specs-relationship.md

**Two grades of work (the reframe).** Not everything is a spec. **Most issues are chores.** A chore is
small work done directly in a fresh plan-mode session, with no spec, never using `/jim:build`. So jim
has two grades of work: the **chore** (the *issue* is the unit of work) and the **spec** (the *spec* is
the unit of work, with a full life cycle). Today jim captures a chore and then stops tracking it once
work starts. There is no in-process state and no record of where the work happened. The goal here is
to track the unit of work that the issue already is. (Issues still get **no acceptance criteria and no
`/jim:build`** — the spec's role does not change.)

1. **Schema and template** (the frontmatter in `skills/issue/`): add `assignee` (a GitHub username if
   one is available), `branch` (a git branch name), `session` (a Claude Code session id or URL), and a
   forward-link `spec:` field (or a `promoted-to` relation in the existing `relations:` graph). Add a
   new status value **`in_progress`** alongside the existing `open` and `closed`.
2. **Writer and renderer** must accept the new value: `new.sh` currently **rejects** any status other
   than `open` or `closed`; `render.sh` holds `STATUS_TOKENS=(open closed)` and prints the status in a
   column 8 characters wide. `in_progress` is 11 characters and would break the column alignment, so
   widen the column or pick a shorter value (`active` or `wip`).
3. **Transition helper plus commands.** Add a script `status.sh <id> <new-status> [--branch X]
   [--session Y] [--assignee Z]` that writes atomically, updates the `updated` timestamp, and checks
   the transition (`open → in_progress → closed`). Expose it through thin
   `/jim:issue start | close | reopen` commands. `start` can read the current branch with
   `git branch --show-current`. *Direct note: this adds commands that change state, which breaks jim's
   current rule that capture is the only judgment command and reads are deterministic. That is a real
   design decision, not a free addition.*
4. **The open-to-in-process flow (your exact intent).** `/jim:issue start` sets `status: in_progress`,
   writes the **session id, branch, and assignee**, **commits that metadata to `main`**, and *then* the
   work proceeds in that session and branch. (Once work is committed, the session id can be read from
   the existing `Claude-Session:` commit trailer, so it may not need writing a second time.)
5. **The `next` and `blocked` read commands** in `render.sh` (the safe, on-philosophy addition from the
   tracker comparison — in the same family as the existing `insights` command). These show which issues
   are ready to work on and which are blocked, read from the relations graph. They feed jimui's
   whatsnext (job 4).
6. **Forward link on promotion.** When a spec is created from an issue, write the `spec:` link back into
   the issue. This closes jim's gap where an issue records where it came from but not where it went to
   (so issue #14 → spec 026 becomes visible from the issue). *(The promotion itself happens in
   `jim:epic` — not as a command on the issue.)*

Other possible candidates:

- relocate closed issues to closed/ folder ?
- new issues following the commit to `main` discipline so `main` branch always has current issue state and we help minimize id# collisions
- (numbered index collisions) ?  <-- be careful referencing issues solely by numbers because they can change (not sure what improvements can be made here but the edge case is merging large branches together probably will have index collisions - how to further reduce id collisions in the index) <-- note reindexing can cause id ##'s to change that means we shouldn't reference issues by id# we should reference them by filename

## BACK-006 · jim:epic skill and file format  UNBLOCKS-JIMUI

jim has **no epic** today. Per the 2026-07-19 brainstorm, an epic is more than a label over issues. It
is the layer that decides which specs to write and in what order. It fills the real gap between
`ROADMAP` (whole-project Now/Next/Later buckets) and a single spec. An epic is a **titled goal plus an
ordered list of the specs we intend to write**, with dependencies noted so that dependent items come
first. It lives at `docs/epics/`.

Importantly, **the epic is where issues become specs.** Promotion happens here, *not* as a command on
the issue. The epic reads the pile of captured issues, decides which become work, orders them, records
dependencies, and links issue #14 → spec 026 (the forward link from BACK-005 (jim:issue upgrades)). This is also where the "issue
life cycle / cross-phase state" work that jim postponed back in spec 018 finally lands — without
changing the issue itself.

Full loop: `/jim:brainstorm jim:epic` (the file: a goal and description, the spec order and
dependencies, which issues become specs, the math that totals progress across items, and the
frontmatter) → `/jim:spec` → `/jim:plan` → build. **One decision to settle when this is specced:** are
the epic's *members* issues (reusing that type) or a new, separate type? Rule to hold: an epic orders
existing captured issues; it does not turn issues into a backlog. This blocks jimui's epics domain
(job 7). It is independent of BACK-002/004/005/007, so it can run in parallel.

## BACK-007 · One rule for deriving stage and status  UNBLOCKS-JIMUI

jim specs have **no `stage` field** (only `status: draft|approved`). The board, whatsnext, and the
percent-complete number all need a life-cycle stage. That stage is derived from *which sibling files
exist* (`spec`, `plan`, `research`, `review.md`), plus the status, plus signals from issues.
- **The rule:** write the derivation as an **ADR** (in the BACK-004 (/jim:arch) ADR format) — one page, the single source.
- **The script (build it properly under jim-first):** a deterministic script (shell, like `render.sh`)
  that outputs each spec's derived stage and its "next step" as data. This way **jim and jimui read one
  source**, not two implementations that can drift apart. This script is what makes "status can never
  drift" true. Depends on BACK-002 (jim:review) (for the `review.md` stage) and BACK-004 (/jim:arch) (for the ADR format).

## BACK-008 · Core Software Development Life Cycle (SDLC) skill upgrades  SKILL-UPGRADE

From `docs/research/20260717-competitive-landscape-sdd-skills.md` these all need review — just a summary of some ideas from the research. We are not committed to any ideas yet; we need to review the research, the suggestions, study the prior-art implementations, and decide what changes to make to adhere to jim's vision and workflow. Don't just take whatever from whoever because they're popular.

These are what "build jimui with the latest jim" actually means. They improve the exact skills every
jimui slice runs. Four upgrades, each its own spec (they can run in parallel, in separate git
worktrees):
- **`/jim:spec` — testable acceptance-criteria grammar** using the Easy Approach to Requirements Syntax
  (EARS), for example "WHEN <trigger> THE SYSTEM SHALL <response>". *jim issue #16.* Every jimui spec
  then gets acceptance criteria a machine can check.
- **`/jim:plan` — cross-artifact consistency check** (in the style of Spec-Kit's `/analyze`: a checker
  that confirms the spec, plan, and tasks agree, plus a check on task size). This catches mismatches
  before any code is written, on a 10-group app where such mismatches add up.
- **`/jim:build` — verify-before-done step** (the superpowers sequence: IDENTIFY → RUN → READ → VERIFY;
  and ban vague words like "should", "probably", "seems"). This requires evidence before any task is
  marked done.
- **`/jim:spec` — read an issue in** (the brainstorm's "Move 1"): add something like `issue/scripts/render.sh show` to
  the spec skill's `allowed-tools` so `/jim:spec` can pull a *named* issue into scope, and teach it to
  **offer** relevant open issues without pulling them in on its own (the human decides which to
  include), recording the forward link when one is pulled in. **Do not add a `--from-issue` flag** —
  typing the issue in the conversation, or pasting the issue's file path, already covers this.
- **Plan-correction flow (after approval)** — edit approved plans and propagate the fixes into the
  code. *jim issue #15.* You *will* revise plans partway through a build on an app this size. *(Related:
  the brainstorm flags "chores that surgically correct an earlier spec and its code" as a separate
  problem — jim and Claude tend to treat specs as write-once — worth filing as its own jim issue
  alongside #15.)*

jim issues **#14** (automate the competitive-research refresh) and **#12** (a brainstorm on a passive
versus active stance) are genuine jim improvements, but **neither blocks anything** — not the jim-ready
checklist, not any jimui job. This is the one place the "everything before jimui" rule relaxes: pick
them up whenever, including after jimui starts. This does not delay your priorities — #14 and #12 were
never on your first-things list.

---

# Tier 1: High Importance

Items here close obvious gaps in the existing SDLC loop, fix known bugs that create friction every session, or unblock decisions the user has been wanting for a while. Address before Tier 2.

## BACK-009 · VISION.md — vision statement + competitive landscape



**Origin:** Z_STUFF_TO_DO line 28, the "what is the intention?" section (lines 70–91), plus user request 2026-05-13 to position jim against `addyosmani/agent-skills` and `garrytan/gstack`.

**Problem statement.** VISION.md is missing two things:

1. **A clear, concise vision statement.** The "what is the intention?" notes in `Z_STUFF_TO_DO` already capture the raw material: built jim to support master's studies and LinkedIn branding; not aiming for mass-market popularity; want it to work for me and a small team; openness to small-team adoption for credibility.

2. **A competitive landscape / prior-art section.** Two reference projects worth positioning against:
   - **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — Addy Osmani's curated collection of agent skills. Same primitive (Claude Code skills) but a different shape (curated library of individual skills) vs. jim's shape (an opinionated SDLC workflow built from skills + agents). Already cited as prior art for HOWTO body templates in BACK-004 (/jim:arch).
   - **[garrytan/gstack](https://github.com/garrytan/gstack)** — Garry Tan's opinionated stack. Positions in the same "small team productivity / personal branding" space the vision statement is targeting.
   Articulating what jim *is* and *isn't* relative to these two clarifies positioning for any small team evaluating jim.

**Next step prompt:**
```text
/jim:vision

Update VISION.md with two additions:

1. A concise vision statement. Source material in Z_STUFF_TO_DO lines 70–91:
   - Built jim to help build an app for master's studies AND for LinkedIn / professional branding.
   - That others started using it has opened new opportunities, but jim is NOT trying to be a mass-market tool.
   - Goal: works for me and my team; ideally adopted by other small teams to build credibility.
   - Explicit non-goals: multi-model support, deep configurability, extensibility, token compression — interesting but not the point of v2.
   - Open question for v3: how far do we push v2 before considering a v3?
   Draft 2–3 sentences for the vision statement, a short non-goals section, and a "who jim is for" section.

2. A "Prior Art & Competitive Landscape" section. Read these two repos and articulate how jim differs:
   - https://github.com/addyosmani/agent-skills — curated library of individual Claude Code skills. jim differs by being an opinionated SDLC workflow (spec → plan → research → build → review) rather than a skill catalog.
   - https://github.com/garrytan/gstack — opinionated dev stack for small teams / solo builders. Useful to articulate jim's positioning in the same "small team productivity" space.
   For each: 2–3 sentences describing the project, then 1–2 sentences on what jim does differently and why a user might pick one over the other. Honest positioning, not marketing.

ALSO `jim:vision` should write the vision out to VISION.md as it's creating it; not wait until the end of the interview to write the file 

Confirm with me before writing. If WebFetch fails on either repo URL, stop and ask me to paste the README content.
```

## BACK-010 · HANDOFF between spec and plan

- jim:plan made some choices without consulting me. 

spec had: 

- **Architect note:** Three viable options to weigh:
  - **A — Inline replacement.** Replace the existing silent self-check inside `/jim:spec` with the Socratic DoD invocation. Simplest; tightly coupled to `/jim:spec`'s lifecycle. Cannot audit hand-edited or historical specs.
  - **B — Dedicated `/jim:spec-check` skill.** A standalone skill invocable against any spec.md. Reusable for hand-edited specs, historical audits, and DoD development. Adds a new skill surface and an associated agent binding.
  - **C — Hybrid.** Standalone `/jim:spec-check` skill that `/jim:spec` invokes at validation via `Skill(jim:spec-check)`. Same logic, two entry points. Uses jim's established skill-to-skill invocation pattern (see `ARCHITECTURE.md` → Skill Invocation, validated by spec 014).
- **Routing hint:** Architect to decide.

architect chose one option. I the user wanted a different option. architect never asked.

How should the architect decide when to ask?  without being too nosy/annoying?  

For the handoff... would subagents be a good option? What skill invocation would make the most sense if we want to start with a clean context? what if we wanted to start with the existing context?  how would the skill invocation best be implemented?

For the handoff... does jim:plan and jim:research have adequate ability to figure out from the spec what issues it needs to address? how to consume any suggestions/flags/questions/tasks from the spec? how to make sure they all get done? 

in my experience jim:research and jim:plan have already been good at finding what it needs to do from the spec. I'm not sure what if any improvements need to be made here. 

I'm more concerned with the architect making shoot-from-the-hip decisions on important items but I'm not sure how to convey to it what items are important ?? (can that/should that be part of the spec process? I'd rather not manually have to instruct what's important or not but what would be the criteria for importance I have no idea)

## BACK-011 · jim:research absolute paths bug

**Origin:** Z_STUFF_TO_DO line 108. Known bug, small surface, high friction.

**Problem statement.** `research.md` files contain absolute paths to source files (e.g. `/home/adri/projects/...`). These paths break the moment the repo is opened on a different machine, in a worktree, or shared with a teammate. All file references should be relative to the project root.

**Next step prompt:**
```text
/jim:spec jim:research relative-paths bug

Bug: research.md files generated by /jim:research and the @jim:researcher agent contain absolute filesystem paths (e.g. `/home/adri/projects/JamSuite/repos/jim/skills/...`). These should be relative to the project root.

Steps to reproduce: run `/jim:research <topic>` against any spec, open the produced research.md, search for `/home/`.

Expected: paths like `skills/research/SKILL.md` or `docs/specs/jim/...`.
Actual: paths like `/home/adri/projects/JamSuite/repos/jim/skills/research/SKILL.md`.

Why it matters: breaks portability across machines, worktrees, and contributors; also pollutes diffs.

Likely fix location: the researcher agent prompt under `agents/researcher.md` and/or skills/research/SKILL.md — instruct relative paths and verify with the existing test patterns under skills/meta-test/.
```

## BACK-012 · jim:debug — include applied resolution and gate the "chosen recommendation"

**Origin:** Z_STUFF_TO_DO lines 24–26. Two related complaints about the same skill.

**Problem statement.** `jim:debug` produces high-quality debug reports, but two things rub:
1. The report labels one option as **"Chosen recommendation:"** before the user has actually chosen anything — it should be presented as a *proposed* recommendation until confirmed.
2. After the user picks and applies a fix, the resolution is not written back into the debug report. The debug report ends at "here are the options" instead of "here is what we did and why."

**Proposed scope:**
- Rename `Chosen recommendation:` → `Proposed recommendation:` (or similar) until the user confirms.
- After confirmation, add a new section `## Resolution` to the debug report capturing: which option was chosen, what code was changed, what tests now pass, and any follow-up TODOs.
- Optional: `/jim:debug` could prompt to hand off to `/jim:build` to apply the chosen fix, rather than ending at the report.

**Next step prompt:**
```text
/jim:spec jim:debug resolution-capture

Refactor: /jim:debug currently labels one option as "Chosen recommendation:" before the user has chosen anything — and the report ends there. The applied fix never makes it back into the debug report.

Two changes:
1. Rename "Chosen recommendation:" to "Proposed recommendation:" (or similar) — the wording should reflect that no decision has been made yet.
2. After the user confirms which option to take and the fix is applied (likely via a /jim:build handoff), append a `## Resolution` section to the debug report capturing: chosen option, code changes (file:line refs), test outcome, follow-ups.

when acting on a /jim:debug report, update the report with chosen-implementation details, not just the original diagnosis 

Open question for the interview: should /jim:debug actively offer a /jim:build handoff after confirmation, or stay strictly diagnostic and let the user dispatch the build separately? The user has expressed appetite for the handoff path.

Prior art: skills/debug/SKILL.md and the debug reports under docs/debug/ (e.g. docs/debug/20260510-claude-code-bash-injection-permissions.md).
```




---

# Tier 2: Medium Importance

Real improvements to the SDLC loop, but not blocking daily work. Pick up after Tier 1 lands. **BACK-013 (jim:security) is the top priority in this tier** — promoted from Tier 3 because security review of LLM-generated code is a known engineering concern, not speculation.

## BACK-013 · jim:security — code/runtime-scanning leftovers (design-time shipped)

**Status:** The design-time half shipped as `jim:sec` (spec `016-sec`; skill `skills/sec/`; agent `@jim:security`): freeform expert review + STRIDE completeness sweep + conditional LINDDUN, a `security.md` artifact, issue-filing authority, and `/jim:plan` + `/jim:build` phase gates. That *exceeds* this task's original design-time ask.

**Not built — folds into BACK-002 (jim:review)** (reviewing LLM-*written code* is a post-build concern, exactly as `docs/specs/jim/016-sec/spec.md` forecasts jim:review consulting `@jim:security` as a lens):
- Branch-diff / staged-changes scoping (review a git diff, not a spec).
- OWASP Top 10 pattern matching (jim:sec deliberately chose STRIDE instead).
- Secret-leakage detection (regex + entropy).
- Dependency-CVE checks against manifests (`package.json` / `pyproject.toml` / `Cargo.toml`).
- Insecure-default *code* detection (`debug=True`, permissive CORS).
## BACK-014 · extensibility — extension points and per-project agents (kim)

**Origin:** Z_STUFF_TO_DO lines 86, 122–128.

**Problem statement.** The user is interested in extending jim's agents with project-specific context — e.g. a downstream "kim" agent that lives in a project's `.claude/` folder and is custom-tailored to that project but uses jim under the hood. Also: extension points in jim's skills where config can swap in project-specific behavior (e.g. `build_verification_skill=.claude/skills/my_build_verification/SKILL.md`). Overlaps significantly with BACK-004 (/jim:arch).

**Next step prompt:**
```text
/jim:brainstorm jim:extensibility

User has expressed appetite for jim being extensible at specific seams (Z_STUFF_TO_DO lines 86, 122–128):
- Config params for skills that name extension-point skills (e.g. `build_verification_skill = .claude/skills/my_build_verification/SKILL.md`)
- Per-project "kim" agent that lives in the host project's .claude/ and uses jim under the hood
- Extra context injection into the @jim:coder for project conventions

Relationship to BACK-004 (/jim:arch) is heavy — HOWTOs are themselves a flavor of extension. May make sense to design these together.

Open questions:
- What are the canonical extension points? (Pre-build verification, post-build review, custom spec sections?)
- How does jimconf.toml express them? Path strings, glob patterns, or named skill IDs?
- What's the precedence when both jim and the project define the same extension?

Read jim's current jimconf.toml resolver under skills/conf/ and skills/file/ before brainstorming.
```

## BACK-015 · jim:build can call @jim:architect if plan is missing

**Origin:** Z_STUFF_TO_DO line 15.

**Problem statement.** When `/jim:build` is invoked on a spec that has no `plan.md`, it currently errors / requires the user to run `/jim:plan` first. It would be smoother for `/jim:build` to detect the missing plan and offer to invoke `@jim:architect` inline.

**Next step prompt:**
```text
/jim:brainstorm jim:build auto-plan

When /jim:build is invoked on a spec without a plan.md, it should detect the missing plan and offer to invoke @jim:architect inline rather than erroring out.

Brainstorm:
- Detection: how does /jim:build check whether plan.md exists for the target spec? (Existing jim:file resolver returns NOT_FOUND — see recent commit 903d53e.)
- Prompt UX: ask the user to confirm before spawning the architect, or do it silently and announce?
- Failure modes: spec.md is also missing; spec is approved but lacks acceptance criteria; plan got generated but is empty.
- Does the same pattern apply elsewhere? (/jim:plan without spec → /jim:spec; /jim:review without build → /jim:build.)

Look at skills/build/SKILL.md for the current gating logic and skills/file/scripts/ for the resolver.
```

## BACK-016 · jim:research — direct external vs local research

**Origin:** Z_STUFF_TO_DO line 18.

**Problem statement.** `/jim:research` defaults to investigating the local codebase. When the user wants external research (libraries, prior art, blog posts, GitHub issues, docs), they have to explicitly steer it — and even then it tends to fall back to local grep. Need a clearer signal/mode for external research.

**Next step prompt:**
```text
/jim:spec jim:research external-mode

Refactor: /jim:research defaults to local codebase investigation. External research (libraries, prior art, blog posts, GitHub issues, vendor docs) is the secondary path, but it's often what's actually needed — and even when steered, the researcher tends to fall back to local grep.

Scope:
- An explicit external-research mode (flag? subcommand? auto-detect from prompt language?)
- Tool budget: when external mode is on, allow WebFetch / WebSearch liberally and de-emphasize Grep/Glob.
- Output shape: external research.md should look different — heavier on citations, lighter on file:line refs.

See skills/research/SKILL.md and agents/researcher.md for current behavior. Also relates to BACK-017 (jim:research citation dates).
```

## BACK-017 · jim:research — annotate citations with dates

**Origin:** Z_STUFF_TO_DO line 20.

**Problem statement.** When `/jim:research` cites articles, blog posts, or GitHub issues, it doesn't note when they were published or last updated. A 2023 blog post about a fast-moving library is very different from a 2026 one. Issue status (open/closed) and creation year matter too.

**Next step prompt:**
```text
/jim:spec jim:research citation-dates

Feature: when the researcher cites external sources, it should record:
- For articles/blog posts: publication year (e.g. "2024"), or "undated" if not found.
- For GitHub issues/PRs: status (open/closed/merged) and creation year.
- For vendor docs: version or "as of YYYY-MM-DD" since these update silently.

Why: a 2023 article about a fast-moving library is much less reliable than a 2026 one, and that signal is currently invisible in research.md.

Likely change: update the @jim:researcher agent prompt to require date/status metadata next to every external citation. See agents/researcher.md.
```

## BACK-018 · jim:plan — manual vs automated verification steps

**Origin:** Z_STUFF_TO_DO line 49.

**Problem statement.** `/jim:plan` currently generates verification steps for every task assuming they can be automated. Some verifications genuinely need manual confirmation (e.g. "install third-party app and check it boots", "confirm UI renders correctly in a browser"). `@jim:architect` should mark these as manual; `@jim:coder` should pause and prompt the user for those.

**Next step prompt:**
```text
/jim:brainstorm jim:plan manual-verification

Brainstorm: /jim:plan generates verification steps assuming they can be automated. Some genuinely require manual confirmation:
- "Install third-party library X and check it loads" (library not in test env)
- "Confirm UI renders in browser" (no headless test setup)
- "Verify deployment succeeded in staging" (out-of-band)

Two pieces:
1. @jim:architect needs heuristics to mark a verification as `manual: true` vs `manual: false` when writing plan.md.
2. @jim:coder needs to handle manual verifications differently in the TDD loop: pause, surface the instructions, wait for user confirmation, then proceed.

Open questions: how does the user confirm — typed reply, checkbox edit, or some structured input? What if manual verification fails (rollback the task? mark as blocked?)?

Prior art: skills/plan/, skills/build/, plan.md structure under docs/specs/jim/.
```

## BACK-019 · jim:release skill

**Origin:** Z_STUFF_TO_DO lines 4–5.

**Problem statement.** Releases of jim itself (and downstream apps built with jim) lack a structured prep flow: changelog, release notes, social posts, press release. A `/jim:release` skill could template these and chain them off the merged work in the current milestone.

**Next step prompt:**
```text
/jim:brainstorm jim:release

Brainstorm a /jim:release skill for prepping a release. Likely artifacts:
- CHANGELOG.md entry (grouped by Added/Changed/Fixed/Removed)
- RELEASE_NOTES.md (user-facing, narrative)
- Draft social posts (LinkedIn primarily — see VISION.md's branding goal)
- Optional press release for bigger releases

Open questions:
- What's the input? A milestone? A version tag? A date range of merged PRs?
- Does it read git log + closed specs to assemble the changelog automatically?
- Where do release notes / social drafts live — docs/releases/<version>/?
- How does this interact with /jim:vision and /jim:roadmap (which version is shipping, what's next)?

Prior art: existing CHANGELOG patterns in popular tools (keep-a-changelog spec), and how skills/vision and skills/roadmap structure their docs.
```

## BACK-020 · mkdocs site for jim

**Origin:** Z_STUFF_TO_DO line 3.

**Problem statement.** jim currently has README/CLAUDE.md/VISION.md/ARCHITECTURE.md scattered in the repo. There is no public-facing documentation site. mkdocs (material theme) is a low-friction option. Question is hosting — readthedocs.io vs jamsuite.com vs GitHub Pages.

**Next step prompt:**
```text
/jim:brainstorm jim:docs-site

Brainstorm a public docs site for jim using mkdocs (material theme is the obvious default).

Decisions to make:
- Hosting: readthedocs.io (low effort, branded by RTD) vs jamsuite.com (more control, more work) vs GitHub Pages (free, less polished).
- Information architecture: how do README / ARCHITECTURE.md / VISION.md / skills/*/SKILL.md map to docs pages?
- Build pipeline: GitHub Actions on push to main? Tag-triggered?
- Relationship to BACK-004 (/jim:arch) — HOWTOs likely belong in the docs site too.

Note: jamsuite-logger also needs docs eventually. Whatever pattern we pick should be repeatable.
```

---

# Tier 3: Low Importance / Speculative

Interesting ideas that need more discovery, or that the user has explicitly tagged as "not the point of v2." Keep on the radar; don't prioritize.


## BACK-021 · Support alternate issue backends

**Origin:** Deferred tail of the shipped jim:issue skill. jim:issue shipped local-markdown storage only; alternate/external backends were left Out-of-Scope in spec `017-issue-tracking` behind a future "bridge abstraction" pattern.

**Problem statement.** jim:issue writes to local `docs/issues/*.md`. A future need for a different backend — Linear (via MCP write-through, the original jim:issue idea), or a git-native tracker — should use a bridge/adapter that keeps jim's capture / candidate-batch / insights layer intact rather than replacing it.

**Grounding:** `docs/research/20260718-issue-tracker-comparison.md` compares jim:issue against `steviee/git-issues` and `remenoscodes/git-native-issue`. Bottom line: do **not** adopt an external tool as a runtime backend today — it either breaks jim's bash/no-deps model (git-issues is Go) or reverses spec 017's human-readable-files decision (git-native-issue stores in `refs/`). `git-native-issue`'s `refs/issues` + `Provider-ID` bridge design is the reference architecture **if** offline-distributed multi-dev sync ever becomes in-scope.

**Why Tier 3.** The research recommends this as a watch-list item, not a build — jim is single-developer today (VISION §Non-Goals). Revisit only if distribution/collaboration needs change.

## BACK-022 · jim:refactor — refactor existing specs

**Origin:** Z_STUFF_TO_DO lines 134. Distinct from `/jim:spec type:refactor` (which creates a *new* refactor spec).

**Problem statement.** Brainstorms today route to `/jim:spec type:refactor` when refactoring is implied — but that creates a *new* spec. There is no clean path to refactor an *existing* spec (and its plan, research, and implementation) when requirements evolve or design decisions need revisiting. Currently the user has to manually edit spec.md, then re-run plan, then reconcile drift — without any tracking of what changed and why.

**Proposed scope to interview around:**
- Is this a new skill `/jim:refactor <existing-spec>`, or an extension to `/jim:spec` that takes a spec ID?
- Does it produce a changelog/diff at the top of the existing spec showing what was revised and why?
- How does it handle downstream artifacts — re-run `/jim:plan`? Invalidate `research.md`? Flag `/jim:build` outputs as needing review?
- What's the relationship to BACK-002 (jim:review) (which detects drift between spec and implementation)?

**Next step prompt:**
```text
/jim:brainstorm jim:refactor existing-spec

Today brainstorms route to `/jim:spec type:refactor` when refactoring is implied — but that creates a NEW spec. There is no path to refactor an EXISTING spec (and its downstream plan/research/build artifacts) when requirements evolve.

Brainstorm a refactor-existing-spec capability:
- Is it a new skill `/jim:refactor <spec-id-or-path>`, or an extension of `/jim:spec`?
- How does the user invoke it from a brainstorm that says "the spec needs to change"?
- Does it write a revision history / changelog into the existing spec.md?
- Does it cascade: re-trigger /jim:plan, invalidate research.md, flag previously-built code as stale?
- Relationship to BACK-002 (jim:review) (which detects implementation drift) — same machinery or separate?

Look at existing skills under skills/spec/ and the spec.md structure under docs/specs/jim/ for prior art on how revisions are currently tracked (or not).
```

## BACK-023 · jim:plan namespace conflict with Claude Code's /plan

**Origin:** Z_STUFF_TO_DO line 22.

**Problem statement.** Typing `/plan` in Claude Code triggers Claude Code's built-in plan mode, not jim. Users have to either type the full `/jim:plan` or use Shift+Tab to switch modes. Low friction; mostly a documentation/onboarding issue.

**Next step prompt:**
```text
/jim:brainstorm jim:plan namespace-collision

Low-priority: typing /plan triggers Claude Code's built-in plan mode, not /jim:plan. Users have to type the full namespaced form or use Shift+Tab.

Options to consider:
- Document the workaround prominently in README / onboarding.
- Rename /jim:plan to something less collision-prone (cost: breaks muscle memory and all docs that reference it).
- Add a `jim` alias surface so `/jim plan` works without the colon.
- Accept the friction.

Probably "document the workaround" is the right answer unless Claude Code adds plugin priority controls. Confirm and close.
```

## BACK-024 · jim:selfupdate

**Origin:** Z_STUFF_TO_DO lines 138–140. Speculative but interesting.

**Problem statement.** As frameworks evolve and Claude Code adds features, jim's own specs/plans/research get stale. A `/jim:selfupdate` would walk jim's own specs from 001-meta onward, refresh each spec/research/plan against current best practices, and propose updates. This is jim eating its own dog food at the meta level.

**Next step prompt:**
```text
/jim:brainstorm jim:selfupdate

Speculative: jim's own specs (docs/specs/jim/001-meta onward) drift as Claude Code adds features and frameworks evolve. A /jim:selfupdate would walk each spec in order, refresh spec/research/plan against current state, and propose updates.

Questions to explore:
- What triggers staleness — version of Claude Code? Date threshold? Manual nomination?
- Output: a refresh PR per spec? A consolidated "what changed and why" report? Both?
- How does this interact with BACK-022 (jim:refactor) (refactor existing spec) — is selfupdate just refactor-in-a-loop?
- Risk: cascading rewrites that break the architecture. Need strong gating.

This is v3 territory — see VISION.md / Z_STUFF_TO_DO lines 89–91. Don't build until v2 is solid.
```

## BACK-025 · multi-model support (Codex, Gemini, etc.)

**Origin:** Z_STUFF_TO_DO line 84.

**Problem statement.** jim is Claude-only today. Supporting Codex, Gemini, and other agentic CLIs would broaden reach — but the user has explicitly flagged this as "not the point of v2." Park as a v3 candidate.

**Next step prompt:**
```text
/jim:brainstorm jim:multi-model

Speculative / v3 territory — user has flagged multi-model support as NOT a v2 goal (see VISION.md / Z_STUFF_TO_DO line 78).

If/when this becomes relevant, brainstorm:
- What's the abstraction layer? Skills are markdown — the prompts likely port. The constraints are tool surface (Claude Code's tool names vs Codex's vs Gemini's) and agent model.
- Which models is it actually worth supporting? Codex CLI? Gemini CLI? Aider? Continue?
- Cost: every model-specific quirk doubles the maintenance surface.

Do NOT pick up before v2 ships.
```



## BACK-026 · token compression / context optimization

**Origin:** Z_STUFF_TO_DO line 87.

**Problem statement.** As jim's specs accumulate and conversations get longer, context usage matters. Some optimization (summarizing old specs, lazy-loading skill bodies, more aggressive memory pruning) could help. Speculative — no clear pain point yet.

**Next step prompt:**
```text
/jim:brainstorm jim:context-optimization

Speculative — no acute pain point reported, but flagged in Z_STUFF_TO_DO line 87.

Brainstorm where jim could reduce token spend:
- Lazy-load skill bodies (some skills are large; do all of them need full preamble?)
- Summarize / compress closed specs when old (and surface a pointer rather than full content)
- Memory pruning rules — what's worth keeping forever vs. expiring
- Reduce duplication between spec.md / plan.md / research.md (they overlap)

Measure before optimizing: what does context look like today on a typical session? Is this a real cost, or anticipation?
```
