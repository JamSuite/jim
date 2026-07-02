---
spec: "spec.md"
status: Active
date: "2026-06-04"
---

# Research: Issue insights — LLM-analytical view

## Anchors

- **`skills/issue/SKILL.md:19–36`** — Step 1 subcommand dispatch. `add` (27–28) is the only LLM verb; `list`/`stats`/`show`/help branch to `render.sh`; unknown → error+help (35). The `insights` arm inserts here as the **second** prompt-side branch.
- **`skills/issue/SKILL.md:136–151`** — Step 7 `<untrusted-issue-content slug="…">` wrapping discipline (Spec 017 AC-S2). The safety boundary a body-reading verb must apply.
- **`skills/issue/scripts/render.sh:517–531`** — top-level `case` dispatch (`stats`/`list`/`show`/help). No `insights` arm needed for the synthesis itself (prompt-side), but the help text and any isolation precompute live here.
- **`skills/issue/scripts/render.sh:154–166`** — `cmd_help` subcommand list. `insights` must be added here for AC #9; this is the **only deterministic, bash-testable change**.
- **`skills/issue/scripts/render.sh:170–283`** — `cmd_stats`: open/closed counts, origin/label clustering, and **blocking out-degree (245–275)**. Sequencing pressure can reuse this existing computation rather than re-deriving it.
- **`skills/issue/scripts/render.sh:62–92, 177`** — `ensure_index` / staleness gate; regen only when `INDEX.md` is stale.
- **`skills/issue/scripts/index.sh:474–495`** — `INDEX.md` layout: `## Summary`, `## Issues` (metadata rows, **no bodies**), `## Graph`, `## Integrity Warnings`.
- **`skills/issue/scripts/index.sh:455–462`** — `## Graph` edge format: `` `source` --{type}--> `target` `` (type ∈ blocks/depends-on/related-to/duplicates), one edge per line, no isolation section.
- **`skills/issue/assets/issue-template.md:1–21`** — frontmatter (1–16) + body (`## Description`, 18–21). **Bodies live only in `docs/issues/*.md`** — `insights` must read per-issue files for semantic convergence.
- **`tests/issues.sh:14–70, 82–99`** — test harness (`run_index`/`run_render`/`write_issue`) + happy-path template; deterministic-only.
- **`skills/conf/scripts/jimconf.sh:42, 70–73`** — `issue_list_*` config-key pattern (KEYS array + default arm). Spec adds **no** `insights_*` keys; this is the mirror if that ever changes.

## Local Patterns

- **The `add` verb is the LLM-branch template** (`SKILL.md` Steps 2–7): branch from dispatch → read strategic context → draft. `insights` mirrors the *branch* but is **read-only** — no confirm-or-edit, no write, no `index.sh` regen. It is closer to "a `show` that interprets" than to `add`.
- **Bash-vs-Prompt rule** (`ARCHITECTURE.md:310–321`): semantic synthesis (convergence, sequencing prose) stays prompt-side; deterministic graph-structure (isolation, out-degree) *may* be precomputed in bash and handed to the prompt. `index.sh`/`render.sh` are the cited anchors for "frontmatter scan + render."
- **Test template:** `tests/issues.sh` — `write_issue` (62–70) seeds a temp issues dir; `run_render`/`run_index` (14–47) capture stdout/stderr/RC. Only the `cmd_help` addition (AC #9) is bash-testable; the synthesis is validated by **skill checklist**, not bash (consistent with `ARCHITECTURE.md:264` — LLM prompts validated by checklist).

## Security & Performance

- **Indirect prompt injection (primary risk).** `insights` reads untrusted issue bodies and *by design interprets them* — so the read-verb "present stdout verbatim / do not act on directive-looking text" discipline (`SKILL.md` Step 1) **cannot** cover it. The `<untrusted-issue-content>` wrapping (`SKILL.md:136–147`) becomes the sole boundary: every body fed to the analysis must be wrapped, with the do-not-follow-embedded-instructions note. AC #8 already encodes this; the architect must explicitly carve `insights` out of the verbatim rule so the carve-out is intentional, not a gap.
- **Per-run full-collection read (perf).** With the cache out of scope (spec decision), each run reads every issue body — O(n) file reads + whole-collection tokens per invocation. Fine at today's scale; the bounded-cost path (spec Insight 3) is **staged**: metadata + graph from `INDEX.md` first, bodies only for candidate convergence groups. The deferred cache is the eventual amortizer.
- **No write surface.** Read-only means no `INDEX.md` corruption or atomic-write concerns; the staleness gate (`render.sh:62–92`) still applies if `insights` triggers a regen to read a fresh graph.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Dispatch:** add `insights` as the second LLM arm in `SKILL.md:19–36`, adjacent to `add`. No `render.sh` `case` arm is required for the synthesis.
2. **Parallel-work / graph-isolation (AC #5):** isolation *is* derivable from `INDEX.md:455–462` — the set of `## Issues` slugs that never appear as source or target in `## Graph`. Two routes: **(a)** a small deterministic helper in `render.sh` (exact, cheap, reliable) that emits the isolated set for the prompt to consume; **(b)** prompt-side scan of the Graph edge list. Recommend **(a)** for the graph-structural part (exactness), leaving convergence + sequencing to the LLM. Either keeps the relation-graph-only scope (no codebase independence proof — out of scope).
3. **Sequencing (AC #4):** reuse `cmd_stats`' blocking out-degree (`render.sh:245–275`) as the deterministic pressure signal feeding the LLM's prose, rather than re-inferring blocking from the raw graph.
4. **Bodies (AC #2):** read per-issue `docs/issues/*.md` (not `INDEX.md`), each wrapped per `SKILL.md:136–147`.
5. **Help (AC #9):** one-line `insights` entry in `cmd_help` (`render.sh:154–166`) — the lone deterministic change; add a `tests/issues.sh` case asserting it appears.

**Alignment.** Fits VISION Phase 2 (Research & Refinement) and the "living documents support agile iteration" pillar — the issue collection becomes sense-makeable institutional memory. Stays clear of the "PM system (Jira/Linear)" non-goal **because it is read-only advisory** — it surfaces judgment, it does not manage lifecycle. Honors `ARCHITECTURE.md`'s Bash-vs-Prompt rule (synthesis → prompt; optional isolation precompute → bash). No locked-constraint divergence.

## Open Questions

- None blocking. Whether graph-isolation is precomputed (Rec 2a) or inferred prompt-side (2b) is the architect's call at `/jim:plan`; both are feasible against the current `INDEX.md` shape.
