---
spec: "standalone"
status: Active
date: "2026-05-12"
---

# Research: 001-meta Skill-Invocation Freshness Audit

Validates the claims about **skill invocation, same-agent vs subagent execution, and the `agent:`/`Agent` mechanics** in `docs/specs/jim/001-meta/research.md` and `plan.md` against the current Claude Code docs (`code.claude.com/docs/en/skills`, `.../sub-agents`, fetched 2026-05-12). Question driving the audit: has Claude Code changed since 001-meta was written, and does the current `@jim:meta` design rest on anything that's now wrong?

**Verdict:** 001-meta's load-bearing claims are **all still correct**. No invalidation. Several additive deltas exist (new frontmatter fields, the `Skill` tool naming, the Task → Agent rename, a 5-tier agent priority table) that don't break 001-meta but should be reflected if/when meta's validation checklist is extended.

## Anchors

- `docs/specs/jim/001-meta/research.md:24-119` — 001-meta's summary of Claude Code skill + sub-agent mechanics. This is the surface being audited.
- `docs/specs/jim/001-meta/plan.md:49-118` — Design decisions (esp. #5 Agent-tool delegation, #6 `agent:` documentation-only, #8 self-contained agent body).
- `agents/meta.md:37-38` — Current frontmatter: `tools: [Agent(pm, architect, researcher), Read, Write, Edit, Glob, Grep]`, `skills: [meta-skill, meta-agent, meta-test]`. Both shapes are still spec-compliant.
- `skills/meta-skill/SKILL.md:17` and `skills/meta-agent/SKILL.md:17` — Both files carry the documentation-only `agent: meta` disclaimer. Still accurate.
- `ARCHITECTURE.md:239` — Already states `agent:` is jim-only and only native when paired with `context: fork`. Aligned with current docs.

## Local Patterns

No local pattern check applies — this is a doc-vs-doc audit, not an implementation task. No test template needed.

## Prior Art

Two canonical sources fetched 2026-05-12:

| File | What It Is | Why It Matters |
|------|------------|----------------|
| `code.claude.com/docs/en/skills` | Current Claude Code skills reference | Authoritative source for skill frontmatter, the `Skill` tool, `context: fork`, and skill-content lifecycle. |
| `code.claude.com/docs/en/sub-agents` | Current sub-agents reference | Authoritative source for agent frontmatter, `Agent(...)` syntax, model defaults, the `skills:` preload field, and the subagents-cannot-nest rule. |

## Claim-by-claim audit

**Confirmed still true (load-bearing):**

1. *"Skill `description` always in context; full body loads on invocation."* — Still true; docs add nuance (combined `description` + `when_to_use` capped at 1,536 chars; total listing capped at ~1% context window by default).
2. *"`context: fork` + `agent:` runs the skill in an isolated subagent — the skill content becomes the task prompt."* — Still true; current docs add a warning that fork only makes sense for skills with explicit instructions.
3. *"Agent `model` defaults to `inherit`, not `sonnet`."* — Still true verbatim.
4. *"Agent markdown body = full system prompt; agents do NOT inherit Claude Code's system prompt."* — Still true verbatim.
5. *"`skills:` field on agents preloads full skill content at startup."* — Still true.
6. *"Subagents cannot nest (parent → child only, no grandchildren)."* — Still true and now stated explicitly twice in the sub-agents doc.
7. *"`agent:` field in skill frontmatter is documentation-only outside `context: fork`."* — Still true. Docs only define `agent:` as "Which subagent type to use when `context: fork` is set."
8. *"`Agent(name1, name2)` in `tools` restricts which subagents can be spawned."* — Still true. Docs add an important constraint: **this restriction only applies when the agent runs as the main thread via `claude --agent`**. In ordinary subagent definitions, `Agent(...)` has no effect because subagents can't spawn anyway.

**Renamed / no behavior change:**

- *Task tool → Agent tool* (v2.1.63). 001-meta's `Agent(...)` terminology is current; old `Task(...)` references still work as an alias.

**Additive — not in 001-meta but harmless to its design:**

- The **`Skill` tool** is now the named mechanism for in-conversation skill invocation. 001-meta describes the behavior ("description triggers, body loads") but doesn't name the tool. Permission rules use `Skill(name)` / `Skill(name *)` syntax.
- **Subagents can invoke skills via the `Skill` tool**, not only preloaded ones. The `skills:` field controls preloading; absence of a skill from `skills:` does not block discovery. To block, omit `Skill` from `tools` or add it to `disallowedTools`. This is the answer to the user's "same-agent vs subagent execution" question — see below.
- **Agent priority table now has 5 tiers** (Managed > `--agents` CLI > project > user > plugin), not 4. Plugin is still lowest. 001-meta's relative ordering is correct.
- **New skill frontmatter fields:** `when_to_use`, `arguments` (named positional), `paths` (auto-activation glob), `shell` (bash/powershell), `effort`, `model` (per-skill override).
- **New agent frontmatter fields:** `initialPrompt`, `color`. Existing fields unchanged.
- **Fork-mode subagents** (`/fork`, `CLAUDE_CODE_FORK_SUBAGENT=1`, experimental) — a subagent that inherits the full parent conversation. Different from `context: fork` on skills. Forks also cannot spawn further forks.

## Same-agent vs subagent execution — current rules

Four invocation paths, all confirmed by the 2026-05-12 docs:

| Path | Where it runs | What it sees |
|------|---------------|--------------|
| `/skill-name` or auto-trigger (Skill tool) | **Main conversation** | Full convo history + skill body loaded as one message, stays for the session |
| Skill with `context: fork` + `agent: X` | **Subagent X** | Agent X's system prompt; skill body becomes the task prompt; no parent history |
| Subagent with `skills: [...]` preloaded | **Subagent's own context** | Subagent body + full preloaded skill content injected at startup |
| Subagent invoking `Skill` tool mid-run | **Same subagent** | Adds the skill body to the subagent's existing context |

**`$ARGUMENTS` propagation through the Skill tool (empirical, 2026-05-13).** When any parent (skill in main conversation, or subagent) calls `Skill(<child-name>)` via the Skill tool without an explicit args parameter, the child's `$ARGUMENTS` is the **empty string** — the parent's `$ARGUMENTS` does **not** auto-forward. To forward, pass it explicitly via the Skill tool's args parameter. Established by spec 014's S3 probe (`docs/specs/jim/014-meta-matrix/plan.md` → Verification Log, row S3); the dispatcher (`skills/meta-matrix/SKILL.md`) called `Skill(jim:meta-matrix-skill-invocation)` and the child sub-skill rendered `SUBST_SKILL_ARGS_PROPAGATE` with no value following.

**Path 2 (`context: fork`) and path 3 (`skills:` preload) — mechanics and substitution (empirical, 2026-05-13, second rerun on Opus 4.7 `[1m]`).** Spec 014's S4 and S5 probes establish three settled facts via the dual-sentinel design (`SUBST_SKILL_PATH*_LITERAL` bare control + `SUBST_SKILL_PATH*_THRU_INJECTION` `!`-injection test):

1. **Both subagent paths fire.** `Skill(jim:meta-matrix-fork-probe)` (path-2 harness with `context: fork` + `agent: meta-matrix-probe`) spawned a forked subagent and returned its task-prompt sentinels; `Agent(meta-matrix-probe)` (path-3 harness whose agent definition carries `skills: [meta-matrix-preload-probe]`) spawned the probe subagent and returned its preloaded sentinels. Neither harness reported "mechanism unsupported."
2. **`!`-injection substitution fires end-to-end on subagent-bound skill bodies.** Both LITERAL controls and THRU_INJECTION tests arrived as bare strings in the parent's tool results — confirming both that the harness delivered the body (LITERAL present) and that `!`-injection ran somewhere along the parent → Skill-tool / Agent-tool → fork-handoff / preload-injection → subagent-startup chain (THRU_INJECTION substituted, not in its literal `` !`echo …` `` form). The single-sentinel first rerun could not distinguish "harness fired but substitution didn't" from "both fired"; the dual-sentinel design closed that gap.
3. **Model headers agree across the chain when the probe inherits.** With `agents/meta-matrix-probe.md` omitting `model:`, the dispatcher, sub-skill body, S4 forked subagent, and S5 probe subagent all report `claude-opus-4-7[1m]` (the parent's active model). The first rerun's Sonnet/Opus split (probe pinned to Sonnet) is gone. Cosmetic only: the forked subagent reports `MODEL_NAME: Claude Opus 4.7 (1M context)` with a "Claude " prefix that the other contexts omit — model ID is the load-bearing field and matches across all four.

**Platform finding (new, 2026-05-13 second rerun) — `Skill(name)` permission tokens do NOT auto-approve invocations of skills with `context: fork` frontmatter.** Despite `skill-invocation`'s `allowed-tools` declaring `Skill(jim:meta-matrix-fork-probe)`, the second rerun observed an explicit "Use skill 'jim:meta-matrix-fork-probe'?" consent prompt the first time the token fired. The parallel `Agent(meta-matrix-probe)` call (also declared in `allowed-tools`) ran silently. This contradicts ARCHITECTURE.md:242's claim that "the caller's allowed-tools covers nested tool calls inside the invoked skill" — though that claim was established against the build→arch precedent, where neither caller nor callee uses `context: fork`. Hypothesis: Claude Code applies an additional consent gate to skills that fork to a subagent, on top of the `Skill(name)` permission token, because forking spawns a fresh execution context with its own agent-system-prompt and broader implications than loading a skill body into the current context. Captured as an Open Question in `docs/specs/jim/014-meta-matrix/plan.md` ("Permission prompt for `context: fork` skills") — clarification needed against current Claude Code docs before ARCHITECTURE.md:242 can be amended with a fork-skill caveat.

Established by spec 014's S4 and S5 probes (`docs/specs/jim/014-meta-matrix/plan.md` → Verification Log rows S4–S5, 2026-05-13 first rerun on Opus 4.7 `[1m]` confirmed harness mechanics + single-sentinel substitution-fires reading; 2026-05-13 second rerun post-refinement confirmed end-to-end substitution via dual-sentinel and surfaced the `context: fork` permission gate).

**Cross-model subagent-inference divergence (empirical, 2026-05-14).** Same dual-sentinel design, two parent models, **same substrate sentinel readings but divergent subagent inference**: an Opus 4.7 subagent applies the LITERAL × THRU_INJECTION rubric correctly (reports `Inferred: substitution fired` when both slots show bare sentinels); a Sonnet 4.6 subagent inverts the inference on the THRU slot (reports `Inferred: did not fire` for the same readings). The Sonnet main-thread reader caught and overrode the wrong inference in the final report, so the user-visible matrix output was correct on both models — but only via main-thread compensation on Sonnet. The substrate findings (paths 2 and 3 fire `!`-injection end-to-end) are model-independent; the divergence is in the probe rubric's *readability* across models. Diagnosis: semantic-reversal trap — the previous rubric ("Both bare strings present → fired") relied on the reader knowing that bare THRU_INJECTION text is *produced by* `!`-injection running, which a Sonnet-shaped reader can flip to "bare text visible, no transformation evidence, therefore nothing happened." The rubric was sharpened on 2026-05-14 in `agents/meta-matrix-probe.md` plus the two helper skills (`skills/meta-matrix-fork-probe/SKILL.md`, `skills/meta-matrix-preload-probe/SKILL.md`) with explicit per-slot reading instructions and a mnemonic ("Bare text in THRU = `echo` ran. Backticked text in THRU = `echo` did NOT run."). This is also a useful side-finding: the matrix's secondary value is cross-model reasoning characterization on the same probe data — different models can produce different reports for the same input, and the matrix surfaces it. See `docs/specs/jim/014-meta-matrix/plan.md` Verification Log § "Cross-model rerun (Sonnet 4.6) — 2026-05-14" and Design Decision 11 § Refinement / Rubric clarity refinement (2026-05-14) for the decision record. **Post-refinement retest (2026-05-14):** the asymmetry **partially closed** — S5 (Sonnet, `skills:` preload) now matches Opus and reports `substitution fired`, but S4 (Sonnet, `context: fork`) still misinfers `did not fire`. Likely cause is a position effect within the fork-probe body (sentinels appear before the rubric); restructuring is deferred. The main-thread reading is authoritative and correct on both rows under both models. See plan Verification Log § "Post-refinement cross-model retest — 2026-05-14" for the empirical readings.

**Implication for `@jim:meta`:** the existing design uses paths 1 and 3 — user invokes `/jim:meta-skill` in the main conversation; `@jim:meta` is spawned with `skills: [meta-skill, meta-agent, meta-test]` preloaded. This is supported and idiomatic. Nothing in the current shape needs changing.

## Security & Performance

- **No new attack surface.** The `agent:` documentation-only convention is still safe — Claude Code ignores the field outside `context: fork`, so a malicious value cannot misroute.
- **Skill listing budget** is a soft performance signal: if jim's skill count grows past the 1% context-window cap, lower-priority skill descriptions get silently truncated. Mitigable via `skillListingBudgetFraction` or by marking rarely-used skills `"name-only"` in `skillOverrides`. Not urgent today.
- **Compaction caveat for skills:** after auto-compaction, only the first 5,000 tokens of each re-attached skill survive (combined 25,000 token budget across all skills). Long jim skill bodies could be silently truncated mid-session. None of jim's current skills are close to this limit.

## Recommendations

1. **Do not edit `001-meta/research.md`.** Its load-bearing claims still match the current docs verbatim. A retroactive rewrite would obscure the historical decision context.
2. **Optional follow-up — extend meta's checklist** if/when the new frontmatter fields become relevant to jim: `when_to_use` (description supplement), `paths` (auto-activation guard), `arguments` (named positional). Today nothing in jim uses them, so the checklist gap is theoretical.
3. **Optional follow-up — note the `Skill` tool by name** in `ARCHITECTURE.md` → Plugin Conventions, since current docs name it explicitly and permission rules reference `Skill(name)`.

## Alignment

- **VISION.md:** No skill-invocation claims; nothing to verify.
- **ARCHITECTURE.md** (lines 237–252): Already aligned with current docs — explicitly states `agent:` is jim-only and only native when paired with `context: fork`, and that `Agent(name1, name2)` restricts spawning. Nothing in ARCHITECTURE.md is invalidated.

## Peer Feedback

None. No spec or plan invalidation surfaced. The two follow-ups above are optional polish, not blockers.
