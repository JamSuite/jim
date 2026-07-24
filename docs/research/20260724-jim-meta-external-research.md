---
spec: "standalone"
status: Needs PM Review
date: "2026-07-24"
---

<!-- Word budget deliberately exceeded per explicit user direction ("do a deep search … table output … group the findings into tiers"). The DoD <1500-word rule is overridden for this survey, mirroring 20260717-competitive-landscape-sdd-skills.md. -->

# Research: External Prior Art for jim's Meta System (meta-skill / meta-agent / meta-test)

External-inspiration survey for jim's skill/agent-building capability. Input was a first-pass external research report (unverified); **every ranked entry below was re-verified 2026-07-24 by fetching the exact SKILL.md**, plus directory sweeps of skills.sh, claudemarketplaces.com, and claudepluginhub.com (403 for us — swept via developer-pasted search results, 16 hits, all triaged). This doc does **not** update `docs/specs/jim/001-meta/research.md` — it is the collection artifact for that future differential update.

## Anchors

- `skills/meta-skill/SKILL.md` (L1–133) — the skill this research will eventually reshape; propagation root for the writing-style rule.
- `skills/meta-agent/SKILL.md` (L1–132) — agent-creation counterpart; target for schema/workflow separation findings.
- `agents/meta.md` (L1–64) — @jim:meta persona; target for artifact-classification and completion-contract findings.
- `skills/meta-test/scripts/testlib.sh` — jim's deterministic bash test harness; the base any Layer-2/3 (routing/behavioral) test expansion builds on.
- `docs/specs/jim/001-meta/{spec,plan,research}.md` — the spec family this feeds; research.md gets the differential update later.
- `ARCHITECTURE.md` § Plugin Conventions — locked constraints (bash LCD, no third-party deps, logic-flow idiom) that bound what can be imported.

## Local Patterns

Phase 0 was abbreviated by design: the target is the external landscape, and jim's own meta system is already documented in `001-meta/research.md` and `ARCHITECTURE.md`. Test template for any adopted testing pattern: `tests/metatest.sh` sourcing `skills/meta-test/scripts/testlib.sh` (case-function discovery, heredoc fixtures, mktemp sandbox — no third-party framework).

## Verification Deltas vs. First Pass

The first-pass report was directionally sound: **12 of its 13 ranked sources verified**, with these corrections:

| First-pass claim | Verified reality |
|---|---|
| Anthropic plugin-dev paths (repo unstated) | Canonical home is `anthropics/claude-plugins-official` (`/plugin install plugin-dev@claude-code-marketplace`); also mirrored in `anthropics/claude-code`. Content claims (model/color presented as required; no coverage of `skills`, `hooks`, `memory`, `isolation`, `background`, `maxTurns`) confirmed. |
| "xobotyi" repo unstated | `xobotyi/cc-foundry`, **master** branch, only **18★**. All content claims verified exactly (decision matrix, 30/25/25/10/10 rubric, prompt-engineering prerequisite). |
| "Taches" repo unstated | `glittercowboy/taches-cc-resources`. Both skills verified. |
| "Tech Leads Club" path | Verified at `tech-leads-club/agent-skills` → `packages/skills-catalog/skills/(creation)/subagent-creator/SKILL.md` (~320 lines). Platform-agnostic fields (`readonly`, `.agent/subagents/`) confirmed. |
| Matt Pocock writing-great-skills "~83 lines" | **~280 lines.** Concepts verified (context vs cognitive load, one-trigger-per-branch, no-op detection, leading words). |
| "Workflow Toolkit: Create Agent" | **Not found — dropped from ranked results.** Best candidate `softaworks/agent-toolkit` (2.2k★) has no create-agent skill (its Meta lane: `plugin-forge`, `command-creator`, `skill-judge`, `agent-md-refactor`). |
| davila7 mirror-copy dedup note; Addy Osmani `evals.json` adoption | Not independently re-verified — carried as reported, low-stakes. |

New finds the first pass missed: **jdforsythe/forge** (promoted to Tier 1), plus Tier-3 entries from the sweeps below.

## Prior Art

### Tier 0 — Canonical official implementations

| Name | SKILL.md | Description | Pros | Cons / Sentiment |
|---|---|---|---|---|
| Anthropic: Agent Development | [claude-plugins-official → plugin-dev/skills/agent-development](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/plugin-dev/skills/agent-development/SKILL.md) | Official guide to plugin agents: frontmatter, descriptions-as-dispatch, `<example>`/`<commentary>` blocks, system prompts, validation. ~5,500 words. | The canonical answer to jim's exact trigger set. Ships `validate-agent.sh` + `test-agent-trigger.sh`. Strong on description = dispatch contract with 2–4 concrete examples. | **Essential baseline, schema-stale.** Presents `model`/`color` as required; omits `skills`, `hooks`, `memory`, `isolation`, `background`, `maxTurns`, `mcpServers`, permission modes — all current fields per `001-meta/research.md`. |
| Anthropic: Skill Development | [claude-plugins-official → plugin-dev/skills/skill-development](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md) | Official 6-step skill authoring process (understand → plan resources → create dir → write → validate/test → iterate). ~6,500 words. | Strong progressive-disclosure guidance; concrete trigger phrases; points to agent-development as its own best example. | **Authoring guide, not evaluator.** Checklist validation only. Third-person description mandate and 1,500–2,000-word target are its conventions, not platform rules. |
| Anthropic: Skill Creator | [anthropics/skills → skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) | 11-step create/edit/benchmark/optimize pipeline: eval prompts (`evals/evals.json`), with-skill vs baseline subagent runs, trigger-accuracy loop (`run_loop.py`), packaging. 326K installs on skills.sh. | The strongest official treatment of skills as measurable. Separates trigger accuracy from output quality. | **Best eval model, wrong substrate for jim.** Product-generic (not plugin-agent aware) and Python-scripted — conflicts with jim's bash-only convention; import the eval *format*, not the tooling. |

### Tier 1 — Direct agent/subagent builders (study closely)

| Rank | Name | SKILL.md | Description | Pros | Cons / Sentiment |
|---|---|---|---|---|---|
| 1 | xobotyi: Subagent Engineering | [cc-foundry → ai-helpers/skills/subagent-engineering](https://github.com/xobotyi/cc-foundry/blob/master/plugins/ai-helpers/skills/subagent-engineering/SKILL.md) | Full subagent lifecycle: decide → create → configure → evaluate → iterate → troubleshoot. ~450 lines. | **Best community analogue.** Subagent-vs-skill-vs-Agent-Team decision matrix; current frontmatter (`memory`, `isolation`, `background`, `effort`); weighted rubric — task completion 30% / trigger accuracy 25% / output quality 25% / context efficiency 10% / tool usage 10%, with score thresholds; 6-issue troubleshooting table. | Tiny adoption (18★) — quality is in the text, not the traction. Requires invoking its `prompt-engineering` skill first (instruction-system coupling). Not spec-gated; no integrated SDLC. |
| 2 | Jamie-BitFlight: Agent Creator | [claude_skills → plugin-creator/skills/agent-creator](https://github.com/Jamie-BitFlight/claude_skills/blob/main/plugins/plugin-creator/skills/agent-creator/SKILL.md) | End-to-end generator: scan existing agents → gather requirements → standard vs role-based-contract archetypes → write → place (project/user/plugin) → validate. ~1,200 lines. | Most production-oriented. DONE/BLOCKED contracts; MCP tool-name validation ("wildcards silently fail; case-sensitive"); `claude plugin validate`; **documented incident: a 2-entry `agents` array in plugin.json disabled auto-discovery and hid 17 of 19 agents.** | ~1,200 lines in one SKILL.md — violates progressive disclosure jim enforces (≤500). Mine into references, don't copy structurally. |
| 3 | jdforsythe: Forge Agent Creator *(new find)* | [forge → skills/agent-creator](https://github.com/jdforsythe/forge/blob/master/skills/agent-creator/SKILL.md) | Research-backed agent definitions: 7-component format, persona science, vocabulary routing, MAST failure taxonomy. ~520 lines; sibling `skill-creator`, `mission-planner`, `librarian`. 149★. | Only entry that cites controlled studies (Zheng et al. 2024; Hu et al. 2026: longer personas degrade task performance). Token-budgets role identity (~20–50 tokens); flattery/consultant-speak detection; 8-pattern anti-pattern watchlist with detection signals. | Own frontmatter dialect (`domain`, `tags`, `quality`) — not Claude Code plugin schema; team-blueprint orientation exceeds jim's single-plugin scope. Mine the persona-science validation gates. |
| 4 | Taches: Create Subagents | [taches-cc-resources → skills/create-subagents](https://github.com/glittercowboy/taches-cc-resources/blob/main/skills/create-subagents/SKILL.md) | Subagent design: prompts, tool access, delegation contracts, orchestration, recovery, debugging. ~450 lines + 7 reference files. | Strongest on the black-box constraint: isolated context, "cannot use AskUserQuestion", must return a useful result. References cover evaluation, error recovery, context management. | Opinionated beyond platform fact: "remove ALL markdown headings, use semantic XML tags" is a house style, not a Claude Code requirement. Value is spread across its references. |
| 5 | Taches: Create Agent Skills | [taches-cc-resources → skills/create-agent-skills](https://github.com/glittercowboy/taches-cc-resources/blob/main/skills/create-agent-skills/SKILL.md) | Router-style skill authoring: `<intake>`/`<routing>` in a ~280-line SKILL.md dispatching to workflows/ + references/. | Best community example of progressive disclosure as architecture — demonstrates its own teaching. Closest structural cousin to jim's SKILL.md + assets/ + references/ + scripts/ split. | Organization system, not an evaluator; no spec gate, no deterministic tests. |

### Tier 2 — Specific patterns worth mining

| Name | SKILL.md | Relevance to jim | Pros | Cons / Sentiment |
|---|---|---|---|---|
| obra: Writing Skills | [superpowers → skills/writing-skills](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) | Behavioral TDD for instructions — maps directly to a stronger `/jim:meta-test`. ~8,500 words. | "NO SKILL WITHOUT A FAILING TEST FIRST" — literal RED (baseline pressure scenario without skill) → GREEN (minimal instruction fix) → REFACTOR (close rationalization loopholes). "Write skill before testing? Delete it. Start over." | Intentionally dogmatic; behavioral runs are token-expensive; nothing on plugin frontmatter/placement. Import the failing-baseline discipline, cost-gate the runs. |
| Matt Pocock: Writing Great Skills | [mattpocock/skills → productivity/writing-great-skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-great-skills/SKILL.md) | Editorial standard for reviewing meta-generated skills. ~280 lines (not 83 as first-passed). | Precise review vocabulary: context load vs cognitive load; one trigger per behavioral branch ("synonyms are duplication"); no-op detection ("does this sentence change behavior vs default?"); leading words. Sharpens jim's 500-line rule into a branch-relevance rule. Sibling `write-a-skill` has 225K installs on skills.sh. | Not a generator — no directories, validation, or evaluation. "Leading words" is a heuristic, not a platform rule. |
| tech-leads-club: Subagent Creator | [agent-skills → (creation)/subagent-creator](https://github.com/tech-leads-club/agent-skills/blob/main/packages/skills-catalog/skills/(creation)/subagent-creator/SKILL.md) | Compact teaching reference: skill-vs-subagent flowchart, verifier/debugger/auditor/reviewer archetypes. ~320 lines. | Clear decision flowchart; one-responsibility discipline; delegation-actually-happens testing. Curated registry with CI static analysis + content hashing (their stat: 13.4% of open-marketplace skills contain critical issues). | Deliberately platform-agnostic: `readonly`, `.agent/subagents/` — do not copy fields verbatim into Claude Code frontmatter. |
| GzuPark: Subagent Creator | [claude-plugin-pack → creators/skills/subagent-creator](https://github.com/GzuPark/claude-plugin-pack/blob/main/plugins/creators/skills/subagent-creator/SKILL.md) | Practical mid-size guide (~280 lines): frontmatter table incl. `permissionMode`/`skills`/`hooks`, 5-step workflow, 6 anti-patterns, design-rationale section. | Current fields; correctly centers description as the routing mechanism; useful hooks matcher examples. | Confirmed shallow on evaluation — no trigger testing or completion gates. Starter reference only. |
| CodeAlive: Subagents Management | [ai-driven-development → skills/subagents-management](https://github.com/CodeAlive-AI/ai-driven-development/blob/main/skills/subagents-management/SKILL.md) | Meta-development as ongoing resource lifecycle: create/edit/list/move/delete across Claude Code, Codex, OpenCode. ~280 lines + helper scripts. | Only entry treating agents as a managed fleet, not one-shot output. Mandatory AskUserQuestion confirm before delete. Helper scripts (`list_subagents.py`) with manual fallback. | Cross-platform ambition dilutes Claude Code depth; Python helpers conflict with jim's bash convention. Import the lifecycle verbs, not the scripts. |

### Tier 3 — Reference only

| Name | Source | One line | Sentiment |
|---|---|---|---|
| softaworks: agent-toolkit Meta lane | [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) → `skills/{plugin-forge,command-creator,skill-judge,agent-md-refactor}` | 2.2k★ curated collection; `skill-judge` (skill quality review) and `plugin-forge` (plugin/manifest scaffolding) are the relevant pieces. | Adjacent, not a direct agent-builder; content not deep-verified. |
| claude-world: director-mode-lite | [claude-world/director-mode-lite](https://github.com/claude-world/director-mode-lite) | Orchestration plugin (77★) with `/agent-template`, `/skill-template`, `/hook-template` generators among 32 skills. | Template generation without spec gating or evaluation. |
| b-open-io: prompts | [b-open-io/prompts](https://github.com/b-open-io/prompts) | 14★; `agent-onboarding`, `agent-auditor`, `agent-decommissioning`, `benchmark-skills` ("write evals for skills, measure impact vs baseline"). | Full onboard→audit→decommission arc is a neat lifecycle sketch at tiny scale. |
| nickcrew: claude-cortex | [nickcrew/claude-cortex](https://github.com/nickcrew/claude-cortex) | 31★; `skills/agent/` — "audit, configure, scaffold, and route agents and subagents" + skill-creator/capture/comply. | Exact SKILL.md raw path 404s on main and master — repo-level reference only. |
| boshu2: agentops | [boshu2/agentops](https://github.com/boshu2/agentops) | 414★; "one intent, one bounded build, one fresh judge, one durable verdict" — fresh-context validation separated from authorship. | Not meta-authoring, but its fresh-judge separation independently validates jim's isolated-verifier direction. |
| Salesforce AI Research: agentforce-adlc | [salesforceairesearch/agentforce-adlc](https://github.com/salesforceairesearch/agentforce-adlc) | Full Agent Development Life Cycle (generate/test/observe/secure) authored via Claude Code — for Salesforce Agentforce agents. | The one other reviewed *lifecycle* system — platform-specific, so jim's claim narrows to "unique among Claude Code component builders", and holds. |

**Reviewed and excluded:** `aaaaqwq/agi-super-team` (79★ prebuilt executive-persona packs, no authoring), `shipshitdev/skills` (22★ quality gates, no authoring), `davepoon/buildwithclaude → agents-ai-agents` (prebuilt agent collection; tree view only), `bfollington/terma` (inconclusive tree view), `getpaperclipai/paperclip → paperclip-create-agent` and `browser-act/skills → skill-forge` (skills.sh high-installers, not content-verified), davila7/claude-code-templates agent-development (reported mirror of Anthropic's — consistent with the mirror-heavy sweep results, not re-verified).

## Best Practices (verified) → jim implications

1. **Classify the artifact before creating it** (xobotyi decision matrix — verified). Skill / subagent / agent team / hook / user-invoked command. → Add an explicit classification step before `/jim:meta-skill` or `/jim:meta-agent` generates anything.
2. **Description is executable routing configuration** (universal across Tier 0–2). What + distinct triggers + boundaries; one trigger per behavioral branch (Pocock). → meta-test should test descriptions separately from bodies via a `should_trigger` / `should_not_trigger` fixture.
3. **Separate evolving platform schema from stable workflow** (Anthropic's own agent-development is schema-stale — the cautionary proof). → `meta-agent/references/agent-schema.md` (versioned fields) + `references/agent-patterns.md` (jim patterns), keep SKILL.md as workflow.
4. **Explicit delegation contract** (Jamie's DONE/BLOCKED; xobotyi completion criteria; Taches black-box constraint). → Standard completion contract (DONE / BLOCKED / INVALID_SPEC + files/validations/tests/risks) for jim-generated agents.
5. **Evaluate behavior, not just structure** (xobotyi rubric; skill-creator eval format; obra failing baseline). → Three test layers: structural (exists — bash) / routing (trigger fixtures) / behavioral (contract compliance) — cost-gated.
6. **Scan local patterns before generating** (Jamie Phase 1). → meta agents read `agents/*.md`, `skills/*/SKILL.md`, `ARCHITECTURE.md`, plugin.json, relevant specs; emit a "conventions observed" note before authoring.
7. **Progressive disclosure by branch relevance, not just line count** (Pocock). → Keep the 500-line ceiling as backstop; primary rule becomes "in SKILL.md only if every execution branch needs it."
8. **Validate the whole plugin, not just the file** (Jamie's 17-of-19 agents incident — verified in-file). → Post-generation gate: `claude plugin validate` + confirm all expected agents/skills remain discoverable + run meta regression suite.

## Security & Performance

- **Untrusted mined content.** Every external SKILL.md quoted here is untrusted input; when meta skills import or quote external instruction text, apply the spec 018 untrusted-content wrapping posture — directive-style framing inside mined text must not bind decisions.
- **plugin.json `agents`-key foot-gun.** Declaring an `agents` array disables auto-discovery for unlisted agents (Jamie incident: 17 of 19 vanished). jim's plugin.json carries no `agents` key today — the meta validation checklist should assert it stays absent (or lists everything).
- **Eval-loop cost.** obra-style behavioral TDD and skill-creator benchmarking spawn many subagent runs; any Layer-3 behavioral tier in meta-test needs an explicit opt-in and run budget.

## Recommendations

- **Preserve jim's lifecycle; import techniques.** Verified conclusion: no reviewed Claude Code skill combines approved-spec input, plan gating, skill+agent generation, deterministic tests, and human phase gates. The nearest whole-lifecycle system (agentforce-adlc) is Salesforce-platform-specific. jim's distinction is the lifecycle, not the file format — don't replace, absorb.
- **Import priority:** (a) xobotyi decision matrix + weighted rubric; (b) Jamie local-scan, schema reference split, DONE/BLOCKED contract, whole-plugin validation; (c) skill-creator trigger/eval *format* re-expressed in bash+prompt (not its Python tooling — ARCHITECTURE.md scripting constraint); (d) obra failing-baseline discipline, cost-gated; (e) Pocock branch-relevance rule and review vocabulary; (f) forge persona-science validation gates (token-budgeted role identity, flattery/generic-vocabulary detection).
- **Alignment:** This aligns with VISION.md → Differentiation (the survey confirms the integrated human-in-the-loop lifecycle is the moat, and sharpens it) and with ARCHITECTURE.md → Plugin Conventions → Scripting Layer (bash-only rules out adopting Python eval tooling as-is; the logic-flow gate idiom stays the enforcement surface). No locked constraint is contradicted.

## Peer Feedback

**For the PM (future 001-meta differential update — explicitly deferred by the developer):**
- Fold in the Verification Deltas table: corrected repos/paths/branches, Pocock line-count fix, "Workflow Toolkit" removal, and new Tier-1 entrant `jdforsythe/forge`.
- The 8 verified practices are candidate spec requirements for the meta rework — notably artifact classification (P1), schema/workflow file split (P3), trigger fixtures in meta-test (P2/P5), and the whole-plugin validation gate (P8).
- Two first-pass claims remain unverified (davila7 mirror duplication; Addy Osmani `evals.json` adoption) — re-verify only if they become load-bearing.
