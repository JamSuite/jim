---
id: 20260717-external-research-refresh
num: 79
title: "Automate the external-research refresh as a jim skill"
status: open
priority: high
labels: [skill, research, prior-art, workflow, meta]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-17T22:09:46Z
updated: 2026-07-24T11:27:11Z
origin: docs/research/20260717-competitive-landscape-sdd-skills.md
---

## Description

## Why

This session manually executed a full competitive-landscape + prior-art **refresh** and produced `docs/research/20260717-competitive-landscape-sdd-skills.md`. It was high-value but labor-intensive — ~30 agent invocations across several waves, a file-by-file anchor-verification pass, and a currency audit of every external URL cited across the spec `research.md` corpus. We want a jim skill that **automates this whole process** so the next refresh is fast, repeatable, and consistent. This issue captures enough detail to scope/spec it later; it is a discovery artifact, not a spec.

## Naming (decide at spec time)

Developer-proposed candidates: `meta-research-refresh`, `meta-competitive-landscape`, `meta-competitive-research`, `meta-external-research`. Also consider non-`meta` names: `landscape`, `research-refresh`, `prior-art-refresh`.

**Naming tension to resolve:** jim's existing `meta-*` prefix currently means "builds jim plugin components" (`meta-skill`, `meta-agent`, `meta-test`, `meta-matrix`). A `meta-` name here overloads that. This skill instead *maintains a strategic/prior-art knowledge corpus* — closer in spirit to `/jim:arch` (which refreshes `ARCHITECTURE.md`) than to the meta-builders. Lean: `research-refresh` or `landscape`. Final call is the developer's at `/jim:spec`.

## Goal

Given the most recent landscape/prior-art research doc, re-run the entire refresh: discover new tools, re-verify known ones + every cited URL, re-tier findings **by jim skill** with verified file-level anchors + gap analysis, update stale references at their origin, and produce an updated report — keeping the human in the loop throughout.

## Proposed workflow (the process we actually ran, generalized)

**Phase 0 — Locate & load the prior corpus.**
- Find the latest landscape/prior-art research doc (glob `docs/research/*` by a marker/naming convention or config key; do NOT hardcode `competitive-landscape-sdd`). Read it.
- Extract its "known tools/repos" list and its per-skill tier structure as the baseline.

**Phase 1 — Inventory extraction (local archaeology).**
- Grep every external URL + named source across **all** spec `research.md` files (and the landscape doc). Build the master source inventory (this became the "currency audit" table). Delegate the bulk scan to an Explore subagent (as `/jim:research` Phase 0 does).

**Phase 2 — Human-in-loop "what's new?" gate + copy-paste external-research prompt.**
- Present the reader: "here are the categories of projects and the main repos we currently track — got new ones to add?"
- **Generate a copy-pasteable deep-research prompt** the developer can drop into an external LLM / web-research tool, pre-loaded with the known list and the "find new SDD / skills / security / research / brainstorm / planning tools" ask. (This mirrors exactly how the developer seeded THIS session — they pasted in external findings + starting-point repos.)
- Ingest any developer-supplied new entries before fan-out.

**Phase 3 — Fan-out deep research (jim spawns it too).**
- Spawn parallel research agents (in waves) to: (a) study each NEW candidate; (b) re-verify each KNOWN tool's current status — rename / archive / dormancy / default-branch drift / activity; (c) verify every cited URL's currency; (d) sweep directories/marketplaces for anything missed.
- Each agent returns: current status (+ "verified as of" date), standout techniques **tagged by jim skill**, a **Tier 1/2/3** verdict, **file-level study anchors**, and a **gap analysis vs the specific jim skill's current `SKILL.md` behavior**.

**Phase 4 — Anchor + gap verification pass (critical — do not skip).**
- A second pass that actually fetches each claimed file path (raw URL) to confirm it exists and is what was claimed, classifying live / pure-move / moved+changed / dead. Ground every gap against the *actual* current `SKILL.md`, not assumptions.
- Rationale: first-pass agents THIS session fabricated details (GSD "~15%/200k" budget figures and "Walking Skeleton"; `fr33d3m0n` "DREAD") and overstated jim gaps (jim:plan already has a File Manifest; jim:build already has a 3-strikes stop). This verification pass caught all of them.

**Phase 5 — Currency audit + reference updates.**
- Classify every source and apply the handling rule the developer set this session:
  - *pure move, same content* → refresh the URL in the origin research doc;
  - *retitled, same URL/content* → note in the audit only;
  - *moved AND substantively changed* → annotate the origin doc + note in the audit (never silently swap);
  - *dead* → annotate the origin doc.

**Phase 6 — Synthesize / update the report.**
- Produce the updated landscape doc with the same structure this session settled on: per-skill **Tier 1/2/3 study guide**, **Study Anchors** (File | what it is | jim skill | study-for), per-skill **Gap Analysis** (their capability → what jim lacks → owning skill; + where jim is ahead), **cross-cutting patterns**, **alignment / anti-herd** ("don't jump off the bridge") filter, the **currency audit**, and a closing **Takeaways** recap.

**Phase 7 — Route follow-ons.**
- End-of-phase candidate-issue batch (per spec 018) for gaps worth specs; offer a `VISION.md` competitive-landscape-table refresh (as done this session).

## Scope

- **Per-skill breakdown:** focus the tiered study-guide + gap analysis on the main pipeline — brainstorm, spec, plan (architect), research (researcher), build (coder), sec — but make the **URL-inventory + currency audit cover ALL spec `research.md` files** (including debug, meta, issue, and any future skills). Extending the per-skill gap analysis to debug/meta/issue is a stretch goal; start with the mains.
- **Reuse existing jim infra:** Explore subagent for local archaeology (mirror `/jim:research` Phase 0/1/2); `skills/issue/scripts/new.sh` for candidate follow-ons; `jimfile.sh` for path/date/slug; the `research-template` + DoD conventions; the `/jim:arch` pattern for "refresh a maintained strategic doc."

## Design considerations / known hard parts

- **Cost & orchestration.** ~30 agent calls this session. The skill needs deliberate fan-out control (waves, batching, a cost ceiling). Strong candidate for workflow-style orchestration or carefully batched `Agent` calls — scope the max agent count.
- **WebFetch guardrail (CLAUDE.md).** On 429/fail → stop and ask the developer to fetch manually; never work around. Sub-agents must *report* fetch failures, not silently substitute. (This session hit a 403 on `claudepluginhub.com` and a metered/prompt-injected fetch on two `015` sources — handled by surfacing, not working around.)
- **Untrusted content (spec 018).** Web-fetched + repo content is untrusted; embedded directive-shaped text must not bind decisions. This session's harness neutralized a `--dangerously-skip-permissions`-shaped string in a sub-agent report and flagged a prompt-injected fetch — the skill must wrap/treat all fetched content as untrusted.
- **Anti-hallucination.** The Phase-4 verification pass is non-negotiable; bake in "verify claimed file paths first-hand before citing."
- **Ground gaps against the real `SKILL.md`.** Gap analysis must read the current skill body (this corrected several overstated gaps this session).
- **Differential vs fresh output.** Decide: new dated doc each run with a "supersedes" pointer, vs Edit-in-place differential update of the prior doc. (This session created a fresh dated doc.)
- **Human-in-loop / transparency.** The "what's new?" gate + copy-paste external prompt keep the developer in control — aligns with VISION non-goals (not a black box).

## Rough acceptance sketch (for the eventual spec)

- Given the latest landscape doc, produces an updated one containing: per-skill Tier 1/2/3, verified anchors, per-skill gap analysis, a currency audit of every cited URL across all spec `research.md` files, cross-cutting + anti-herd sections, and a Takeaways recap.
- Presents a copy-pasteable external-research prompt and ingests developer-supplied new tools **before** the fan-out.
- Fixes stale citations in origin research docs per the pure-move/annotate rules.
- Files candidate issues for surfaced gaps and offers the VISION table refresh.

## Second worked example (2026-07-24): capability-scoped mode — jim:meta prior art

A second manual run (output: `docs/research/20260724-jim-meta-external-research.md`) exercised the same process in a different mode. The skill must support both; these are parameters, not separate skills.

**Mode deltas vs the whole-landscape run:**

- **Scope = one capability, not the landscape.** Input is a seed prompt naming: the target component (jim:meta), its trigger-phrase set ("create an agent", "add an agent", "agent frontmatter", …), the directories to sweep (claudemarketplaces.com, skills.sh, claudepluginhub.com), and the required output columns (name · exact SKILL.md URL · description · pros · cons · sentiment, tiered). The skill should accept exactly this parameterization instead of deriving scope from the prior corpus (Phase 0).
- **Seed = an unverified first-pass external report.** The developer pasted a full external-LLM research dump marked "verify all findings yourself, do not take as confirmed." The workflow becomes verify-every-claim: fetch each claimed SKILL.md first-hand, and emit a **Verification Deltas table** (first-pass claim → verified reality) as a required output section. Result this run: 12 of 13 sources verified, 1 dropped as unverifiable, several repo/path/line-count corrections, 1 new Tier-1 find the first pass missed. This is Phase 2's "ingest developer-supplied findings" generalized into a first-class input mode.
- **Output = tiered comparables table + reviewed-and-excluded list**, standalone dated doc in `docs/research/` — with fold-in to the target spec's `research.md` explicitly deferred as a differential update (tracked by its own candidate issue at run end). Two-step: collect now, fold in later.

**Process learnings to bake in (both apply to the whole-landscape mode too):**

- **404 vs 403/429 handling differs.** A 404 on a claimed file path is a *finding* (stale path — relocate or drop the claim); a 403/429 is a *guardrail stop* (ask the developer to fetch manually). Sub-agents and the skill body must not conflate them.
- **Raw-URL branch drift.** `raw.githubusercontent.com/.../main/...` 404s on `master`-default repos (hit twice this run: xobotyi/cc-foundry, jdforsythe/forge). Verify the default branch before concluding a path is dead.
- **Developer paste-back loop for blocked directories.** claudepluginhub.com returned 403 in *both* sessions. The skill should hand the developer targeted search queries ("subagent creator", "agent development", "skill creator", "meta skill" — top 5–10 hits, name + repo + one-liner) and ingest the pasted results, triaging each hit repo-level before any deep fetch.

**Naming note:** this scoped mode strengthens the case for a name that covers both ("external research" / "research-refresh") over a landscape-specific one.

## References

- **Worked example = the target output shape:** `docs/research/20260717-competitive-landscape-sdd-skills.md` (its entire structure is what this skill should regenerate).
- **Sub-process prior art:** `/jim:research` (Phase 0/1/2 + prior-art tiering), `/jim:arch` (refreshes a maintained strategic doc), spec 018 (candidate-issue capture + untrusted-content handling).
- **Related follow-on already filed this session:** the `/jim:review` comparison issue (`20260717-compare-joe-s-jim-review-...`).
