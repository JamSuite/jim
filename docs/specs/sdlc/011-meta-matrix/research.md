---
spec: "spec.md"
status: Active
date: "2026-05-13"
---

# Research: Promote meta-matrix to a top-level plugin skill with selectable categories

## Anchors

- `.claude/skills/meta-matrix/SKILL.md:1-270` — the fixture being migrated. Sentinel sections: A–T (`:21-109`, bash-invocation), W (`:127-129`, variable-setting SET-assign), U/V/X/Y/Z (`:119-145`, conditional-evaluation single-line + numbered/indented), AA/BB (`:151-171`, lean IF chains), CC–FF (`:185-206`, empty-substitution D8 no-op — fixture-annotated as HISTORICAL/superseded 2026-05-13 at `:173-175,:270`), GG/HH (`:208-230`, canonical post-amendment sentinel form — load-bearing conditional-evaluation rows after the 2026-05-13 spec 011 amendment).
- `skills/build/SKILL.md:10,120` — the **only existing precedent** in jim for `Skill(jim:<name>)` permission + Skill-tool body call. The new dispatcher is the second instance and the first to fan out to multiple siblings.
- `ARCHITECTURE.md:242` — documents the skill-to-skill invocation convention (`Skill(jim:<name>)` for least-privilege; bare `Skill` is the only documented wildcard form). Load-bearing for the dispatcher's `allowed-tools` shape.
- `ARCHITECTURE.md:381` — the line referencing `.claude/skills/meta-matrix/` as the manual regression fixture (inside Substitution Conventions → Wrapper sensitivity bullet). Spec AC requires updating this in-place to `skills/meta-matrix/`.
- `ARCHITECTURE.md:282-354` — Logic-Flow Conventions (sentinel vocabulary + lean paren-free `IF`). The dispatcher's `$ARGUMENTS`-equality branch should follow this form even though it's a string match, not a path-exists gate.
- `ARCHITECTURE.md:240` — `$ARGUMENTS` substitution mechanic. The dispatcher reads `$ARGUMENTS` to select a category; whether the same string flows through `Skill(...)` to a sub-skill's `$ARGUMENTS` is an open question (see Peer Feedback).
- `docs/research/20260512-001-meta-skill-invocation-freshness.md:60-71` — the four invocation paths. Spec scopes paths 1 (`/skill-name` direct) and 4 (Skill tool mid-run); defers paths 2 (`context: fork`) and 3 (`skills:` preload).
- `docs/specs/sdlc/008-directive-vocabulary/spec.md:63-65` — the Regression-matrix AC block that names `.claude/skills/subtest/` → `.claude/skills/meta-matrix/` rename and the ARCHITECTURE.md fixture reference. Spec 014 amends these references in place; 011's behavioral ACs (sentinel migrations, lean IF) are unchanged.
- `.claude-plugin/plugin.json:2` — `"name": "jim"` is the prefix that produces `/jim:meta-matrix-*` autocomplete entries for every top-level `skills/meta-matrix-*/` directory.

## Local Patterns

- **Skill-to-skill invocation:** `Skill(jim:<name>)` permission token in `allowed-tools`, Skill tool call in the body (`skills/build/SKILL.md:10,120`). Every existing usage names one literal skill — no jim skill currently uses a glob or family wildcard.
- **`$ARGUMENTS` and `argument-hint`:** Every user-arg-taking skill carries an `argument-hint` line (e.g., `skills/research/SKILL.md:10`, `skills/meta-test/SKILL.md:10`). The dispatcher should follow suit with `argument-hint: "[bash-invocation | variable-setting | conditional-evaluation | skill-invocation]"`.
- **Sentinel/lean-IF for branches:** `ARCHITECTURE.md:282-354` is now the canonical form for in-prompt branching (`SET <name> = !\`bash …\`` then `IF <name> == "value" THEN`). The dispatcher's category-match logic is LLM-evaluated prose over `$ARGUMENTS` — not a `!`-injection gate — but should still use the lean `IF $ARGUMENTS == "bash-invocation" THEN … ELSE IF … ELSE … ENDIF` shape for consistency with the rest of the plugin.
- **Naming convention:** `ARCHITECTURE.md:233` — `name:` in frontmatter must equal the directory name. Each sub-skill directory must match its `name:` exactly: `skills/meta-matrix-bash-invocation/` ↔ `name: meta-matrix-bash-invocation`.
- **Manual-diagnostic, no automated tests:** `tests/jimconf.sh`, `tests/jimfile.sh`, `tests/metatest.sh` are the project's only test files — they exercise bash scripts via `meta-test/scripts/testlib.sh`. **No existing test framework covers SKILL.md body content**, which is correct: spec 014 § Out of Scope explicitly excludes automated regression. The verification surface is § "Original 011 repro still clears" (AC lines 77-79) — human reads the rendered body for `SUBST_*` sentinels. Documenting this is the relevant DoD item.
- **`${CLAUDE_PLUGIN_ROOT}` vs `${CLAUDE_SKILL_DIR}`:** The dispatcher and sub-skills do not call scripts (`allowed-tools` only declares `Skill(...)` tokens), so neither variable applies. The current fixture's `allowed-tools: Bash(echo *), Bash(bash -c *)` (`:10`) travels with each sub-skill body verbatim because the sentinel rows themselves use `!\`echo …\``.

## Prior Art

Three search rounds. Round 1 (LLM agent benchmarks: Terminal-Bench, SWE-bench, BFCL V4, MCP-Bench, OSWorld, tau-bench, AgentBench, Aider, ToolBench) returned no signal — wrong layer for a single-session preprocessor diagnostic. Round 2 (open-axis search, 2026-05-13) yielded one keeper, Promptfoo, after four drops (prompt-template runtimes, a word-collision on "variable substitution," and a closed-source enterprise tool). Round 3 (axes-targeted search, 2026-05-13) yielded seven keepers across three tiers. Final corpus (Round 2's Promptfoo carried forward into Tier 2):

**Tier 1 (Study Closely):**

- **addyosmani/agent-skills** ([github.com/addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), ~40.9k stars, latest release 2026-04-28). Active Claude Code skill pack with a dispatcher pattern over slash commands — uses **identical `/spec`, `/plan`, `/build` names as jim** (verified 2026-05-13 against the live repo; convergent evolution or shared lineage, worth a beat of PM awareness). Same Claude Code runtime → highest signal-to-noise of any entry. Study the sibling-skill routing model and the "anti-rationalization tables" diagnostic pattern (already validated by `docs/research/20260512-jim-prompt-meta-skill.md`).
- **CommonMark Spec & Spec Runner** ([github.com/commonmark/commonmark-spec](https://github.com/commonmark/commonmark-spec), ~5.1k stars, last release `commonmark 0.31.2` in Jan 2024 — spec is stable, not actively iterating). The canonical fixture-matrix for a markdown preprocessor: each entry an (input, expected output) pair grouped by construct, verified human-readable. **Closest conceptual sibling** — spec 014 is essentially the same shape applied to Claude Code's preprocessor rather than a CommonMark parser. Study the corpus organization and per-construct grouping; ignore the JSON runner output (meta-matrix is human-eye, not automated).
- **Babel Plugin Test Fixtures** ([github.com/babel/babel](https://github.com/babel/babel), ~43.9k stars). Golden-file pattern: recursive scan of `input.js` / `output.js` pairs per plugin. Out of scope for spec 014 (manual diagnostic, no fixture-pair structure) but a forward-compatible template if meta-matrix ever grows a programmatic successor.

**Tier 2 (Study for Specific Patterns):**

- **Promptfoo** ([github.com/promptfoo/promptfoo](https://github.com/promptfoo/promptfoo), ~21.2k stars, latest release 2026-05-08). The closest existing OSS tool at meta-matrix's layer: positioned for evaluating and red-teaming LLM applications. *Open verification flag:* round-2 summary named a specific "raw input assertion" feature (assertions on the rendered prompt **before** inference, not on model output). The 2026-05-13 audit could not corroborate this feature from the README alone — defer to `promptfoo.dev/docs` before citing as load-bearing.
- **Pytest Markers** ([github.com/pytest-dev/pytest](https://github.com/pytest-dev/pytest), ~13.8k stars). Canonical category-filter CLI. The marker-registration discipline (declare valid markers in config; unknown markers warn with the registered list) informs spec AC `:48` — "unknown category lists the valid set and stops" — as an established UX pattern, not a novel invention. Ignore the boolean-expression grammar; spec 014 deliberately scopes to exact-string match.
- **Storybook addons** ([github.com/storybookjs/storybook](https://github.com/storybookjs/storybook), ~89.9k stars). Probe matrix where addons toggle different probe surfaces (a11y, viewport, controls). Useful inspiration for the dispatcher's category-toggle UX; everything UI-specific is the wrong target domain.
- **Autoconf `AC_CHECK_*`**. Philosophical ancestor — tiny self-contained snippets probe "does environment X support feature Y." Small-snippet-per-probe discipline aligns with meta-matrix's sentinel rows; operational distance otherwise large.

**Tier 3 (Reference Only):**

- **marcusgoll/Spec-Flow** ([github.com/marcusgoll/Spec-Flow](https://github.com/marcusgoll/Spec-Flow), ~85 stars, latest release `v11.9.1` on 2026-04-23). Claude Code workflow toolkit. The "Phase Isolation" pattern (sub-tasks point at artifacts on disk rather than re-summarizing) is already validated in jim's earlier research and is the load-bearing relevance. The "delimiter-based returns" claim (round-3 summary's flagged item) is **confirmed** in the live repo as of 2026-05-13 — v11.0.0 introduced structured delimiters (`---COMPLETED---`, `---NEEDS_INPUT---`, `---FAILED---`) for phase-agent communication; v11.1.0 codified them in the `/quick` command architecture.

## Security & Performance

- **Permission scope.** `Skill(jim:meta-matrix-*)` is least-privilege within the family — it cannot reach `/jim:build` or `/jim:plan`. Even if the wildcard syntax is supported (see Peer Feedback), the dispatcher cannot escalate beyond the four sibling probes. The four sub-skills carry their own `allowed-tools: Bash(echo *), Bash(bash -c *)` — bounded to `echo` for sentinel emission only.
- **Context budget.** Today's fixture is one 9KB body. After split: dispatcher (~1KB) + four ~2-3KB sub-skills. When the user invokes `/jim:meta-matrix` (no arg, chain-all), total bytes loaded are roughly equivalent to today. When the user invokes one category, only ~25% of today's body loads — an upside.
- **Post-compaction survival.** Per freshness research, after auto-compaction only the first 5,000 tokens of each re-attached skill survive (combined 25,000-token budget). Splitting reduces per-skill body size well below the per-skill cap → strict improvement over the monolith.
- **`Skill(...)` tool call cost.** Each sub-skill invocation is one tool call. Chain-all = 4 tool calls vs. 0 today. Acceptable for a manual diagnostic; not in any hot loop.

## Recommendations

- **Open Question 1 (sentinel namespacing):** Keep A–FF verbatim. `docs/debug/20260512-skill-bash-substitution-wrappers.md` and spec 011 cite specific sentinel names as evidence — renaming would silently invalidate those references. New rows in `meta-matrix-skill-invocation` should take a category prefix (`SUBST_SKILL_*`) to avoid future collisions.
- **Open Question 2 (chain-all arity):** Sequential. Parallel `Skill(...)` calls could interleave bodies in the rendered transcript; meta-matrix is read top-to-bottom by humans. The cost (4 sequential tool calls instead of 1 batch) is invisible at human latency.
- **Open Question 4 (unknown-category error shape):** Prose. meta-matrix has no downstream automation; structured exit codes serve no consumer.
- **Open Question 3 (where subagent-side probes live):** ~~Naming pattern is forward-compatible — a future `skills/meta-matrix-subagent-invocation/` is the natural fifth category. Spec already notes this.~~ *(Resolved 2026-05-13 subagent-probe amendment — folded into `meta-matrix-skill-invocation` as rows S4 (path 2, `context: fork`) and S5 (path 3, `skills:` preload) with three internal harness files: `agents/meta-matrix-probe.md`, `skills/meta-matrix-fork-probe/SKILL.md`, `skills/meta-matrix-preload-probe/SKILL.md`. See plan Design Decision 11 and PM Disposition addendum below. The hypothetical fifth-category extension is no longer planned; the four-category dispatcher fan-out is final.)*
- **Manual `meta-test` run as the post-migration gate.** `bash skills/meta-test/scripts/run.sh` (mandatory-for-refactor per 011's pattern) covers the bash scripts, not the new SKILL.md bodies. The relevant gate is the human-readable § "Original 011 repro still clears" AC — call this out in the plan's task list explicitly so the coder doesn't skip it.

### Model attribution mechanism (added 2026-05-13)

Investigated how to surface the active Claude Code model into the rendered meta-matrix body so probe results can be attributed to a specific model when comparing runs across models. Verified via claude-code-guide WebFetch / WebSearch pass against the live Claude Code documentation, 2026-05-13.

- **Recommended — system-prompt self-report.** Claude Code injects the active model into the assistant's system prompt at session start: the line `"You are powered by the model named <NAME>. The exact model ID is <ID>"`. A SKILL.md body that instructs the model to echo those two values produces deterministic in-rendered-body attribution with zero infrastructure (no hooks, no env vars, no settings parsing). Reliability is the same as any system-prompt instruction — the model reads its own context rather than guessing. Adopted in spec AC "Model attribution in rendered output."
- **Rejected — env var (`$CLAUDE_MODEL`, `$ANTHROPIC_MODEL` reverse-read).** No documented Claude Code env var exposes the active model to shell injection. `ANTHROPIC_MODEL` is write-only (overrides the model at launch); not exposed back to a running shell.
- **Rejected — `/model` slash command.** Interactive picker only; no programmatic read surface a skill could capture into its body.
- **Rejected — `settings.json` `model` field.** Reflects the configured *default* model, not the active model if the user invoked `/model` mid-session. Stale-value risk defeats the attribution use case.
- **Rejected — status line UI.** Configurable via `/statusline` and shown in the CLI chrome, but not capturable into a SKILL.md rendered body; UI-only.
- **Partially viable, deferred — `SessionStart` hook payload.** Hook event includes a `model` field; a future iteration could write the active model to a `.claude/.active-model` file at session start and have the dispatcher read it. Adds installation infrastructure (a hook) for marginal benefit over self-report. Deferred unless self-report turns out to be unreliable in practice.
- **Reliability follow-up.** The "does the model echo verbatim vs. paraphrase / hallucinate" question is itself probe-shaped and on-theme for `meta-matrix-skill-invocation`. Captured as a follow-up Open Question (a `SUBST_SKILL_MODEL_SELFREPORT` sentinel row) rather than expanded into this amendment — keeps the report-vs-probe boundary clean. See spec § Out of Scope.

## Peer Feedback

**For PM (`@jim:pm`) — spec assumes a wildcard syntax that has no documented precedent in jim.**

Spec AC (`:37`) and Out-of-Scope note (`:116`) both specify `Skill(jim:meta-matrix-*)` as the dispatcher's permission token. Two checks needed:

1. **No existing jim skill uses a prefix wildcard inside the parens.** Every current `Skill(...)` token names one literal skill (`skills/build/SKILL.md:10` → `Skill(jim:arch)`). `ARCHITECTURE.md:242` says "bare `Skill` is a wildcard and is avoided" — implying only bare `Skill` is the documented wildcard form.
2. **Recommended PM decision:** either (a) verify against Claude Code docs that `Skill(jim:meta-matrix-*)` is supported syntax and add a one-line ARCHITECTURE.md note codifying the prefix-wildcard precedent, or (b) tighten the AC to enumerate four explicit tokens (`Skill(jim:meta-matrix-bash-invocation) Skill(jim:meta-matrix-variable-setting) Skill(jim:meta-matrix-conditional-evaluation) Skill(jim:meta-matrix-skill-invocation)`).

The (b) enumeration is least-surprise and matches existing precedent. (a) saves four tokens of `allowed-tools` real estate but introduces a syntax that isn't validated elsewhere in the plugin.

**For PM — `$ARGUMENTS` propagation through `Skill(...)` is undocumented.**

Spec AC (`:61-62`) requires a probe for `$ARGUMENTS` substitution in the skill-invocation category. The freshness research (`docs/research/20260512-001-meta-skill-invocation-freshness.md`) does not state whether the Skill tool can pass arguments to the invoked skill (i.e., whether `Skill(jim:meta-matrix-skill-invocation FOO)` is valid syntax that makes `$ARGUMENTS == "FOO"` inside the sub-skill body). If unsupported, the `$ARGUMENTS` probe must be invoked directly via path 1 (`/jim:meta-matrix-skill-invocation FOO`), not via the dispatcher (path 4). Plan to decide based on a verification step against current Claude Code docs.

**For PM — sub-skill discoverability via top-level autocomplete.**

With five new `skills/meta-matrix*` directories (dispatcher + four sub-skills), all five names appear at the top level under `/jim:` autocomplete unless Claude Code filters by depth. The dispatcher's value prop is the chain-all and unknown-category-detection paths; if a user can also type `/jim:meta-matrix-bash-invocation` directly (path 1) and bypass the dispatcher, that's a real second entry point. Worth a one-line note in the dispatcher's `description` clarifying which entry point is "preferred" vs. "raw" — neither is wrong.

## Alignment

- **VISION.md:** No invalidation. Spec 014 supports Phase 1 self-hosting (jim debugs jim), advances Phase 2 refinement (categorized probes enable iterative convention work), and supports Phase 3 cross-project use (the plugin ships the diagnostic so jim users can probe their own Claude Code installs). The "Not a black box" non-goal is reinforced: meta-matrix is itself a transparency tool.
- **ARCHITECTURE.md:** The dispatcher precedent extends `Plugin Conventions → Skill Invocation` (line 242). The `.claude/skills/meta-matrix/` → `skills/meta-matrix/` move at `Substitution Conventions` (line 372) is already an explicit AC. The lean-IF dispatcher body aligns with `Logic-Flow Conventions` (lines 282-354). No constraint is violated.

## PM Disposition (2026-05-13)

Status flipped from `Needs PM Review` to `Active`. Disposition of the three Peer Feedback items:

1. **`Skill(jim:meta-matrix-*)` wildcard syntax (research `:70-77`).** Resolved by plan Design Decision 1 and Task 13 — four enumerated tokens (`Skill(jim:meta-matrix-bash-invocation)` … `Skill(jim:meta-matrix-skill-invocation)`); spec AC :37 amended in-place. Matches the only existing precedent (`skills/build/SKILL.md:10`).

2. **`$ARGUMENTS` propagation through `Skill(...)` (research `:79-81`).** Resolved by plan Design Decision 2 and Task 14 — the skill-invocation sub-skill's S3 probe (`SUBST_SKILL_ARGS_PROPAGATE`) captures the answer empirically by reading what `$ARGUMENTS` evaluates to when the sub-skill loads via the dispatcher. Direct-invocation probe dropped as redundant. Spec AC :62 amended in-place.

3. **Sub-skill discoverability via top-level autocomplete (research `:83-85`).** PM call: both entry points are legitimate. Direct `/jim:meta-matrix-<category>` is the natural shorthand when the user already knows the category; the dispatcher exists for chain-all and unknown-category detection. No spec/plan-level change needed. Coder folds a one-sentence acknowledgement into the dispatcher SKILL.md **body prose** (not the `description` frontmatter, which surfaces in autocomplete and should stay terse) when authoring Task 6 — e.g., "Direct invocation of any sub-skill (`/jim:meta-matrix-<category>`) bypasses this dispatcher and is supported; the dispatcher exists for chain-all and category-selection ergonomics."

Additionally (PM-side, post-research):

- **Fixture changed under the spec.** Rows GG/HH (canonical post-amendment sentinel form) and the HISTORICAL annotation on rows CC–FF landed via commit `5d143d5` after this research was drafted. Spec AC :54, plan File Manifest + Task 3 + Task 16, and this research's `Anchors` block are amended in-place to capture the new rows. Plan Task 12b added for the missed `docs/research/20260512-skill-allowed-tools-narrowing.md:65` reference. See `~/.claude/plans/jim-pm-please-revisit-docs-specs-jim-01-sunny-marshmallow.md` for the full review.

- **Cross-check audit (2026-05-13, post-research).** A targeted internal/external reference audit (`~/.claude/plans/docs-specs-jim-014-meta-matrix-research-moonlit-meteor.md`) caught four post-research drift items, resolved in-place:
  1. **Spec 012 cross-references** to `.claude/skills/meta-matrix/SKILL.md` (012/spec.md :60, 012/plan.md :89, :290) plus two bare-name occurrences (012/spec.md :66, :71) — added to plan as **Task 12c** alongside the existing 12b precedent.
  2. **Bare `meta-matrix` references in `docs/brainstorms/20260513-directive-vocab-exists-trap.md`** (lines 7, 17, 23, 209) — annotated alongside the two full-path references already in plan Task 11; Task 11 expanded.
  3. **Debug doc footer extension** (`docs/debug/20260512-skill-bash-substitution-wrappers.md` references the pre-011 `subtest` name in body prose; per spec 011 AC :69 precedent, body is preserved verbatim and the footer carries the relocation note) — added to plan as **Task 12d**.
  4. **Spec AC :79 GG/HH addition** — the conditional-evaluation spot-check AC :79 enumerated `U–Z, AA, BB, CC–FF` but did not yet include `GG, HH` (load-bearing post-amendment). Added to plan as **Task 16a** (self-amend, mirrors Tasks 13/14).

  Anchor-only fixes also landed in this research (`:1-270` not `:1-271`; `:21-109` not `:22-109`; `:151-171` not `:152-171`; `:185-206` not `:184-203`; `ARCHITECTURE.md:381` not `:372`; `011/spec.md:63-65` not `:55-57`; Round-3 keeper count seven not six). Plan Task 9 line list trimmed (dropped 284, 433 — those reference the `/meta-matrix` skill name, not the path).

- **External-references verification pass (2026-05-13, follow-up to the cross-check audit).** WebFetched every prior-art URL against the live repo. Findings applied in-place above:
  1. **Star counts corrected across all seven keepers** — every original count came from the search agent and was off (some by ~10×): addyosmani 3.8k→40.9k, Promptfoo 9.2k→21.2k, CommonMark 6.1k→5.1k, pytest 11k→13.8k, Storybook 83k→89.9k, Babel 44k→43.9k, Spec-Flow 950→85. Lesson: trust the agent for keeper *identification* but verify all numeric claims.
  2. **CommonMark "ongoing" was misleading** — last release was Jan 2024 (`commonmark 0.31.2`); the spec is stable rather than actively iterating. Body amended.
  3. **Spec-Flow's "delimiter-based returns" claim is confirmed** — original framing said "not corroborated and should be verified before citing"; verified present in v11.0.0+ (`---COMPLETED---`, `---NEEDS_INPUT---`, `---FAILED---`). Status flipped from "should verify" to "confirmed."
  4. **addyosmani `/spec` `/plan` `/build` convergence is confirmed** — the live repo has those three slash commands as primary entry points, as the round-3 summary claimed.
  5. **Promptfoo "raw input assertion" feature remains unverified** — the README does not document it; the original verification flag is preserved with a pointer to `promptfoo.dev/docs` for deeper confirmation.
  6. **Flagged-drops paragraph removed entirely.** Per-URL verification showed both entries exist (PULSE at `HKati/pulse-release-gates-0.1` — original URL was missing a `-0.1` suffix; AINL at `sbhooley/ainativelang` as-cited). Both are small/niche (0 and 87 stars) with project-specific vocabulary that doesn't match recognizable industry patterns; not strong prior art. Per user direction, dropped from the corpus rather than re-tiered.

- **Subagent-probe amendment (2026-05-13).** Resolved Open Question 3 ("where do subagent-side probes live") by folding paths 2 (`context: fork`) and 3 (`skills:` preload) into `skills/meta-matrix-skill-invocation/SKILL.md` as rows S4 and S5, backed by three new internal harness files. Triggering question from the user: "the deferral is a bummer — that's one thing we're really curious about. Can we fold subagent side probes into existing meta-matrix-skill-invocation?" Feasibility check confirmed: jim already has agent-spawning precedent (`agents/researcher.md:40` for `tools: Agent(name)`, `agents/meta.md:37-38` for `skills:` preload), and the `context: fork` mechanism is documented in the 001-freshness research and ARCHITECTURE.md:241. The harness shape is one new probe agent (`agents/meta-matrix-probe.md` with `skills: [meta-matrix-preload-probe]` and `model: sonnet`) plus two tiny helper skills (`skills/meta-matrix-fork-probe/`, `skills/meta-matrix-preload-probe/`), each marked as internal harness in its `description` so `/jim:` autocomplete clearly distinguishes them from user-facing categories. The skill-invocation sub-skill's `allowed-tools` expands to add `Skill(jim:meta-matrix-fork-probe)` and `Agent(meta-matrix-probe)`. The dispatcher remains at four categories — the harness skills are invoked transitively by skill-invocation, not as standalone fan-out targets. Captured in plan as **Design Decision 11** and **Tasks 5a–5d**; spec ACs amended in-place under "New skill-invocation category" and "Original 011 repro still clears." The empirical findings for S4 (path-2 fork substitution) and S5 (path-3 preload substitution) are open until the next manual matrix rerun records them in plan Verification Log — both are interesting either way (any of bare-string, literal, or harness-failed readings reveals platform behavior). Once collected, the result is cross-referenced into `docs/research/20260512-001-meta-skill-invocation-freshness.md` mirroring the existing S3 finding pattern.
