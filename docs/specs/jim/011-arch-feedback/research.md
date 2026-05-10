---
spec: "docs/specs/jim/011-arch-feedback/spec.md"
status: Needs Architect Review
date: "2026-05-10"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Post-build ARCHITECTURE.md feedback loop

## Anchors

**`skills/build/SKILL.md`** — insertion point for the new arch-feedback step:

- Step 5 header at line 99. Pre-completion gate block at lines 103–113 (the existing `IF EXISTS THEN DO ... ELSE ... END IF`). The new arch step inserts **after line 113** (after `END IF`) and **before line 114** (the existing "Report results" step).
- Step 5's existing structure post-PR-#8: pre-completion gate (1) → report (2) → STOP (3). New arch step lands as the new step 2; report and STOP shift to 3 and 4.

**`skills/arch/SKILL.md`** — modification point for `auto_arch_feedback`:

- Step 6 header at line 78 ("### 6. Present and stop"). User-confirmation prompt at line 82 ("Ask: 'Does this look accurate? Any sections to refine?'"). Step body ends line 84.
- The `auto_arch_feedback` read happens before the user-prompt branch. When `"true"`, skip the prompt and apply via Edit (already the verb the skill uses for differential updates). When `"false"`, run the existing flow unchanged.

**`skills/conf/scripts/jimconf.sh`** — three extension points:

- `KEYS` array, line 42: ten current keys (`specs`, `architecture`, `vision`, `roadmap`, `brainstorms`, `debug`, `pre_commit`, `pre_completion`, `require_pre_commit`, `require_pre_completion`). Append `auto_arch_feedback`.
- `default_for()`, lines 48–62: append `auto_arch_feedback) echo "false" ;;` arm before the `*) return 1 ;;` wildcard.
- `resolve()` prefix-dispatch block, lines 92–96: currently dispatches `require_*` → CLI key as TOML key (no `_path`). The new key is also a flag — extend the condition to recognize `auto_*` alongside `require_*`. **Critical: failure to extend means `resolve()` looks up `auto_arch_feedback_path` in TOML, returns empty, falls through to default.** Silent miss.

**`tests/jimconf.sh`** — five hardcoded-count cases plus four-template flag cases:

- `case_no_config_returns_defaults` (lines 39–58), `case_full_config_returns_overrides` (62–84), `case_list_outputs_all_keys` (106–124, hardcoded `"10"` at line 113), `case_keys_outputs_valid_keys` (127–133, hardcoded expected output at line 131), `case_malformed_lines_are_ignored` (154–170, hardcoded `"10"` at line 169). All move from 10 to 11.
- Templates for the new cases: `case_require_pre_commit_default`/`_overridden` (lines 237–250), `case_require_pre_completion_default`/`_overridden` (lines 253–266). Mirror these for `case_auto_arch_feedback_default` / `case_auto_arch_feedback_overridden`.

**`jimconf.toml.example`** — new key lands after line 40 (after the existing `require_pre_completion` line). The require block (lines 35–40) sets the comment style: 2–4 line block comment + key.

**`ARCHITECTURE.md`** Scripting Layer entry — line 261. Currently reads "ten configurable keys: eight paths … and two enforcement flags." Becomes "eleven configurable keys" with `auto_arch_feedback` added to the inline list. Convention sentence ("Path keys append `_path` ...; flag keys map directly...") needs the prefix dispatch extended in mention to recognize `auto_*` alongside `require_*`.

## Local Patterns

**BASIC `IF EXISTS THEN DO ... ELSE ... END IF`.** The arch step uses the canonical idiom from ARCHITECTURE.md §Logic-Flow Conventions (lines 279–322). Multi-step body wrapped in fenced ` ```text ` per the rendering rule. The new step's THEN body has 1 numbered action ("Invoke `/jim:arch` via the Skill tool"); ELSE branch is implicit (skip silently). Well within the `~3-step` budget at line 320.

**`!`-injection eager substitution.** ARCHITECTURE.md §Substitution Conventions documents the pattern. The arch step's existence check uses `!`-injection of the resolved architecture path: `IF (!\`bash …jimfile.sh get architecture\`) EXISTS THEN`. Inputs are stable at slash-command load (config-resolved path), so eager substitution is correct.

**Test framework conventions** (per `tests/jimconf.sh` header): each case starts with `# AC: …` comment; `fixture <name>.toml '<content>'` writes a temp TOML; `empty_dir <label>` creates a temp dir with no config; `run <args…>` captures stdout/stderr/rc into `$OUT`/`$ERR`/`$RC`; assertions are `assert_eq`/`assert_exit`/`assert_match`/`assert_nonempty`. No registration array — discovery by `case_*` function-name convention. **At least one existing test file is identified** — `tests/jimconf.sh` itself is the template for the new cases.

## Security & Performance

**Auto-apply bypasses human review.** When `auto_arch_feedback = "true"`, `/jim:arch` writes the proposed update directly. The architecture document is the one downstream skills treat as locked-constraint ground truth — a bad arch update can propagate into bad spec/plan/research outputs. The opt-in nature mitigates: default is `"false"` (review preserved); users explicitly accept the risk by setting `"true"`. Worth a Design Decision in the plan that names this trade-off.

**Full codebase scan on every build.** `/jim:arch` performs a complete codebase Glob/Grep (per its skill body, step 4). The arch-feedback step fires after every `/jim:build` completion gate, so this scan runs on every build. Acceptable for now (per spec Out of Scope: deferred to `/jim:backlog` for delta-only optimization). Not a blocker, but the cost compounds for projects with frequent small builds.

**No new attack surface.** The flag is data, not code. The resolver never sources the file. `auto_arch_feedback` is just a string compared to the literal `"true"`.

## Recommendations

**Skill invocation mechanism.** The plan needs to specify exactly how `/jim:build` invokes `/jim:arch`. Three options:

1. **Built-in `Skill` tool.** Build skill body instructs the LLM: "Invoke the `/jim:arch` skill via the Skill tool." Claude Code loads arch's SKILL.md into the session; the LLM (currently @coder) follows arch's body. Cleanest in terms of mechanism reuse, but sets a new convention in jim (see Peer Feedback).
2. **Inline instruction.** Build skill body says: "Perform a differential update of ARCHITECTURE.md (codebase scan → diff against existing doc → apply via Edit; honor `auto_arch_feedback`)." Self-contained but duplicates `/jim:arch` logic. Drift risk over time.
3. **User handoff.** Build skill ends with: "ARCHITECTURE.md exists. Run `/jim:arch` to refresh." User invokes manually. Maximum domain separation; defeats the "automatic feedback loop" intent.

The architect should choose 1 (per spec design intent) and document the new convention.

**`resolve()` prefix dispatch extension.** Two shapes for the same effect:

- **Disjunction:** `if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then`. Minimal change; explicit list of flag prefixes.
- **Generalized predicate:** maintain a list of flag-prefix variables (`FLAG_PREFIXES=(require_ auto_)`); loop. Future-proof but over-engineered for two prefixes.

Recommend disjunction. Re-evaluate when a third prefix lands.

## Peer Feedback

**For Architect — skill-to-skill invocation: confirm or replace.** The fork's commit `9039461` (the original arch-feedback implementation) used English prose: *"Check if ARCHITECTURE.md exists at the project root. If it does, invoke `/jim:arch` to run a differential update."* That's it — no Skill-tool reference, no special syntax. The LLM running `/jim:build` reads the prose and uses the Skill tool to load `/jim:arch`. The pattern was working in the fork; it's a normal use of Claude Code's built-in tool.

What's missing is upstream documentation: no current upstream jim skill explicitly invokes another, and ARCHITECTURE.md's Subagent Delegation section (lines 248–252) only documents the `Agent()` syntax for agent-level subagent spawning. The plan should:

1. Confirm option 1 (Skill-tool invocation via prose, fork-style) — or propose a cleaner alternative if one exists.
2. Add a brief Plugin Convention entry to ARCHITECTURE.md documenting skill-to-skill invocation as a valid pattern, so future ports don't re-derive the question.
3. Note that this pattern is enabled by jim's `agent:` frontmatter being documentation rather than runtime routing (already stated at line 239) — the same agent (whoever invoked the parent skill) executes the invoked skill's body.

**For Architect — soft domain-boundary tension.** ARCHITECTURE.md's Agents section (lines 144–148) frames "agents do not cross domain boundaries — coder does not modify specs" as a soft principle. When `/jim:build` (coder's skill) invokes `/jim:arch` (architect's skill), @coder ends up running arch's prose. The invocation is non-blocking from a runtime perspective — line 239 already states that `agent:` is documentation, not enforcement. One sentence in the plan's Constitution Check should be enough to cover this: the boundary is a guideline; the auto-feedback feature is the whole point of the spec.

## Alignment

VISION.md ("agentic SDLC workflow grounded in research, spec-driven planning, and test-first implementation to maintain architectural consistency") — this spec directly serves the architectural-consistency goal by closing the silent-drift gap. Aligned.

ARCHITECTURE.md — BASIC idiom honored (AC line 47), eager `!`-injection at slash-command load honored (AC line 48), skills-always-call-jimfile-not-jimconf rule unchanged (no new direct `jimconf.sh` calls), SKILL.md ≤ 500 lines preserved (build grows by ~10 lines, arch grows by ~5 lines). Two new conventions need to be added (skill-to-skill invocation, `auto_*` flag prefix); both flagged for architect in Peer Feedback above.
