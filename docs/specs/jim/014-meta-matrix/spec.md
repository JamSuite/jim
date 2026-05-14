---
title: "Promote meta-matrix to a top-level plugin skill with selectable categories"
type: feature
group: "jim"
id: "014"
status: approved
origin:
  - "docs/research/20260512-001-meta-skill-invocation-freshness.md"
  - "docs/specs/jim/011-directive-vocabulary/spec.md"
  - ".claude/skills/meta-matrix/SKILL.md"
---

# 014 Promote meta-matrix to a top-level plugin skill with selectable categories

## Overview
Promote the `meta-matrix` sentinel-row fixture from the project-local `.claude/skills/meta-matrix/` (introduced by spec 011) to a top-level `/jim:meta-matrix` plugin skill that any jim user can invoke to probe Claude Code's runtime behavior, and reorganize it as a dispatcher + four category sub-skills so future behavior investigations can be probed selectively without loading every sentinel on every invocation.

## Problem Statement

Today, jim's only manual Claude Code behavior probe lives at `.claude/skills/meta-matrix/SKILL.md` — a project-local fixture built for spec 011's `!`-injection investigation. Two pains result:

- **Not shipped with the plugin.** Jim users who install the plugin in their own projects have no way to invoke meta-matrix; the fixture only exists in the jim repo. A jim user troubleshooting unexpected Claude Code behavior in their own project (e.g., "did my SKILL.md's `!`-injection substitute?") has to read the source of jim's `.claude/` directory or hand-build their own fixture.
- **Monolithic and single-purpose.** All 32 sentinel rows (A–FF) live in one body covering bash-substitution wrappers, the directive vocabulary, the lean IF form, and empty-substitution no-ops. Every invocation loads everything. Adding a new probe surface — e.g., the skill-invocation behaviors documented in `docs/research/20260512-001-meta-skill-invocation-freshness.md` — means appending to one growing file. There is no way to ask "just show me bash-substitution behavior" without loading the directive-vocabulary rows too, and vice versa.

The user pain is that meta-matrix is the right tool for diagnosing "why did Claude Code do X?" but is currently locked to one investigation and one repo.

## User Stories

- As a **jim user** troubleshooting their own Claude Code behavior, I can invoke `/jim:meta-matrix bash-invocation` in my project to see which `!`-injection wrapper patterns substitute and which don't, without loading directive-vocabulary or skill-invocation probes I don't care about.
- As a **jim user** investigating broader behavior, I can invoke `/jim:meta-matrix` with no argument and have the dispatcher chain every category sub-skill so I see the full picture in one session.
- As a **jim contributor** investigating a new Claude Code behavior, I can add a new `meta-matrix-<category>` sub-skill alongside the existing four, and the dispatcher picks it up via the same selection mechanism.
- As a **jim contributor** maintaining the directive vocabulary, I can probe variable-setting behavior independently of conditional-evaluation behavior so a regression in one doesn't drag the other into context.

## Acceptance Criteria

**Skill family delivered**
- [ ] `/jim:meta-matrix` dispatcher skill exists at `skills/meta-matrix/SKILL.md` with frontmatter `name: meta-matrix`, an `argument-hint`, and `allowed-tools` granting four enumerated `Skill(jim:meta-matrix-<category>)` tokens (one per sub-skill: `bash-invocation`, `variable-setting`, `conditional-evaluation`, `skill-invocation`). *(Amended 2026-05-13 — realized as four explicit tokens per plan Design Decision 1; no documented prefix-glob form in Claude Code permission syntax, so an enumerated list matches both the docs and the only existing jim precedent at `skills/build/SKILL.md:10`. Tokens including `Skill(jim:meta-matrix-bash-invocation)` etc.)*
- [ ] Four category sub-skills exist as siblings, each in its own directory:
  - `skills/meta-matrix-bash-invocation/SKILL.md`
  - `skills/meta-matrix-variable-setting/SKILL.md`
  - `skills/meta-matrix-conditional-evaluation/SKILL.md`
  - `skills/meta-matrix-skill-invocation/SKILL.md`
- [ ] Each sub-skill's `description` field clearly states what behaviors it probes, so a user reading `/jim:` autocomplete can choose without loading bodies.

**Dispatcher behavior**
- [ ] `/jim:meta-matrix` (no argument) chains all four category sub-skills via the Skill tool. The rendered conversation shows every sentinel from every category.
- [ ] `/jim:meta-matrix <category>` loads only the matching sub-skill via `Skill(jim:meta-matrix-<category>)`. Only that category's sentinels appear in the rendered body.
- [ ] `/jim:meta-matrix <unknown>` does not silently chain everything — the dispatcher detects an unknown category, lists the valid set, and stops.
- [ ] Category names accepted by the dispatcher: `bash-invocation`, `variable-setting`, `conditional-evaluation`, `skill-invocation`. Match is exact-string (no fuzzy / no prefix).

**Migration from the 011 project-local fixture (sentinel rows)**
- [ ] Rows A–T (current `.claude/skills/meta-matrix/SKILL.md` lines 22–109) migrate to `skills/meta-matrix-bash-invocation/SKILL.md` verbatim — sentinel strings preserved so existing references in `docs/debug/20260512-skill-bash-substitution-wrappers.md` and spec 011 remain valid.
- [ ] Row W (SET assignment) migrates to `skills/meta-matrix-variable-setting/SKILL.md` along with at least one new SET-only probe that verifies substitution into a SET line without an accompanying IF.
- [ ] Rows U, V, X, Y, Z (retired single-line `*_IF_EXISTS` directives — forensic), rows AA, BB (lean IF chains), rows CC–FF (historical empty-substitution no-op probes — preserved as forensic record per the fixture's own annotation; no longer load-bearing after the 2026-05-13 spec 011 amendment retired the EXISTS-family vocabulary), and **rows GG, HH (canonical post-amendment sentinel form: `SET <name> = !`bash …`` + `IF <name> != "NOT_FOUND" THEN … ELSE … ENDIF`; GG covers the negative case where SET binds to `NOT_FOUND`, HH covers the positive case)** migrate to `skills/meta-matrix-conditional-evaluation/SKILL.md`. The SET assignments embedded in AA/BB/FF/GG/HH travel with the IF rows since the probe target is the branch behavior, not the SET itself. (Amended 2026-05-13 to add GG/HH and reframe CC–FF after the fixture grew the post-amendment rows; in-place amend, precedent `abd85b1`.)
- [ ] No sentinel row from the current 011 fixture is dropped during migration. (Renames for category-namespacing are allowed — see Open Questions.)

**New skill-invocation category (per 001-freshness research)** *(Amended 2026-05-13 — subagent-side probes folded into this category rather than deferred to a follow-up spec. Path-2 and path-3 harnesses live as internal sibling skills + one probe agent, all internal to the meta-matrix family. See plan File Manifest tasks 5a/5b/5c/5d for the file shape and research § "Subagent-probe harness" for the design rationale.)* *(Refined 2026-05-13 post-rerun — S4 and S5 probes use a dual-sentinel design (LITERAL + THRU_INJECTION per row) to disambiguate substitution-tier; the probe subagent omits `model:` so it inherits the parent's active model. See plan Design Decision 11 § Refinement.)*
- [ ] `skills/meta-matrix-skill-invocation/SKILL.md` contains at minimum one probe for **each of the four invocation paths** from `docs/research/20260512-001-meta-skill-invocation-freshness.md` § "Same-agent vs subagent execution":
  - Direct `/skill-name` invocation in main conversation (**path 1** — row S1).
  - Skill tool invocation mid-run from the same context (**path 4** — row S2).
  - `context: fork` subagent invocation (**path 2** — row S4). Invoked by calling `Skill(jim:meta-matrix-fork-probe)` from row S4; the fork-probe skill's frontmatter (`context: fork` + `agent: meta-matrix-probe`) triggers a forked subagent whose final message returns as the Skill tool result. The fork-probe body uses a **dual-sentinel design** — one bare literal (`SUBST_SKILL_PATH2_FORK_LITERAL`, control) plus one through `!`-injection (`!`echo SUBST_SKILL_PATH2_FORK_THRU_INJECTION``, test) — so the comparison between the two readings empirically pins down whether `!`-injection substitution fired on the path-2 chain or the body passed through verbatim.
  - `skills:` preload subagent invocation (**path 3** — row S5). Invoked by calling `Agent(meta-matrix-probe)` from row S5; the probe agent's `skills: [meta-matrix-preload-probe]` field preloads the preload-probe body into its startup context. The preload-probe body also uses the **dual-sentinel design** (`SUBST_SKILL_PATH3_PRELOAD_LITERAL` + `!`echo SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION``), reported back as the Agent tool result, so the path-3 substitution-tier reading is independent of S4's.
  - ARGUMENTS propagation through the Skill tool when this sub-skill is loaded via the dispatcher (**S3** — `$ARGUMENTS` in the sub-skill body). *(Amended 2026-05-13 — rescoped per plan Design Decision 2 from "`$ARGUMENTS` substitution into the loaded body": direct `$ARGUMENTS` substitution is documented and trivially working; the propagation question — whether `Skill(jim:meta-matrix-skill-invocation FOO)` makes `$ARGUMENTS == "FOO"` in the sub-skill — is the open empirical question worth probing.)*
- [ ] Each probe carries a unique `SUBST_*` sentinel and a one-line interpretation note in the same style as the existing matrix rows. The plan chooses the specific row designs; the spec only requires coverage of the five rows above. *(Refined 2026-05-13 — for rows S4 and S5 specifically, each row carries a *pair* of sentinels per the dual-sentinel design; the interpretation note describes the 4-cell rubric (substitution fired / did not fire / harness failure / unexpected) over LITERAL × THRU_INJECTION readings.)*
- [ ] **Harness files exist as siblings of the four category sub-skills:**
  - `agents/meta-matrix-probe.md` — minimal probe subagent. `skills: [meta-matrix-preload-probe]`, `tools: [Bash(echo *), Bash(bash -c *)]`. The `model:` field is **omitted** so the probe inherits the parent conversation's active model — pinning to a specific model would mask model-specific runtime behavior, which is the very signal the meta-matrix is built to surface. *(Refined 2026-05-13 from the original `model: sonnet` requirement; rationale in plan Design Decision 11 § Refinement / Model pinning sub-decision.)* Spawned only by `meta-matrix-skill-invocation` row S5 (via `Agent(meta-matrix-probe)`) and by `meta-matrix-fork-probe` (via `context: fork`).
  - `skills/meta-matrix-fork-probe/SKILL.md` — path-2 harness. Frontmatter `context: fork` + `agent: meta-matrix-probe`; body holds the dual-sentinel pair `SUBST_SKILL_PATH2_FORK_LITERAL` and `!`echo SUBST_SKILL_PATH2_FORK_THRU_INJECTION``. `description` field marks it as internal harness, not for direct user invocation.
  - `skills/meta-matrix-preload-probe/SKILL.md` — path-3 harness. Body holds the dual-sentinel pair `SUBST_SKILL_PATH3_PRELOAD_LITERAL` and `!`echo SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION``; injected into `meta-matrix-probe`'s startup context via the agent's `skills:` field. `description` field marks it as internal harness.
- [ ] `skills/meta-matrix-skill-invocation/SKILL.md` `allowed-tools` is expanded to include `Skill(jim:meta-matrix-fork-probe)` and `Agent(meta-matrix-probe)` alongside the existing `Bash(echo *)` and `Bash(bash -c *)` tokens. Dispatcher `allowed-tools` is unchanged (the harness skills are not categories — they are invoked transitively by skill-invocation).

**Retire the project-local fixture**
- [ ] `.claude/skills/meta-matrix/` is removed after migration. Alternative: a 3-line stub `SKILL.md` is acceptable if the user later wants to keep the path resolvable, but the default is full removal since the top-level skill replaces it.

**011 in-place amend (path and location references only)**
- [ ] `docs/specs/jim/011-directive-vocabulary/spec.md` ACs that reference `.claude/skills/subtest/ → .claude/skills/meta-matrix/` are amended in place to point at `skills/meta-matrix-*/` (top-level). The behavioral ACs of 011 (sentinel migrations U–Z, lean control flow, empty-substitution behavior) are unchanged — only their *home* changes.
- [ ] A short "Sentinel fixture relocated by spec 014" annotation is added to 011's regression-matrix AC block. 011's status is not reopened (in-place amend precedent: commit `abd85b1` for specs 008/009).
- [ ] `docs/specs/jim/011-directive-vocabulary/plan.md` and `research.md` (if either references `.claude/skills/meta-matrix/`) are similarly amended in place. Body of the historical record preserved otherwise.

**Brainstorm and ARCHITECTURE.md annotation**
- [ ] `docs/brainstorms/20260505-file-resolver-conventions-audit.md`, any other brainstorm under `docs/brainstorms/`, **and any non-014 spec under `docs/specs/jim/`** (e.g., `012-allowed-tools-narrowing/`) that mentions `.claude/skills/meta-matrix/` or `.claude/skills/subtest/` carries a one-line "Sentinel fixture location updated by spec 014 — see `skills/meta-matrix/`" annotation near the reference. Body preserved verbatim (historical-annotation hygiene, mirroring 011's own pattern). Bare `meta-matrix` references (no `.claude/skills/` prefix) are annotated when co-located with full-path references or when the surrounding paragraph reads as a single defect/decision discussion. (Amended 2026-05-13 per cross-check audit; precedent for cross-spec annotation is plan Task 12c.)
- [ ] `ARCHITECTURE.md` → Substitution Conventions: the line referencing `.claude/skills/meta-matrix/` is updated to point at the new top-level `skills/meta-matrix/` family. The "quit and relaunch Claude Code from the repo root" guidance is preserved.

**Original 011 repro still clears**
- [ ] After migration, launching `/jim:meta-matrix bash-invocation` in a fresh Claude Code session resolves all `!`-injection sentinels in the loaded body to their `SUBST_*` strings for the rows that should substitute (A, B, E, F, R, S, etc.) and leaves the literal `` !`echo SUBST_*` `` text for the rows that should be suppressed (C, D, N, O, P).
- [ ] Equivalent spot-check passes for `/jim:meta-matrix conditional-evaluation` against rows U–Z, AA, BB, CC–FF, **GG, HH** — matching the dated results recorded by spec 011's matrix run (post-2026-05-13 amendment). GG/HH are the load-bearing post-amendment sentinel-form rows; CC–FF are informational/forensic per the fixture's HISTORICAL annotation. (Amended 2026-05-13 to add GG/HH per the cross-check audit; precedent `5d143d5`.)
- [ ] Spot-check passes for `/jim:meta-matrix skill-invocation` against rows S1, S2, S3, **S4, S5** — the subagent-side rows S4 (path 2) and S5 (path 3) surface their sentinels in the returned Skill / Agent tool results, not directly in the parent's rendered body. Under the dual-sentinel design, AC-passing means: the probe agent's report contains a `Row S4` and `Row S5` block with LITERAL and THRU_INJECTION slots filled (bare-string, literal `` !`echo …` ``, or `ABSENT`) plus a one-sentence `Inferred:` finding. The empirical reading itself ("fired" / "didn't fire" / "harness failure" / "unexpected") is the probe output, not the AC bar — what matters for the AC is that the harness fires and the report block lands. *(Added 2026-05-13 — subagent-side probes folded in; refined 2026-05-13 post-first-rerun to the dual-sentinel design. See plan Verification Log for the actual readings.)*

**Model attribution in rendered output** *(Added 2026-05-13 amendment — meta-matrix probe results need to be attributable to a specific Claude model so cross-model comparisons can be made from the rendered transcript alone. See research.md § "Model attribution mechanism" for the alternatives investigated and rejected.)*
- [ ] Each meta-matrix sub-skill SKILL.md body opens its rendered output with a two-line metadata header — `MODEL_NAME: <name>` and `MODEL_ID: <id>` — read verbatim from the assistant's system prompt (the `"You are powered by the model named X. The exact model ID is Y"` line that Claude Code injects at session start).
- [ ] The dispatcher SKILL.md (`skills/meta-matrix/SKILL.md`) carries an equivalent two-line header in its preamble, rendered before the first `Skill(...)` call fires. Net: chain-all renders 5 headers (1 dispatcher + 4 sub-skills); single-category dispatch renders 2; direct sub-skill invocation renders 1; unknown-category stop renders 1 (dispatcher only).
- [ ] When multiple headers render in one transcript (chain-all, single-category dispatch), they should all agree on the same `MODEL_NAME` / `MODEL_ID`. A discrepancy is a useful integrity signal (mid-session model swap) and is not an error condition.
- [ ] If the assistant cannot locate the identifier in its system prompt (e.g., a runtime that doesn't inject the line), it emits `MODEL_NAME: unknown` / `MODEL_ID: unknown` rather than guessing or hallucinating an ID. Graceful degradation, not a probe.
- [ ] **Subagent-side path-2 / path-3 harnesses** (`skills/meta-matrix-fork-probe/`, `skills/meta-matrix-preload-probe/`, and the driving `agents/meta-matrix-probe.md`) emit the model header as the first two lines of the subagent's final message, which surfaces in the parent transcript as the S4 / S5 Skill / Agent tool result. The subagent is pinned to `model: sonnet` per `agents/meta-matrix-probe.md` frontmatter, so a parent running on Opus or Haiku will see two distinct headers (parent + subagent) for the path-2 / path-3 rows — an informative cross-agent integrity signal showing which model handled the subagent-side probes. *(Added 2026-05-13 — harness extension, picked up after fork-probe / preload-probe landed mid-amendment.)*
- [ ] Probing self-report reliability (does the model echo verbatim or paraphrase? do smaller models comply less reliably?) is **out of scope** for this amendment — listed in Out of Scope so a future spec can add a `meta-matrix-skill-invocation` sentinel row (e.g., `SUBST_SKILL_MODEL_SELFREPORT`) if reliability becomes a question.

**Delivery shape**
- [ ] Skill family creation, sentinel migration, fixture retirement, 011 amend, brainstorm annotations, and ARCHITECTURE.md update land in one bundled PR (internal commits may separate structural moves from behavioral changes per Tidy First). No partial rollout — the project-local fixture and the top-level skill family should not both exist after merge.

## UI Mockup

```
$ /jim:meta-matrix
  -> loads dispatcher
  -> dispatcher Skill(jim:meta-matrix-bash-invocation)
  -> dispatcher Skill(jim:meta-matrix-variable-setting)
  -> dispatcher Skill(jim:meta-matrix-conditional-evaluation)
  -> dispatcher Skill(jim:meta-matrix-skill-invocation)
User reads rendered body for SUBST_* sentinels across all four categories.

$ /jim:meta-matrix bash-invocation
  -> loads dispatcher
  -> dispatcher Skill(jim:meta-matrix-bash-invocation)
Only A–T sentinels render.

$ /jim:meta-matrix not-a-real-category
  -> loads dispatcher
  -> dispatcher prints:
       Unknown category 'not-a-real-category'.
       Valid: bash-invocation, variable-setting,
              conditional-evaluation, skill-invocation.
  -> stops.
```

## Out of Scope

- **Automated regression / CI integration.** meta-matrix is a manual diagnostic — the "test result" is the human-readable rendered body. No bash assertions, no automated pass/fail. (This boundary matches the 011 design and is reinforced by the spec 011 § "Regression matrix" rationale.)
- **Probing recursive `!`-injection substitution** (e.g., whether ``!`cat fragment.md` `` re-scans its output for further `!`-injection slots). Worth investigating as a future spec — it would enable a single-skill-with-fragments architecture — but not in scope here.
- ~~**Subagent-side probes** for `skills:` preload or `context: fork` invocation paths. These need a different harness (spawn a subagent with a preloaded probe skill, read its output back). Deferred to a follow-up spec.~~ *(Resolved 2026-05-13 — folded into the New skill-invocation category AC block above. Path-2 (`context: fork`) is covered by row S4 via `skills/meta-matrix-fork-probe/`; path-3 (`skills:` preload) is covered by row S5 via `agents/meta-matrix-probe.md` + `skills/meta-matrix-preload-probe/`. No follow-up spec needed.)*
- **Re-litigating 011's substantive ACs.** This spec only updates path/location references in 011 and its companions. Behavioral ACs (which rows substitute, what the directive vocabulary covers, the lean-IF form) remain unchanged. If a 011 AC is found to need behavioral revision, it is a separate spec.
- **Changes to `meta-test`, `meta-skill`, or `meta-agent`.** Those are sibling meta-* skills with distinct responsibilities. meta-matrix is a manual debug probe; the other three are author-time scaffolding/validation.
- **A `Skill` permission token for non-meta-matrix skills** in the dispatcher. The dispatcher needs only `Skill(jim:meta-matrix-*)` — least privilege.
- **Migrating any sentinel row from `.claude/skills/meta-matrix/` to plain prose or another skill not in the meta-matrix family.** All current rows belong to one of the four categories above; the migration is a clean repartition, not a redistribution across the plugin.
- **Probing self-report reliability of the MODEL_NAME / MODEL_ID header** itself. The Model-attribution AC block above requires the report; whether the model surfaces it verbatim vs. paraphrases vs. hallucinates is a separate probe-shaped question worthy of a follow-up `SUBST_SKILL_MODEL_SELFREPORT` sentinel row. Not included here so the report-vs-probe boundary stays clean. *(Added 2026-05-13.)*

## Open Questions

- [ ] **Sentinel namespacing during migration.** Current sentinels use a flat `SUBST_<row>_<descriptor>` namespace (e.g., `SUBST_A_BARE_LINE`). When rows split across four sub-skills, should sentinels be re-namespaced (e.g., `SUBST_BASH_A_BARE_LINE`, `SUBST_VAR_W_SET_ASSIGN`, `SUBST_COND_AA_PATH`) to keep collisions and category-attribution obvious, or preserved verbatim to keep existing `docs/debug/20260512-skill-bash-substitution-wrappers.md` references intact? Plan to decide; one option is "keep existing, namespace any *new* rows by category."
- [ ] **Dispatcher arity for the chain-all case.** When `/jim:meta-matrix` is invoked with no argument, does the dispatcher issue all four `Skill(...)` calls in one tool-call batch (parallel), or sequentially? Parallel is faster but the rendered context order matters for human readability of the matrix. Plan to decide.
- [x] ~~**Where does the skill-invocation matrix's subagent-side probe set live** if/when a follow-up spec adds it? A fifth sub-skill (`meta-matrix-subagent-invocation`) or a sibling category? Out of scope for 014 but worth noting so the naming pattern is forward-compatible.~~ → *Resolved 2026-05-13: folded into `meta-matrix-skill-invocation` as rows S4 (path 2) and S5 (path 3), with three internal harness files (`agents/meta-matrix-probe.md`, `skills/meta-matrix-fork-probe/`, `skills/meta-matrix-preload-probe/`). A fifth `meta-matrix-subagent-invocation` category is not needed; the four-category dispatcher fan-out is unchanged.*
- [ ] **Should the dispatcher's "unknown category" error message be machine-readable** (e.g., exit-1-style) or purely human-readable prose? meta-matrix is human-driven so prose is fine, but if any future automation wraps it, structured output would help. Default: prose.
