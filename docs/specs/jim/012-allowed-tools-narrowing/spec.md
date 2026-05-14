---
title: "Narrow `allowed-tools` in all SKILL.md frontmatter"
type: refactor
group: "jim"
id: "012"
status: approved
origin:
  - docs/research/20260512-skill-allowed-tools-narrowing.md
---

# 012 Narrow `allowed-tools` in all SKILL.md frontmatter

## Overview
Replace wildcard `Bash(bash *)` permissions across jim's skills with prefix-narrowed `Bash(...)` clauses matching the exact script paths each skill injects or runs, so frontmatter documents the bash surface explicitly and aligns with Anthropic's documented best practice. (Originally this spec also pursued own-skill `Read(${CLAUDE_SKILL_DIR}/...)` clauses to suppress permission prompts when a skill reads its own templates or methodology docs; empirical verification during implementation showed that path does not work — see Refactor Rationale → Desired State and the Open Questions resolution.)

## Refactor Rationale
- **Motivation:** Thirteen of fourteen `skills/*/SKILL.md` files declare `allowed-tools: Bash(bash *)` — a broad pre-approval that Anthropic's skills doc explicitly flags as a trust risk ("Review project skills before trusting a repository, since a skill can grant itself broad tool access"). `skills/build/SKILL.md:10` already shows the narrowed shape; the rest have drifted. Research at `docs/research/20260512-skill-allowed-tools-narrowing.md` confirms narrowing is documented best practice with multiple Anthropic-authored precedents (`Bash(git add *) Bash(git commit *)`, `Bash(python3 *)`, `Bash(gh *)`). A secondary motivation — declaring own-skill `Read(...)` clauses to suppress the manual Read permission prompts that fire when a skill reads its own templates/methodology docs — was investigated and found infeasible: those prompts originate in spawned subagents, and Claude Code provides no plugin-shippable mechanism to pre-authorize subagent reads (see Phase 0 verification table below).
- **Current State:** `arch`, `brainstorm`, `conf`, `debug`, `file`, `meta-agent`, `meta-skill`, `meta-test`, `plan`, `research`, `roadmap`, `spec`, `vision` all use `Bash(bash *)`. `build` is already correct but is treated as in-scope for verification so the spec is uniform. ARCHITECTURE.md L378-383 documents "Permission Creep" as an anti-pattern at the agent level; the skill-frontmatter analogue (bare `Bash(bash *)`) is undocumented and unenforced. The corollary anti-pattern around Read clauses (declaring `Read(${CLAUDE_SKILL_DIR}/...)` in skill frontmatter for skills that delegate work to a subagent) is also undocumented.
- **Desired State:** Every `skills/*/SKILL.md` `allowed-tools` clause names the exact script path(s) it actually invokes — `${CLAUDE_PLUGIN_ROOT}` for cross-skill calls, `${CLAUDE_SKILL_DIR}` for own-skill calls. No skill declares a `Read(${CLAUDE_SKILL_DIR}/...)` clause: empirical verification showed these clauses do not propagate to spawned subagents (which is where the cross-boundary Reads actually fire), so they are misleading documentation. The `meta-skill` validation checklist enforces the Bash narrowing rule and warns against the Read anti-pattern. ARCHITECTURE.md gains a "Permission Conventions" subsection under Plugin Conventions (sibling to "Substitution Conventions") that covers the Bash narrowing rule, the verified scope of skill `allowed-tools` (main-thread only), and the user-side `.claude/settings.json` workaround for the residual subagent Read prompts. The "Permission Creep" anti-pattern entry calls out both the skill-frontmatter wildcard case and the Read-clause anti-pattern explicitly. README.md gains a "Permissions" section documenting the one-per-session prompt behavior and the optional zero-prompt snippet.
- **Affected Systems:** All 14 `skills/*/SKILL.md` files; `skills/meta-skill/SKILL.md` validation checklist; `ARCHITECTURE.md` (Plugin Conventions section + Anti-Patterns table); `README.md` (new Permissions section).

### Phase 0 verification table (added during implementation)

Empirical verification against Anthropic docs (`code.claude.com/docs/en/skills.md`, `sub-agents.md`, `permissions.md`, `plugins-reference.md`) and the GitHub issue tracker:

| Mechanism | Status |
| :--- | :--- |
| Skill `allowed-tools` propagates to spawned subagents | ❌ Subagents have independent permissions |
| Subagent frontmatter has an `allowed-tools` field | ❌ Not in the frontmatter table |
| Subagent `tools:` accepts parameterized patterns like `Read(/path/**)` | ❌ Bare tool names only |
| Plugin subagent `permissionMode: bypassPermissions` | ❌ Ignored for plugin subagents (sub-agents.md L227–228) |
| Plugin manifest accepts a `permissions` field | ❌ Not in the manifest schema |
| Plugin-shipped `settings.json` honors `permissions.allow` | ❌ Only `agent` and `subagentStatusLine` keys |
| `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` substitute inside `permissions.allow` patterns | ❌ Substitution scoped to hooks/monitors/MCP/LSP |
| Agent `skills:` preload includes asset/reference files | ❌ SKILL.md body only |
| User-side `.claude/settings.json` `permissions.allow` inherited by subagents | ✅ Only working cross-boundary path |
| `agent:` field in skill frontmatter is inert without `context: fork` | ✅ Confirmed; jim never sets `context: fork` |
| `context: fork` propagates the skill's `allowed-tools` to the forked agent | ❌ Fresh permission scope |

Conclusion: the Bash narrowing pass (Phase 1 of this spec) works as designed. The Read clause pass (Phase 2 of this spec, originally tasks 11–20) was ineffective and is being reverted; documentation replaces it.

## Acceptance Criteria
- [ ] Every `skills/*/SKILL.md` declares `allowed-tools` with `Bash(<exact-script-prefix> *)` clauses matching the script path(s) referenced in that skill's body — no bare `Bash(bash *)` remains.
- [ ] `arch`, `brainstorm`, `build`, `debug`, `meta-agent`, `meta-skill`, `plan`, `research`, `roadmap`, `spec`, `vision` declare `allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)`.
- [ ] `conf` declares `allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimconf.sh *)`.
- [ ] `file` declares `allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimfile.sh *)`.
- [ ] `meta-test` declares `allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Bash(bash ${CLAUDE_SKILL_DIR}/scripts/metatest.sh *)`.
- [ ] `skills/meta-skill/SKILL.md` validation checklist includes a regression-prevention line stating that `allowed-tools` must declare the exact script path(s) the skill injects or runs, and that bare `Bash(bash *)` is a validation failure.
- [ ] `ARCHITECTURE.md` includes a new "Permission Conventions" subsection under "Plugin Conventions" (sibling to "Substitution Conventions") documenting the narrowing rule with one example per sigil (`${CLAUDE_PLUGIN_ROOT}` cross-skill case, `${CLAUDE_SKILL_DIR}` own-skill case).
- [ ] `ARCHITECTURE.md` Anti-Patterns entry for "Permission Creep" mentions skill-frontmatter wildcards (`Bash(bash *)`) as a concrete instance, not only agent tool lists.
- [ ] Smoke check after changes: invoking `/jim:conf list` and `/jim:file path spec jim 001 meta` both succeed without unexpected permission prompts, confirming each skill's narrowed pattern still matches its own `!`-injection sites.
- [ ] No `skills/*/SKILL.md` declares a `Read(${CLAUDE_SKILL_DIR}/...)` clause in its `allowed-tools` line (the original AC 10–11 from this spec, before the Phase 0 verification pivot, are intentionally inverted: the clauses turned out to be ineffective for subagent reads and are being removed).
- [ ] `ARCHITECTURE.md` → Permission Conventions states explicitly that skill `allowed-tools` applies only to the skill's main-thread execution and does **not** propagate to subagents spawned by the Agent tool. It documents the verified non-mechanisms (subagent frontmatter has no `allowed-tools`; sigils don't substitute in permission patterns; plugin manifests don't accept `permissions`; plugin-shipped `settings.json` permission keys are ignored) and the only working cross-boundary path (user-side `.claude/settings.json`).
- [ ] `ARCHITECTURE.md` → Anti-Patterns → "Permission Creep" entry warns against declaring `Read(${CLAUDE_SKILL_DIR}/...)` clauses in skill frontmatter for skills that delegate work to a subagent.
- [ ] `skills/meta-skill/SKILL.md` validation checklist drops the prior Read-clause requirement and adds the anti-pattern warning (no `Read(${CLAUDE_SKILL_DIR}/...)` clauses for delegating skills).
- [ ] `README.md` contains a "Permissions" section documenting (a) the default one-per-session Read prompt behavior and the in-session "Yes, for this session" approval path, and (b) the optional zero-prompt `permissions.allow` snippet for `.claude/settings.json` with the exact key shape (absolute paths to jim's skill assets/references).
- [ ] Existing tests pass without modification.

## Out of Scope
- `.claude/skills/meta-matrix/SKILL.md` — substitution-regression fixture; its broad `Bash(echo *), Bash(bash -c *)` is intentional and must not be touched. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)
- Upstream Anthropic enforcement bugs (issues #14956, #18837, #37683) — outside jim's control. Narrowing's value as documentation and trust-dialog blast-radius reduction stands regardless of upstream status.
- Changes to the `!`-injection sites themselves — only the frontmatter `allowed-tools` declarations change. Bash commands the skills invoke stay byte-identical.
- Restructuring `${CLAUDE_PLUGIN_ROOT}` vs `${CLAUDE_SKILL_DIR}` usage in skill bodies — the existing sigil choices are correct and remain.
- A scripted bash-grep guard for `Bash(bash *)` regressions — the `meta-skill` LLM validation checklist is the chosen prevention mechanism, matching how every other SKILL.md convention is policed today.
- `/jim:setup` skill (would generate a per-install `permissions.allow` snippet automatically) — deferred to a follow-up spec. The README documents the manual snippet path for now.
- Automated empirical tests of Claude Code permission inheritance behavior — see Open Questions. The current `meta-matrix` fixture probes `!`-injection substitution under visual inspection, not permission-prompt behavior; a permissions regression surface would be a different kind of test. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)
- Inlining template/reference content into SKILL.md bodies via `!`-bash to eliminate the cross-boundary Read — considered and rejected: defeats the asset-separation design intent and grows resolved skill content at load time.
- Restructuring jim to ship agents at project-level (instead of plugin-level) so they could declare `permissionMode: bypassPermissions` — rejected: `bypassPermissions` silences all prompts including dangerous Bash, which is a security smell; major distribution-model change.

## Open Questions
- Should we add empirical regression tests (extending `meta-matrix` or in a new test surface) to verify the documented permission-inheritance behavior under future Claude Code versions? Deferred for now — flagged for a future spec. (Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`.)
