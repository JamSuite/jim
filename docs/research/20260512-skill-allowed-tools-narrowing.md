---
spec: "standalone"
status: Active
date: "2026-05-12"
---

# Research: Skill `allowed-tools` Narrowing — Least Privilege for Bash Patterns

## Anchors

- `skills/build/SKILL.md:10` — the only skill already narrowed; canonical reference: `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)`.
- `skills/{arch,brainstorm,debug,meta-agent,meta-skill,plan,research,roadmap,spec,vision}/SKILL.md` line 10/11 — ten skills using wildcard `Bash(bash *)`; each `!`-injects only `${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh`.
- `skills/conf/SKILL.md:10,33` — wildcard, but body only injects `${CLAUDE_SKILL_DIR}/scripts/jimconf.sh $ARGUMENTS`.
- `skills/file/SKILL.md:11,18` — wildcard, but body only injects `${CLAUDE_SKILL_DIR}/scripts/jimfile.sh $ARGUMENTS`.
- `skills/meta-test/SKILL.md:11,47,64,86,105` — wildcard; `!`-injects `jimfile.sh` (via `CLAUDE_PLUGIN_ROOT`) AND has fenced bash blocks the LLM runs against `${CLAUDE_SKILL_DIR}/scripts/metatest.sh` (scaffold/add/run).
- `ARCHITECTURE.md:383` — Anti-Patterns table already lists "Permission Creep" with the rule "follow least privilege"; agent-level discipline; skills have drifted.
- `ARCHITECTURE.md:258` — Plugin Conventions documents `${CLAUDE_PLUGIN_ROOT}` (cross-skill) and `${CLAUDE_SKILL_DIR}` (own-skill) substitutions; both are required by the narrowed forms.

## Local Patterns

- **Two path sigils are already in use.** `${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<file>.sh` for cross-skill calls; `${CLAUDE_SKILL_DIR}/scripts/<file>.sh` for own-skill calls. Both must appear verbatim inside `Bash(...)` patterns to match — they substitute at the same load-time pass as `!`-injection.
- **Build is the template.** `skills/build/SKILL.md:10` is the only narrowed skill in the repo today and was implemented as a deliberate test (per user). It is the canonical exemplar; this refactor generalizes it.
- **Validation surface is LLM-checked, not scripted.** `meta-skill` and `meta-agent` SKILL.md bodies hold checklist items the model walks at create-time; there is no bash test for SKILL.md frontmatter. Closest existing test pattern (for any test work this refactor produces): `tests/jimfile.sh` — `case_*` functions sourced via `testlib.sh`, exit-code/string asserts, inline heredoc fixtures.
- **Prior research already audited this surface.** `docs/specs/jim/008-jimconf/research.md:101` and `009-jimfile/research.md:78` both note `allowed-tools` is "documented but enforcement is buggy" (cite Anthropic issues #14956, #18837, #37683). They explicitly tell readers to treat declarations as documentation, not security. That framing affects the value proposition (see Recommendations).

## Prior Art

Authoritative source: `code.claude.com/docs/en/skills` and `…/permissions` (Anthropic Claude Code docs; `docs.claude.com/en/docs/claude-code/*` redirects 301 → `code.claude.com/docs/en/*`).

| File / URL | What It Is | Why It Matters |
|---|---|---|
| `code.claude.com/docs/en/skills` § "Pre-approve tools for a skill" | The canonical reference for `allowed-tools` semantics | States `allowed-tools` is a **grant of pre-approval**, not a sandbox: "It does not restrict which tools are available: every tool remains callable, and your permission settings still govern tools that are not listed." |
| Same § — commit skill example | Anthropic-authored example of narrowing | Shows three narrow rules side-by-side: `Bash(git add *) Bash(git commit *) Bash(git status *)`. Documented best-practice shape. |
| Same § — "Restrict Claude's skill access" warning | Documented least-privilege guidance | "Review project skills before trusting a repository, since a skill can grant itself broad tool access." This is Anthropic explicitly flagging wildcard `Bash(*)` as a trust risk. |
| `code.claude.com/docs/en/skills` § "Generate visual output" (codebase-visualizer) | Anthropic-authored skill with bundled script | Uses `Bash(python3 *)` — narrowed to interpreter, leaves args open. Direct precedent for the `Bash(bash <script-path> *)` shape jim uses. |
| `code.claude.com/docs/en/skills` § "Inject dynamic context" (pr-summary) | Anthropic-authored skill with `!`-injection | Uses `Bash(gh *)` even though the only invocations are `gh pr diff` etc. — confirms the prefix-narrowing pattern is canonical even when arguments are predictable. |
| `code.claude.com/docs/en/permissions` § "Bash" | Pattern-matching semantics | Documents word-boundary rule: `Bash(ls *)` matches `ls -la` but not `lsof`; `Bash(ls*)` (no space) matches both. The space in `Bash(bash ${CLAUDE_PLUGIN_ROOT}/…/jimfile.sh *)` is therefore load-bearing — it anchors a word boundary after the script path. |
| Same § — compound command awareness | Pattern-matching semantics | "A rule like `Bash(safe-cmd *)` won't give it permission to run the command `safe-cmd && other-cmd`." Fits jim's model: every `!`-injection site is a single command. |
| Same § — Warning callout | Documented caveat | "Bash permission patterns that try to constrain command arguments are fragile." This is the caveat jim must be honest about (see Security & Performance). |

## Security & Performance

- **The fragility caveat does not apply here.** The docs' warning targets attempts to constrain *arguments* (e.g. `Bash(curl http://github.com/ *)` defeated by `curl -X GET http://...`, redirects, env vars, extra spaces). Jim's pattern constrains the *command prefix* — `bash <stable-script-path>` — and leaves `*` for arguments. The script path is a fixed plugin-installation file, not user input; an adversary would need to *write a new script* into the plugin tree to abuse it, which is a much higher bar than smuggling args.
- **Enforcement bugginess is documented but mitigations remain.** Prior jim research (008/009) cites open Anthropic issues #14956, #18837, #37683 against `allowed-tools` enforcement. Status of those issues was not re-verified in this pass; even if still buggy, narrowing has two non-security benefits that survive: (a) it documents intent for human reviewers of the SKILL.md, (b) it is the shape Anthropic's docs prescribe, so jim stays aligned for when enforcement tightens.
- **Trust-dialog blast radius.** Per docs: project-scope skills get `allowed-tools` honored *after the user accepts the workspace-trust dialog*. A wildcard-trusting user implicitly pre-approves every bash command jim's skills could issue for the lifetime of that project. Narrowing reduces that blast radius to the resolver scripts jim actually invokes.
- **No performance impact.** `allowed-tools` is matched at permission-check time per tool call; narrowing affects only which rule wins, not the number of checks.
- **`meta-test` is the only multi-script case.** It needs *two* `Bash(...)` clauses — one for the `!`-injected `jimfile.sh` (gate lookups), one for the LLM-run `metatest.sh` (subcommands inside fenced bash blocks). Single-script skills need only one clause.

## Recommendations

**Confirmed: narrowing is best practice.** Anthropic's own example skills (`commit`, `codebase-visualizer`, `pr-summary`) all use prefix-narrowed `Bash(...)` clauses; the docs explicitly flag broad `allowed-tools` as a trust risk. Jim's existing `skills/build/SKILL.md:10` is the correct template.

**Per-skill target patterns** (deduced from `!`-injection sites + fenced bash blocks):

| Skill | Recommended `allowed-tools` |
|---|---|
| arch, brainstorm, debug, meta-agent, meta-skill, plan, research, roadmap, spec, vision | `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)` |
| build | `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)` (already correct) |
| conf | `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimconf.sh *)` |
| file | `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimfile.sh *)` |
| meta-test | `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *) Bash(bash ${CLAUDE_SKILL_DIR}/scripts/metatest.sh *)` |

Notes for the architect / PM:

- **Out-of-scope but worth flagging:** `.claude/skills/meta-matrix/SKILL.md:10` (the substitution-regression fixture) uses `Bash(echo *), Bash(bash -c *)` — deliberately broad for testing. Leave it as-is. (Sentinel fixture location updated by spec 014 — the `allowed-tools` row now lives at `skills/meta-matrix-bash-invocation/SKILL.md`.)
- **Frontmatter trivia.** `allowed-tools` accepts a space-separated string or a YAML list (docs § Frontmatter reference). Jim already uses the space-separated form; keep it consistent.
- **Validation gate.** Add a one-line check to `meta-skill`'s validation checklist: "`allowed-tools` declares the exact script path(s) the skill injects or runs — no bare `Bash(bash *)`." This prevents regression.

## Alignment

- **VISION.md — "Transparency over automation."** Narrowed `allowed-tools` makes the skill's bash surface explicit at the top of every SKILL.md; readers do not have to scan the body to learn what bash can run. Aligned.
- **ARCHITECTURE.md L383 — Anti-Patterns: Permission Creep.** The document already names "Write/Bash in a read-only agent's tool list — follow least privilege" as a documented anti-pattern. Today's wildcard `Bash(bash *)` in 13 skills is the skill-level analogue of the same anti-pattern. This refactor closes that drift.
- **ARCHITECTURE.md L258 — Plugin Conventions / Scripting Layer.** The narrowed patterns use the documented `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` sigils unchanged; no new convention is introduced.

No divergence from VISION.md or ARCHITECTURE.md locked constraints.
