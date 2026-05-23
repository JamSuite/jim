# BACKLOG

# Tier 1: High Importance

Items here close obvious gaps in the existing SDLC loop, fix known bugs that create friction every session, or unblock decisions the user has been wanting for a while. Address before Tier 2.



## HANDOFF BETWEEN SPEC AND PLAN

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

## Task 0001: jim:issue

**Origin:** Z_STUFF_TO_DO line 116 (build-time bugs have nowhere to go), plus the fact that `Z_STUFF_TO_DO` and `BACKLOG.md` are themselves acting as unstructured issue trackers today.

**Problem statement.** Bugs and follow-ups noticed during the SDLC loop have no home. Today they end up in ad-hoc files (`Z_STUFF_TO_DO`), in `BACKLOG.md`, or lost. A `/jim:issue` skill would provide templates for BUG, FEATURE, and REFACTOR (mirroring `/jim:spec` types) and, optionally, write through to Linear via the Linear MCP when available. Issues are *mini-specs* — placeholders for future work, not full specs.

Unblocks [[task-0012-jim-build-outside-scope-bug-tracking]], which depends on the issue surface existing.

**Next step prompt:**
```text
/jim:brainstorm jim:issue skill/command

Context to ground the brainstorm:
- Today there is no home for bugs and follow-ups noticed during the SDLC loop. They end up in `Z_STUFF_TO_DO` (an unstructured TODO file at repo root) or `BACKLOG.md` — both are acting as ad-hoc issue trackers right now. This skill is meant to give that work a real home.
- This skill unblocks [[task-0012-jim-build-outside-scope-bug-tracking]]: the @jim:coder needs a way to file follow-up bugs it spots during /jim:build. Design the issue surface with that caller in mind — what does the coder need to be able to call?
- Issues are mini-specs / placeholders. A critical lifecycle question to brainstorm: **how does an issue get promoted to a real `/jim:spec`?** When the user is ready to work on a parked BUG/FEATURE/REFACTOR issue, what's the path? Does `/jim:spec` take an `--from-issue <id>` flag? Does `/jim:issue` have a `promote` subcommand? Without this bridge, `/jim:issue` becomes a parallel todo system rather than a real on-ramp to the SDLC loop.

Now the original idea capture:

For this `jim:issue` skill/command let's capture some ideas.
We want issue templates for BUG, FEATURE, REFACTOR (same as the types we use for `/jim:spec` specifications).

Issue template for **bug** should be: short problem statement (1-2 sentence), STEPS TO REPRODUCE, and WHAT I SEE (RESULT), EXPECTED. Plus any extra detail like environment settings (python version, operating system, web browser, for example).

Issue template for **feature** should be: short description, some acceptance criteria, what else? open questions?

Issue template for **refactor** should be: problem statement, example, proposed solution, file(s) affected. <-- Issues are like mini specs. We are just putting issues aside to outline future work we need to do.

NOW ... we want to have some fun! If we have linear mcp installed, we want jim to create issues using our templates.

How do we know if we have linear mcp installed? No clue... maybe we should have a jimconf setting `issue_storage="linear"` or `issue_storage="docs/jim/issues"` (default). If we're storing issues locally, need a way to organize them with numbers, maybe priority tiers, maybe functional groups. May need to investigate any prior-art GitHub-repository-based issue tracking systems (they must exist! how do they organize issues inside a repository?).

If we are using linear mcp then we want `jim:issue` to interface with linear for issues. `jim:issue` should be able to create issue, triage issue (what would that do?), delete issue, move issue (change priority)? What can linear mcp do with issues? What would `jim:issue` need to be able to do to align with linear mcp? Don't want to recreate linear mcp with `jim:issue` — just want a thin wrapper so that the issues in linear align with jim's agentic SDLC process and conventions.
```

## Task 0002: jim:howtos

**Status:** Brainstorm complete, **ready for `/jim:spec`**. Lowest effort-to-ship of any Tier 1 task. The brainstorm (`docs/brainstorms/20260512-jim-howtos.md`) is comprehensive: problem statement, 9-project prior-art survey, candidate HOWTOs extracted from jim's own ARCHITECTURE.md, three-template proposal, proactive-suggestion heuristics, non-goals locked, and a "Preliminary Answers" section that resolves every Open Question with a working recommendation. The brainstorm's own "Next Steps" explicitly recommends SPEC and provides this prompt:

**Next step prompt:**
```text
/jim:spec jim:howtos

New feature: a `/jim:howtos` command for managing topic-specific technical guides ("HOWTOs") that decompose `ARCHITECTURE.md` into a modular wiki. Default location `docs/howtos/`, configurable via `jimconf.toml` (`howtos_path`). Ships with a standard HOWTO template.
Origin: `docs/brainstorms/20260512-jim-howtos.md` (see for prior art, candidate HOWTOs, heuristics, and the proposed ARCHITECTURE.md ↔ HOWTO boundary rule).
Prior-art: docs/prior-art/howtos/tauri-env-build.md

Scope decisions to interview around:
- Subcommands for `/jim:howtos` (likely `create`, `list`, `update`; possibly `deprecate`).
- HOWTO file naming (slug vs. date-prefixed) and status lifecycle.
- **Inclusion modes** (per Kiro prior art): always-loaded / glob-conditional via `paths:` / manual `@` reference / description-matched auto. Which modes ship in v1?
- Body template — the draft in this brainstorm vs. addyosmani's *Overview → When to Use → Process → Rationalizations → Red Flags → Verification* shape. compare with @docs/prior-art/howtos/tauri-env-build.md
- Which skills get proactive HOWTO suggestion logic in v1 (the brainstorm proposes /jim:plan and /jim:research as highest-signal).
- `/jim:arch` integration: does the architect link HOWTOs, prune stale ones, both?
- should jim:arch offer to make a HOWTO and get confirmation from the user? should jim:plan skill include some detail about when to create a HOWTO ?
- what about jim:research or jim:brainstorm? should those know when and when not to suggest creating a HOWTO?
- when should those skills suggest creating a HOWTO? When should they not suggest creating a HOWTO?

Non-goals (already decided — see brainstorm): no `@jim:librarian` agent; no `llms.txt` integration; no automated staleness detection; no central INDEX.md.
- Whether this spec also ships ~3–5 example HOWTOs extracted from jim's own ARCHITECTURE.md (see "Immediate Candidates" table in the brainstorm) — proves the pattern works on jim itself.

Suggestion: link the brainstorm via the spec's `origin:` field so the spec stays traceable to this thinking.
```

## Task 0003: jim:review

**Origin:** Z_STUFF_TO_DO lines 14, 98–101, 112. Mentioned three separate times, which suggests the gap is felt repeatedly. Closes the `/jim:spec → /jim:plan → /jim:build → ???` loop.

**Problem statement.** After `/jim:build` finishes, nothing systematically verifies that what was implemented matches the spec and the plan. Acceptance-criteria checkboxes in `spec.md` are left empty — there is no agent whose job is to tick them. Drift between plan and implementation goes unnoticed unless the user catches it by eye.

**Proposed scope to interview around:**
- What does `/jim:review` actually compare? (spec ↔ code, plan ↔ code, both?)
- Does it produce a `review.md` artifact alongside `spec.md` / `plan.md` / `research.md`?
- Does it mark acceptance criteria checkboxes as complete in `spec.md` directly, or propose marks for the user to confirm?
- How does it report drift (deviated from plan but still meets spec; meets plan but spec changed; meets neither)?
- Does it run automatically after `/jim:build` completes, or only on explicit invocation?
- Does it have authority to *file* follow-up issues (depends on Task 0001 `jim:issue`) for drift it can't reconcile?

**Next step prompt:**
```text
/jim:brainstorm jim:review

After `/jim:build` finishes, nothing closes the loop against `spec.md` and `plan.md`. Acceptance-criteria checkboxes in spec.md stay empty. Drift between plan and implementation goes unnoticed.

Brainstorm a `/jim:review` skill (and likely a `@jim:reviewer` agent) that:
- compares the implemented code against the spec's acceptance criteria and the plan's task list
- marks AC checkboxes as complete (or proposes marks for user confirmation)
- reports drift: implementation deviated from plan, or plan diverged from spec, or both
- produces `review.md` alongside spec.md / plan.md / research.md

Open questions to explore: when does it run (auto after build, or on demand)? Does it have authority to file follow-up issues via [[task-0001-jim-issue]]? How does it differ from `/jim:debug` (which diagnoses failures) and from human code review?

Prior art to check: jim's existing skill patterns under `skills/`, the @jim:coder TDD loop in skills/build/, and how spec.md's "Acceptance Criteria" section is structured today.
```

## Task 0004: jim:research absolute paths bug

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

## Task 0005: jim:debug — include applied resolution and gate the "chosen recommendation"

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

Open question for the interview: should /jim:debug actively offer a /jim:build handoff after confirmation, or stay strictly diagnostic and let the user dispatch the build separately? The user has expressed appetite for the handoff path.

Prior art: skills/debug/SKILL.md and the debug reports under docs/debug/ (e.g. docs/debug/20260510-claude-code-bash-injection-permissions.md).
```


## Task 0006: VISION.md — vision statement + competitive landscape

**Origin:** Z_STUFF_TO_DO line 28, the "what is the intention?" section (lines 70–91), plus user request 2026-05-13 to position jim against `addyosmani/agent-skills` and `garrytan/gstack`.

**Problem statement.** VISION.md is missing two things:

1. **A clear, concise vision statement.** The "what is the intention?" notes in `Z_STUFF_TO_DO` already capture the raw material: built jim to support master's studies and LinkedIn branding; not aiming for mass-market popularity; want it to work for me and a small team; openness to small-team adoption for credibility.

2. **A competitive landscape / prior-art section.** Two reference projects worth positioning against:
   - **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — Addy Osmani's curated collection of agent skills. Same primitive (Claude Code skills) but a different shape (curated library of individual skills) vs. jim's shape (an opinionated SDLC workflow built from skills + agents). Already cited as prior art for HOWTO body templates in Task 0002.
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

Confirm with me before writing. If WebFetch fails on either repo URL, stop and ask me to paste the README content.
```

---

# Tier 2: Medium Importance

Real improvements to the SDLC loop, but not blocking daily work. Pick up after Tier 1 lands. **Task 0017 (jim:security) is the top priority in this tier** — promoted from Tier 3 because security review of LLM-generated code is a known engineering concern, not speculation.

## Task 0017: jim:security agent

**Origin:** Z_STUFF_TO_DO line 96. Promoted to top of Tier 2 on 2026-05-13 — see rationale below.

**Problem statement.** Code that an LLM writes — whether jim's own bash scripts under `skills/*/scripts/` or app code generated by `@jim:coder` for downstream projects — has demonstrated weak spots in security-sensitive patterns: command injection, SQL injection, secret leakage, insecure defaults, missing authz checks. jim already takes this seriously at the script layer (see CLAUDE.md's "Never `source` or `eval` user-supplied data" and the recent debug report at `docs/debug/20260510-claude-code-bash-injection-permissions.md`), but there's no systematic review skill.

**Why this is Tier 2 (not Tier 3):**
- Every app built with jim ships LLM-written code — security review is genuinely load-bearing, not nice-to-have.
- Concrete prior incident already on record (the bash-injection debug report).
- Existing patterns (OWASP top 10, secret regex scanning, dep CVE checks) make this buildable today; it's not R&D.

**Why not Tier 1:** No active daily friction reported, and `/jim:review` (Task 0003) should ship first to define the "review skill" pattern that `/jim:security` likely extends.

**Proposed scope to interview around:**
- Standalone `/jim:security` skill vs. a *mode* of [[task-0003-jim-review]] (`/jim:review --security`).
- Relationship to Claude Code's built-in `/security-review` skill — wrap, replace, or complement? (jim's value-add: structured report artifact, integration with the rest of the SDLC loop, project-specific config via jimconf.)
- Scope: full repo, current branch diff vs. main, or staged changes only?
- Check surface: OWASP top 10 patterns, secret leakage (regex + entropy), dependency CVEs (where a manifest is available), insecure defaults, missing authz.
- Output: `security-review.md` artifact alongside the spec/plan/research/review chain? Or inline annotations only?
- Does it have authority to file issues via [[task-0001-jim-issue]] for findings that aren't blocking?

**Next step prompt:**
```text
/jim:brainstorm jim:security

Brainstorm a /jim:security skill (and likely @jim:security-reviewer agent) for security review of LLM-generated code. This is Tier 2 priority — see BACKLOG.md for rationale.

Should ship AFTER [[task-0003-jim-review]] so the "review skill" pattern is established first. Open question: is /jim:security a standalone skill or a mode of /jim:review?

Check surface to brainstorm:
- OWASP top 10 patterns (injection, XSS, broken auth, deserialization, etc.)
- Secret leakage in code or commits (regex + entropy detection)
- Dependency CVEs (where manifest is available — package.json, pyproject.toml, Cargo.toml)
- Insecure defaults (debug=True in prod paths, permissive CORS, etc.)
- Missing authz/authn checks on sensitive endpoints

Open questions:
- Relationship to Claude Code's built-in /security-review skill — wrap, replace, or complement? jim's value-add is structured report artifact + integration with the SDLC loop + project-specific config.
- Scope: full repo, current branch diff vs main, or staged changes only?
- Output: a security-review.md artifact alongside spec.md / plan.md / research.md / review.md? Inline annotations? Both?
- Authority to file follow-up issues via [[task-0001-jim-issue]] for non-blocking findings?
- How does it know what's "sensitive" — heuristics, jimconf config, or per-spec metadata?

Prior context worth reading before brainstorming:
- CLAUDE.md "Bash scripts" section — jim already enforces security rules at the script layer.
- docs/debug/20260510-claude-code-bash-injection-permissions.md — concrete prior incident.
- skills/security-review/ if Claude Code's built-in surface lives there (check).
```
## Task 0019: extensibility — extension points and per-project agents (kim)

**Origin:** Z_STUFF_TO_DO lines 86, 122–128.

**Problem statement.** The user is interested in extending jim's agents with project-specific context — e.g. a downstream "kim" agent that lives in a project's `.claude/` folder and is custom-tailored to that project but uses jim under the hood. Also: extension points in jim's skills where config can swap in project-specific behavior (e.g. `build_verification_skill=.claude/skills/my_build_verification/SKILL.md`). Overlaps significantly with Task 0002 `jim:howtos`.

**Next step prompt:**
```text
/jim:brainstorm jim:extensibility

User has expressed appetite for jim being extensible at specific seams (Z_STUFF_TO_DO lines 86, 122–128):
- Config params for skills that name extension-point skills (e.g. `build_verification_skill = .claude/skills/my_build_verification/SKILL.md`)
- Per-project "kim" agent that lives in the host project's .claude/ and uses jim under the hood
- Extra context injection into the @jim:coder for project conventions

Relationship to [[task-0002-jim-howtos]] is heavy — HOWTOs are themselves a flavor of extension. May make sense to design these together.

Open questions:
- What are the canonical extension points? (Pre-build verification, post-build review, custom spec sections?)
- How does jimconf.toml express them? Path strings, glob patterns, or named skill IDs?
- What's the precedence when both jim and the project define the same extension?

Read jim's current jimconf.toml resolver under skills/conf/ and skills/file/ before brainstorming.
```

## Task 0008: jim:build can call @jim:architect if plan is missing

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

## Task 0009: jim:research — direct external vs local research

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

See skills/research/SKILL.md and agents/researcher.md for current behavior. Also relates to [[task-0010-jim-research-article-dates]].
```

## Task 0010: jim:research — annotate citations with dates

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

## Task 0011: jim:plan — manual vs automated verification steps

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

## Task 0012: jim:build — file follow-up issues for outside-scope bugs

**Origin:** Z_STUFF_TO_DO line 116. Depends on Task 0001 `jim:issue`.

**Problem statement.** During `/jim:build`, the coder sometimes notices real bugs in code outside the current task's scope. Today these get either ignored or fixed silently (scope creep). Better: the coder files a tracked issue (via `jim:issue`, [[task-0001-jim-issue]]) and continues on-scope.

**Next step prompt:**
```text
/jim:brainstorm jim:build outside-scope-bug-tracking

Depends on Task 0001 (/jim:issue) — design that first.

During /jim:build, the @jim:coder occasionally spots real bugs in code outside the current task's scope. Today: ignored, or fixed silently as scope creep. Neither is great.

Brainstorm a third option: coder files a tracked issue via [[task-0001-jim-issue]] (BUG template) without leaving the build loop, then continues on-scope.

Questions:
- Does the coder ask the user before filing, or file silently and surface a summary at end of build?
- How does the coder describe the bug — short snippet + file:line + reproduction guess, then leave full diagnosis to /jim:debug later?
- Threshold: every code smell becomes an issue? Or only "this is definitely wrong and affects correctness"?

Look at skills/build/SKILL.md and agents/coder.md for where the hook would go.
```

## Task 0013: jim:release skill

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

## Task 0014: mkdocs site for jim

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
- Relationship to [[task-0002-jim-howtos]] — HOWTOs likely belong in the docs site too.

Note: jamsuite-logger also needs docs eventually. Whatever pattern we pick should be repeatable.
```

---

# Tier 3: Low Importance / Speculative

Interesting ideas that need more discovery, or that the user has explicitly tagged as "not the point of v2." Keep on the radar; don't prioritize.


## Task 0006: jim:refactor — refactor existing specs

**Origin:** Z_STUFF_TO_DO lines 134. Distinct from `/jim:spec type:refactor` (which creates a *new* refactor spec).

**Problem statement.** Brainstorms today route to `/jim:spec type:refactor` when refactoring is implied — but that creates a *new* spec. There is no clean path to refactor an *existing* spec (and its plan, research, and implementation) when requirements evolve or design decisions need revisiting. Currently the user has to manually edit spec.md, then re-run plan, then reconcile drift — without any tracking of what changed and why.

**Proposed scope to interview around:**
- Is this a new skill `/jim:refactor <existing-spec>`, or an extension to `/jim:spec` that takes a spec ID?
- Does it produce a changelog/diff at the top of the existing spec showing what was revised and why?
- How does it handle downstream artifacts — re-run `/jim:plan`? Invalidate `research.md`? Flag `/jim:build` outputs as needing review?
- What's the relationship to [[task-0003-jim-review]] (which detects drift between spec and implementation)?

**Next step prompt:**
```text
/jim:brainstorm jim:refactor existing-spec

Today brainstorms route to `/jim:spec type:refactor` when refactoring is implied — but that creates a NEW spec. There is no path to refactor an EXISTING spec (and its downstream plan/research/build artifacts) when requirements evolve.

Brainstorm a refactor-existing-spec capability:
- Is it a new skill `/jim:refactor <spec-id-or-path>`, or an extension of `/jim:spec`?
- How does the user invoke it from a brainstorm that says "the spec needs to change"?
- Does it write a revision history / changelog into the existing spec.md?
- Does it cascade: re-trigger /jim:plan, invalidate research.md, flag previously-built code as stale?
- Relationship to [[task-0003-jim-review]] (which detects implementation drift) — same machinery or separate?

Look at existing skills under skills/spec/ and the spec.md structure under docs/specs/jim/ for prior art on how revisions are currently tracked (or not).
```

## Task 0015: jim:plan namespace conflict with Claude Code's /plan

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

## Task 0016: jim:selfupdate

**Origin:** Z_STUFF_TO_DO lines 138–140. Speculative but interesting.

**Problem statement.** As frameworks evolve and Claude Code adds features, jim's own specs/plans/research get stale. A `/jim:selfupdate` would walk jim's own specs from 001-meta onward, refresh each spec/research/plan against current best practices, and propose updates. This is jim eating its own dog food at the meta level.

**Next step prompt:**
```text
/jim:brainstorm jim:selfupdate

Speculative: jim's own specs (docs/specs/jim/001-meta onward) drift as Claude Code adds features and frameworks evolve. A /jim:selfupdate would walk each spec in order, refresh spec/research/plan against current state, and propose updates.

Questions to explore:
- What triggers staleness — version of Claude Code? Date threshold? Manual nomination?
- Output: a refresh PR per spec? A consolidated "what changed and why" report? Both?
- How does this interact with [[task-0006-jim-refactor]] (refactor existing spec) — is selfupdate just refactor-in-a-loop?
- Risk: cascading rewrites that break the architecture. Need strong gating.

This is v3 territory — see VISION.md / Z_STUFF_TO_DO lines 89–91. Don't build until v2 is solid.
```

## Task 0018: multi-model support (Codex, Gemini, etc.)

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



## Task 0020: token compression / context optimization

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
