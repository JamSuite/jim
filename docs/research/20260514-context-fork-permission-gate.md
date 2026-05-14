---
spec: "standalone"
status: Active
date: "2026-05-14"
---

# Research: `context: fork` permission gate — closing the spec 014 Open Question

Spec 014's second matrix rerun (2026-05-13) observed that `Skill(jim:meta-matrix-fork-probe)` in `skill-invocation`'s `allowed-tools` did NOT auto-approve the nested Skill-tool invocation — the user got an explicit "Use skill 'jim:meta-matrix-fork-probe'?" consent prompt. The parallel `Agent(meta-matrix-probe)` call (also in `allowed-tools`) ran silently. Five sub-questions framed in `docs/specs/jim/014-meta-matrix/plan.md` § "Permission prompt for `context: fork` skills".

## Anchors

- `docs/specs/jim/014-meta-matrix/plan.md:520-555` — Verification Log § "Skill-invocation (rows S1-S5)" with the S4/S5 readings and the permission-prompt finding paragraph.
- `docs/specs/jim/014-meta-matrix/plan.md` Open Questions block — the five sub-questions this research aims to close.
- `docs/research/20260512-001-meta-skill-invocation-freshness.md` § "Path 2 (`context: fork`) and path 3 (`skills:` preload)" — the empirical paragraph framing the platform finding (updated 2026-05-13 after the second rerun).
- `skills/meta-matrix-fork-probe/SKILL.md:1-11` — the `context: fork` + `agent: meta-matrix-probe` frontmatter that triggered the prompt.
- `skills/meta-matrix-skill-invocation/SKILL.md:8` — the `allowed-tools` line declaring `Bash(echo *), Bash(bash -c *), Skill(jim:meta-matrix-fork-probe), Agent(meta-matrix-probe)`.
- `ARCHITECTURE.md:241-253` — current claims about `context: fork`, `Skill(name)` permission tokens, and the build→arch auto-approval precedent.
- `skills/build/SKILL.md:10` — the only existing jim precedent for `Skill(jim:<name>)` in `allowed-tools` (calling `arch`, which has no `context: fork`).

## Local Patterns

**Skill-to-skill invocation in jim today:** Two precedents, asymmetric:

| Caller | `allowed-tools` declares | Target | Target carries `context: fork`? | Empirical behavior on first invocation |
| :--- | :--- | :--- | :--- | :--- |
| `skills/build/SKILL.md:10` | `Skill(jim:arch)` | `arch` | No | (Assumed silent — not empirically retested in a fresh workspace) |
| `skills/meta-matrix-skill-invocation/SKILL.md:8` | `Skill(jim:meta-matrix-fork-probe)` | `meta-matrix-fork-probe` | **Yes** | **Explicit consent prompt** (Verification Log) |

Other relevant inventory (per the Phase 0 archaeology):
- Zero other `context: fork` skills in jim (`grep -rn "context: fork" skills/ agents/` returns only fork-probe).
- Zero `permissionMode:` declarations in jim skills or agents.
- `Agent(meta-matrix-probe)` in `skill-invocation`'s `allowed-tools` is the first jim precedent for an Agent token in a SKILL'S `allowed-tools` (agents previously held Agent tokens only in their own `tools:` field; e.g., `agents/researcher.md:40`). This call ran silently in the same parallel batch as the prompted fork-probe call.

**Testing convention:** jim's manual diagnostic posture (meta-matrix family) is the right surface to retest this — no automated framework covers SKILL.md body invocation behavior. The S4/S5 rerun is the canonical reproduction.

## Prior Art

Six Claude Code documentation sections fetched 2026-05-14 (refresh of the 2026-05-12 001-freshness pass). Treating the platform docs as prior art because this is a platform-behavior investigation. Tiered per DoD checklist item 5.

**Tier 1 (Study Closely) — directly contradicts the observation:**

| Page / Section | What It Is | Why It Matters |
|---|---|---|
| `code.claude.com/docs/en/skills` § "Pre-approve tools for a skill" | Documents `allowed-tools` semantics: "grants permission for the listed tools while the skill is active, so Claude can use them without prompting you for approval." | Doc claims auto-approval — sets the expectation that's failing empirically. Same section: "For skills checked into a project's `.claude/skills/` directory, `allowed-tools` takes effect after you accept the workspace trust dialog for that folder." Plugin skills may follow a different but parallel trust path. |
| `code.claude.com/docs/en/skills` § "Restrict Claude's skill access" | Documents `Skill(name)` / `Skill(name *)` permission rule syntax. | Confirms `Skill(jim:meta-matrix-fork-probe)` is a syntactically valid permission rule. Examples here all show rules at the global `/permissions` level — no examples of `Skill(name)` inside another skill's `allowed-tools` actually auto-approving a nested call. |
| `code.claude.com/docs/en/permissions` § "Permission system" / "Manage permissions" | "Allow rules let Claude Code use the specified tool without manual approval." Rules evaluated deny → ask → allow. | Confirms allow rules should auto-approve. Does NOT document a per-skill trust gate that bypasses allow rules. Notes the "Yes, don't ask again" persistence flow. |

**Tier 2 (Study for Specific Patterns) — boundary semantics:**

| Page / Section | What It Is | Why It Matters |
|---|---|---|
| `code.claude.com/docs/en/skills` § "Run skills in a subagent" | Documents `context: fork` mechanism — the skill body becomes the task prompt for a fresh subagent. | No mention of an additional consent gate for `context: fork` skills. The mechanism is presented as a routing primitive, not a security boundary. |
| `code.claude.com/docs/en/sub-agents` § "Permission modes" + "Fork the current conversation" | Permission modes table (`default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`); the `/fork` feature (env-flag-gated, distinct from skill `context: fork`). | Permission modes don't document a per-skill-invocation trust gate. Confirms `/fork` is a different mechanism from skill `context: fork`. |

**Tier 3 (Reference Only) — plugin distribution context:**

| Page / Section | What It Is | Why It Matters |
|---|---|---|
| `code.claude.com/docs/en/plugins` § "Develop more complex plugins" | Plugin component layout. References `/en/discover-plugins#security` for plugin trust. | Documented plugin trust is install-time only (`pluginTrustMessage` managed setting). No documented per-skill trust prompt at invocation time. |

**Key gap:** no doc section documents the per-skill-invocation trust prompt observed in the rerun. The prompt shape ("Yes, don't ask again for X in `<workspace>`") matches Claude Code's standard permission-rule acceptance flow — but per the Tier 1 docs, `Skill(name)` in the calling skill's `allowed-tools` should have pre-approved it.

## Security & Performance

- **Plugin authors should not assume `Skill(name)` in `allowed-tools` auto-approves.** Empirical evidence: at least for `context: fork` targets, it does not. Plugin authors documenting workflows that chain skills should warn users of the first-invocation prompt — `skills/meta-matrix-skill-invocation/SKILL.md:48` already does this in jim.
- **The "Yes, don't ask again" rule scope is per-workspace.** The prompt offered `"Yes, don't ask again for jim:meta-matrix-fork-probe in /workspaces/korswerk"`. This is consistent with Claude Code persisting allow rules to `.claude/settings.local.json` in the workspace. Cross-workspace re-prompting is expected.
- **No new security risk to jim.** The gate is more restrictive than the docs suggest, not less. The platform is failing closed (prompt) where the docs suggest it would fail open (auto-approve). This is the conservative direction.
- **Performance: one-time cost per workspace per skill.** Not in any hot loop. After "don't ask again" is selected, subsequent invocations are silent.

## Recommendations

Closing the five sub-questions from spec 014's Open Question:

(a) **Documented platform rule, or empirical only?** Empirical only. None of skills, sub-agents, permissions, or plugins docs (fetched 2026-05-14) document a per-skill-invocation trust gate distinct from the global permission system. The skills doc explicitly says `allowed-tools` auto-approves — which contradicts observed behavior.

(b) **Once-per-session or once-per-invocation?** Once-per-workspace-per-skill, persisted. Before acceptance, every invocation would re-prompt; after "don't ask again", silent for the workspace's lifetime.

(c) **"Yes, don't ask again" scope?** Workspace-scoped, persisted to `.claude/settings.local.json` (inferred from prompt text "in `<workspace>`" and the permissions doc's settings precedence).

(d) **Other frontmatter shapes that trigger the gate?** **Undetermined empirically.** The hypothesis is `context: fork` triggers it; the simpler explanation may be: any first-invocation of a newly-discovered plugin skill in a workspace prompts, regardless of `context: fork`. The build→arch precedent was likely accepted long ago in users' workspaces, masking this. A follow-up probe (ship a NEW non-fork skill, invoke in a fresh workspace) disambiguates.

(e) **Should ARCHITECTURE.md:242 be amended?** **Yes** — proposed wording in Peer Feedback. The current claim ("the caller's `allowed-tools` covers nested tool calls inside the invoked skill") is technically about tool calls made *inside* the called body, but has been read (in spec 014's design) as implying the caller's `Skill(name)` token auto-approves the Skill-tool *invocation* of the target. The empirical finding shows that latter reading is wrong, at least for `context: fork` targets.

**Alignment.** VISION.md not present (confirmed). ARCHITECTURE.md:241-253 is the load-bearing constraint and the document that needs amendment. The recommended amendment narrows an existing claim rather than introducing new architecture — no strategic-direction shift.

## Peer Feedback

**For Architect — ARCHITECTURE.md:242 amendment.** Current text implies `Skill(jim:arch)` in `build`'s `allowed-tools` auto-approves the nested Skill-tool call; empirically this only holds after a one-time per-workspace trust prompt. Proposed insert after the existing sentence ending "covers nested tool calls inside the invoked skill":

> **First-invocation trust prompt (empirical, 2026-05-14).** On the *first* invocation of a never-before-seen plugin skill in a workspace, Claude Code shows a "Use skill 'X'?" consent prompt regardless of `allowed-tools`. The "Yes, don't ask again for X in `<workspace>`" option persists workspace-scoped acceptance; subsequent invocations auto-approve. Confirmed empirically by spec 014's S4 probe. Whether the trigger is `context: fork` specifically or any new plugin skill is undetermined — see `docs/research/20260514-context-fork-permission-gate.md`.

**For Architect — follow-up probe (non-blocking).** To resolve sub-question (d): ship a tiny non-fork plugin skill (e.g., `meta-matrix-noop-probe`), reference it from `skill-invocation`'s `allowed-tools`, invoke in a fresh workspace. If it prompts → "any new skill" is the rule. If silent → `context: fork` is the trigger. Alternatively, re-test build→arch in a freshly-cloned workspace where `.claude/settings.local.json` is empty.

**For Architect — sub-question (d) gains a model-conditional axis (addendum 2026-05-14).** Two `/jim:meta-matrix skill-invocation` reruns in the same workspace (`/workspaces/korswerk`), both fresh sessions, produced divergent consent-prompt behavior — Sonnet 4.6 ran the `Skill(jim:meta-matrix-fork-probe)` call silently while Opus 4.7 fired the standard "Use skill 'X'?" prompt. The persistence-option text ("Yes, don't ask again for jim:meta-matrix-fork-probe in `/workspaces/korswerk`") implies workspace-scoped acceptance keyed on (skill, workspace), but the empirical divergence suggests one of:

1. The rule is actually keyed on (skill, workspace, **model**) rather than (skill, workspace) — so accepting once on Opus does not propagate to Sonnet, and vice versa.
2. The Sonnet runtime has a different consent-gate evaluation than Opus — possibly auto-bypassing for some class of skills.
3. Per-model workspace settings files (`.claude/settings.local.json` variants) accumulate differently — unconfirmed; the docs don't describe a per-model settings split.

Captured by `docs/specs/jim/014-meta-matrix/plan.md` Verification Log § "Post-refinement cross-model retest — 2026-05-14". The original follow-up probe shape (ship a non-fork plugin skill in a fresh workspace) should be **extended to test cross-model behavior in the same workspace**: invoke the new probe on Sonnet first, observe; invoke on Opus second, observe. If both prompt → simple workspace-scoped (any new skill). If Sonnet silent + Opus prompts → confirms the model-conditional axis. If both silent → `context: fork` is the trigger and the model-conditional reading was a workspace-state artifact. Three outcomes, one rerun.

**For PM — no spec invalidation.** Spec 014's ACs are unaffected; the skill-invocation S4 row already warns users about the consent prompt (`skills/meta-matrix-skill-invocation/SKILL.md:48`). Closing 014's Open Question with this research's findings fits in the same bundled PR.
