# Brainstorm: jim:howtos — Decomposing ARCHITECTURE.md into a Technical Wiki

*2026-05-12*

> **Superseded (2026-07-17) by [`20260717-jim-arch-knowledge-corpus.md`](20260717-jim-arch-knowledge-corpus.md).**
> That doc widens the frame from *how-tos* to the whole knowledge corpus and resolves the command-model
> question left open here: no standalone `/jim:howtos` command — "howto" becomes one `kind:` on a
> knowledge-rung ladder managed by an upgraded `/jim:arch`. This doc is retained for its 9-project
> prior-art survey, the Kiro mapping, the ARCHITECTURE↔topic boundary rule, and the proactive-suggestion
> heuristics, all of which the successor carries forward.

Seeded by a Gemini CLI draft; refined collaboratively. Working document — not a spec yet.

## Problem Statement

Currently, `ARCHITECTURE.md` acts as the primary "memory" and technical guide for Jim projects. While it follows a structured template, it suffers from several issues:
1. **Bloat:** It becomes a "catch-all" for every technical decision, guide, and convention, leading to massive files that are hard for both humans and agents to navigate efficiently.
2. **Mixing of Concerns:** High-level system design (diagrams, components) is mixed with low-level implementation guides (how to write a test, how to handle errors).
3. **Difficulty in Updates:** Small changes to specific conventions require modifying the large "constitution" of the project, increasing the risk of "instruction shadowing" or "personality soup".
4. **Limited Discovery:** New developers (and agents) may miss specific conventions buried in a 1000-line architecture doc.

## Proposed Solution: `jim:howtos`

Introduce a first-class concept of **HOWTOs**—modular, topic-specific technical guides stored in a dedicated directory (default: `docs/howtos/`). This transforms `ARCHITECTURE.md` into a "Table of Contents" and "High-Level Blueprint," while the "Wiki" (HOWTOs) handles the deep-dive implementation memory.

### Key Features
- **`/jim:howtos` Command:** A new skill for creating, listing, and updating guides.
- **Configurable Location:** `howtos_path` in `jimconf.toml` (default `docs/howtos`).
- **Standardized Templates:** A `howto-template.md` to ensure consistency.
- **Proactive Suggestions:** Agents (PM, Architect, Researcher) suggest creating a HOWTO when they detect "high-density technical buckets."

## Research & Prior Art

Surveyed nine agentic-SDLC projects on 2026-05-12 for a comparable wiki/howto/steering pattern: Kiro, addyosmani/agent-skills, Spec-Flow, gstack, SuperClaude, gsd-build, github/spec-kit, zhsama/claude-sub-agent, VoltAgent/awesome-claude-code-subagents.

**Result: only two strong matches.** The rest either put technical reference into a monolithic `ARCHITECTURE.md` / `KNOWLEDGE.md`, or conflate procedure with reference inside skill/command files. The gap `/jim:howtos` would fill is real and underserved.

### Strong matches — borrow from these

**Kiro Steering** (`kiro.dev/docs/steering`) — the directly comparable design.

| Aspect | Kiro | Maps to jim |
|---|---|---|
| Directory | `.kiro/steering/` (workspace) + `~/.kiro/steering/` (global) | `docs/howtos/` configurable via `jimconf.toml` |
| **Inclusion modes** (the missing dimension in jim's draft) | `Always` / `Conditional(fileMatch glob)` / `Manual (#name)` / `Auto (description match)` | jim already has the `description:`-match mechanism for skills; `paths:` (new Claude Code field, see 2026-05-12 freshness audit) is literally Kiro's `Conditional` mode. No new primitive needed. |
| Auto-generated baseline | `product.md` + `tech.md` + `structure.md` always-loaded | jim's `VISION.md` + `ARCHITECTURE.md` + `ROADMAP.md` already serve this role. HOWTOs fill the conditional/manual/auto tiers. |
| File references | `#[[file:path]]` inline links to live workspace files | Equivalent to jim's existing `!`-injection / `@`-mention conventions. |
| AI-assisted refinement | "Refine" button | Maps to jim's differential-update model (read → summarize → Edit). |

**addyosmani/agent-skills** — different architecture (skills-as-docs, not docs-as-docs), but its template is the strongest prior art for HOWTO body structure:

> Overview → When to Use → Process → Rationalizations → Red Flags → Verification

The "Rationalizations" section (common excuses + rebuttals) is uniquely suited to behavioral HOWTOs like `substitution-sigils.md` or `directive-vocabulary.md` where there's a "but can't I just…" trap to head off. Worth comparing to the current draft template's *Anti-Patterns + Troubleshooting* split — they overlap but Rationalizations is more pointed.

**`docs/prior-art/howtos/tauri-env-build.md`** — a real production HOWTO captured from a Tauri project, included specifically because it proves a single template won't fit everything. 387 lines, organized around a use-case matrix (desktop / iOS / Android × dev / build / sideload), with per-row procedural sections, a reference table of data locations, and "[⬑ Back to top]" anchors. The doc's own preamble flags this: *"demonstrates a complex matrix of options that are linked together… a generic howto template will be challenging to fit."* This is the **multi-template signal** — HOWTOs vary by shape (procedural, behavioral, reference), and jim should ship variants rather than force one shape. See "Preliminary Answers → Body template" below.

### Adjacent — terminology inspiration only

**github/spec-kit** — has `.specify/memory/constitution.md`, a single governance doc capturing locked principles. Same "persistent project context" framing, but it's *one* file, not a directory. Worth borrowing the **"memory"** language (vs. wiki/howto) if it lands better with users. Not a structural match.

### Negative examples — what NOT to do

**SuperClaude's `KNOWLEDGE.md`** — one file containing "accumulated insights, best practices, troubleshooting." This is *literally the bloat problem* `/jim:howtos` is solving, in microcosm. Useful to cite in the spec as the failure mode the feature prevents.

**gsd-build, Spec-Flow, github/spec-kit, zhsama/claude-sub-agent** — all use monolithic top-level docs (`USER-GUIDE.md`, `ARCHITECTURE.md`, `COMMANDS.md`). Confirms the field-wide pattern jim is breaking from.

### Underlying patterns (from the original draft)

- **Cognitive Model Pattern:** Documentation maps to Past (Changelog), Present (Architecture), Future (Requirements), and HOWTOs (the "How" / Runbooks).
- **AI-Ready Documentation:** Modular docs are easier for agents to ingest without overwhelming context. Kiro's inclusion modes are the practical mechanism that delivers this.

## HOWTO Categories (Examples)

- **Workflow:** testing, code layout, pull requests, commit conventions.
- **Technical Patterns:** error handling, logging, data migrations, API design.
- **Infrastructure:** building, deploying, environment setup.
- **Project Specifics:** skill invocation conventions, permission sets, LLM prompting strategies.

### Immediate Candidates for Jim (from ARCHITECTURE.md)

The following sections in jim's current `ARCHITECTURE.md` are prime candidates for extraction into `docs/howtos/` — concrete pain points, not hypothetical:

| Candidate HOWTO | Source section | Rough line range | Why it qualifies |
|---|---|---|---|
| `skill-invocation.md` | Plugin Conventions → Skill Invocation, Agent Invocation, Subagent Delegation | `ARCHITECTURE.md:235-252` | Cross-cutting convention; high failure cost (silent skill mis-routing); already cited from multiple skills. |
| `directive-vocabulary.md` | Plugin Conventions → Logic-Flow Conventions | `ARCHITECTURE.md:279-350` | ~70 lines of formal grammar plus an anti-pattern callout; load-bearing for every skill author. |
| `substitution-sigils.md` | Plugin Conventions → Substitution Conventions | `ARCHITECTURE.md:352-370` | Three-sigil rule with wrapper-sensitivity gotcha; references a debug doc — natural runbook material. |
| `bash-testing.md` | Development & Testing + Scripting Layer → Tests | `ARCHITECTURE.md:216-223, 263` | Hand-rolled framework with non-obvious conventions (function-name discovery, BASH_SOURCE-relative sourcing); already crowds the architecture doc. |
| `scripting-layer.md` | Plugin Conventions → Scripting Layer + Bash-vs-Prompt Decision Rule | `ARCHITECTURE.md:254-277` | Both rules (CLAUDE.md security + bash-vs-prompt heuristic) belong together as a single guide. |

This is jim eating its own dog food — the same feature that solves project ARCHITECTURE.md bloat is exactly the feature jim itself needs.

## The ARCHITECTURE.md ↔ HOWTO boundary

The critical question for `/jim:arch`: when a HOWTO is created, what stays in `ARCHITECTURE.md`?

**Proposed rule:** ARCHITECTURE.md keeps the *one-paragraph identity* of a convention (what it is, why it exists, where it lives) and links to the HOWTO for the *recipe* (rules, examples, anti-patterns, troubleshooting). This preserves the architecture document as a navigable index without losing it as a conceptual map.

**Example:**
> *In ARCHITECTURE.md, after extraction:*
> ### Logic-Flow Conventions
> In-prompt existence/absence gates around `!`-injected paths use a sentinel-based form: `SET <name> = !\`bash …\`` + `IF <name> != "NOT_FOUND" THEN … ENDIF`. The shape is forced by a wrapper-sensitivity rule in Substitution Conventions and the EXISTS-trap defect that motivated the 2026-05-13 amendment to spec 011. **See [`docs/howtos/gate-convention.md`](docs/howtos/gate-convention.md) for the full grammar, examples, and anti-patterns.**

This is the smallest change that resolves the bloat problem. Alternative — fully replacing the section with a single link — loses ARCHITECTURE.md as a self-contained orientation doc.

## Standardized HOWTO Template

A `howto-template.md` should be provided in `skills/howtos/assets/`:

````markdown
# HOWTO: {Topic}

- **Level:** Beginner | Intermediate | Advanced
- **Audience:** Developers | Agents | DevOps
- **Last Updated:** {YYYY-MM-DD}

## Overview
{1-2 sentence description of what outcome this guide achieves.}

## Prerequisites
- {Constraint or requirement 1}
- {Constraint or requirement 2}

## Recipe / Steps
1. **{Step Title}:** {Description}
2. **{Step Title}:** {Description}
   ```bash
   # Code example here
   ```

## Anti-Patterns
- **{Anti-pattern Name}:** {Why it's bad and what to do instead.}

## Troubleshooting
- **Problem:** {Description}
- **Solution:** {Steps to fix}

## Related Links
- [ARCHITECTURE.md](../../ARCHITECTURE.md#relevant-section)
- [Other HOWTO](other-guide.md)
````

## Agentic Discovery & Metadata

To make the Wiki "AI-Ready":
- **`llms.txt` Integration:** Automatically include the `docs/howtos/` directory in a project's `llms.txt` (if present) so agents discover the guides immediately.
- **YAML Front-matter:** Use `type: howto`, `tags: [bash, testing]`, and `status: evergreen` to allow agents to filter relevant guides during search.
- **"Context Priming":** Skills like `/jim:build` or `/jim:plan` should check for a `howtos/` index or specific guide before implementation.

## Workflow Integration: The "Proactive Jim"

Jim shouldn't just wait for a command; he should recognize when a HOWTO is needed.

### When to suggest?
1. **During `/jim:spec`:** If a new feature introduces a "first-of-its-kind" pattern (e.g., first time adding a database).
2. **During `/jim:research`:** If the Researcher finds a recurring technical pattern that is undocumented or inconsistent.
3. **During `/jim:arch`:** When scanning the codebase, if the Architect detects a "high-density technical bucket" (see heuristics) that has no corresponding HOWTO.
4. **During `/jim:plan`:** If the Architect finds themselves writing >10 lines of "Implementation Anchors" about *how* to do something vs. *what* to do.
5. **During `/jim:brainstorm`:** When a session concludes with "this is how we should handle X moving forward."
6. **During `/jim:debug`:** If a failure was caused by a misunderstood convention, suggest documenting it in a HOWTO to prevent recurrence.

### The /jim:arch Coordination Loop
The `/jim:arch` skill serves as the primary "Librarian" for the technical wiki:
- **Discovery:** Step 4 of `/jim:arch` (Scan the codebase) will now include a glob of the `howtos_path`.
- **Linking:** Step 5 (Generate/Update) will map discovered HOWTOs to their relevant `ARCHITECTURE.md` sections. For example, `docs/howtos/testing.md` is automatically linked under "Development & Testing".
- **Pruning/Auditing:** If `/jim:arch` finds a HOWTO that no longer matches the codebase patterns (e.g., it describes a logging library that has been removed), it should suggest a `/jim:howtos update` or deprecation.

### Heuristics for "High Importance" (The "High-Density Bucket")
To prevent Jim from becoming an annoying documentation nag, suggestions should only trigger when one of these "density" thresholds is met:

1.  **The "10-Line Rule":** During `/jim:plan`, if the Architect writes more than 10 lines of "Implementation Anchors" or "Manual Steps" that describe *how* to implement a recurring pattern (e.g., "always use this specific wrapper for DB calls"), suggest a HOWTO.
2.  **The "Third Time's the Charm":** If the Researcher detects the same technical pattern or convention being implemented in 3 or more different files (especially if there's slight drift), suggest a HOWTO to consolidate the "One True Way."
3.  **The "Cross-Package Boundary":** Any convention that must be shared between different packages in a monorepo (e.g., sharing a logging utility between `pkg/api` and `pkg/worker`) warrants a HOWTO.
4.  **The "Failure Loop":** If `/jim:debug` identifies that a bug was caused by a developer (or agent) violating a non-obvious project convention, a HOWTO is mandatory.
5.  **The "Safety/Security Gate":** Any procedure involving credentials, deployment permissions, or data destructive operations MUST have a HOWTO if it's not already covered by a script.

## Draft Workflow for `/jim:howtos`

1. **Invoke:** `/jim:howtos create "error handling"`
2. **Interview:** Jim asks 2-3 targeted questions about the convention (based on "gray-area analysis").
3. **Draft:** Jim scans the codebase for existing examples to ground the guide in reality.
4. **Generate:** Jim creates `docs/howtos/error-handling.md` using a template.
5. **Link:** Jim automatically adds a link to the new HOWTO in the relevant section of `ARCHITECTURE.md`.

## Non-goals for v1

To keep the PM interview from sprawling, these are deliberately *out of scope* for the first cut:

- A dedicated `@jim:librarian` agent — start with PM/Architect handling HOWTOs through `/jim:howtos`.
- `llms.txt` integration — useful but a separate concern; can be a follow-up spec once the directory exists.
- Automated freshness/staleness detection (a `/jim:howtos check` command). `/jim:arch` can flag drift opportunistically; dedicated automation is v2.
- A central `INDEX.md` — let `/jim:arch` linking serve as the index initially; revisit if the count exceeds ~15 HOWTOs.
- Proactive suggestion logic in *every* skill. Pick the 2–3 skills with the highest signal (likely `/jim:plan` and `/jim:research`); add others later if the suggestions land well.

## Open Questions

- [ ] **File naming.** Date-prefixed like brainstorms (`20260512-error-handling.md`) or pure slug (`error-handling.md`)? Slug matches the "evergreen" framing; date-prefix preserves history. Lean: pure slug.
- [ ] **Status lifecycle.** Just `evergreen` / `deprecated`, or also `draft`? Brainstorms have no lifecycle; specs have five. HOWTOs probably need at least `evergreen` and `deprecated`.
- [ ] **HOWTO ↔ executable artifacts.** When a HOWTO documents a script that already exists (e.g., `bash-testing.md` → `skills/meta-test/scripts/`), should the HOWTO link to the script, or is the script the canonical source and the HOWTO just orientation? Lean: HOWTO orients, script is canonical.
- [ ] **Differential updates.** `/jim:howtos update <name>` reads existing, summarizes proposed changes, uses Edit — same shape as every other jim skill. Worth confirming in the spec.
- [ ] **Cross-cutting suggestions.** Heuristics are documented above — but the PM should decide which skills get the proactive nudge in v1 vs. later.

## Preliminary Answers to Scope Decisions

Working recommendations to seed the PM interview — not commitments. The `/jim:spec` interview can revisit any of them.

### Subcommands

**`create`, `list`, `update`, `deprecate`.** Mirrors `/jim:spec` and `/jim:conf` patterns. Interview-driven `create`; differential `update`. `deprecate` sets status, doesn't delete — preserves history. Possibly add `path` and `glob` later for `jimfile.sh` parity, but only if scripts need them.

### File naming + status lifecycle

- **Pure slug** (`error-handling.md`). HOWTOs are evergreen reference, not time-stamped artifacts like brainstorms or debug docs.
- **Status: `evergreen` + `deprecated` only.** Skip `draft` in v1 — HOWTOs aren't gated by approval the way specs are. Add `draft` later if a multi-session creation workflow emerges.

### Inclusion modes — refinement on Kiro

HOWTOs aren't Claude Code skills; they're passive markdown reference. Kiro's modes don't all transfer for free.

| Mode | v1? | Why |
|---|---|---|
| **Manual** (`@docs/howtos/foo.md`) | **Ship** | Free — skills/agents reference HOWTOs explicitly in their prompts. |
| **Conditional** (`paths:` glob) | Defer to v1.x | Uses the new Claude Code `paths:` field + skill-side discovery — useful but not v1-load-bearing. |
| **Auto** (description match) | Defer | Requires skill-side scan plumbing; only worth it if usage shows the need. |
| **Always** | **Skip permanently** | Defeats the bloat-reduction goal. Strategic docs (VISION/ARCHITECTURE/ROADMAP) already cover this tier. |

**v1 = Manual-only.** Add Conditional once we see which HOWTOs get repeatedly `@`-mentioned from the same skills.

### Body template — ship three variants

The tauri prior art forced this. One template doesn't fit procedural, behavioral, and reference HOWTOs.

| Variant | Use for | Shape |
|---|---|---|
| `template-procedure.md` | Step-by-step recipes (deployment, migrations, error-handling) | Overview → Prerequisites → Recipe → Anti-Patterns → Troubleshooting (current draft) |
| `template-convention.md` | Behavioral rules (`directive-vocabulary`, `substitution-sigils`) | Overview → When to Use → Rules → Rationalizations → Red Flags → Verification (addyosmani) |
| `template-reference.md` | Multi-option matrices (`tauri-env-build`, monorepo code layout) | Use-case matrix → Per-case sections → Reference tables → Troubleshooting (tauri) |

`/jim:howtos create <topic>` asks which variant fits during the interview. Frontmatter (`title`, `status`, `last_updated`, optional `tags`) is shared across all three. Users can deviate from a variant — the templates are scaffolds, not rigid forms.

### Proactive suggestion — which skills, when

| Skill | v1? | Trigger |
|---|---|---|
| `/jim:plan` | **Yes** | "10-Line Rule" — architect writing >10 lines of how-to inside Implementation Anchors |
| `/jim:research` | **Yes** | "Third Time's the Charm" — same pattern in 3+ files with drift |
| `/jim:debug` | **Yes (added)** | "Failure Loop" — bug caused by violating an undocumented convention. Each debug → HOWTO is "never again" |
| `/jim:arch` | Linking + pruning only (not creation suggestion) | See loop below |
| `/jim:brainstorm` | Add `/jim:howtos` to end-of-session routing menu only | No mid-session push — brainstorms stay open-ended |
| `/jim:spec` | No | Too early — the pattern doesn't exist yet |
| `/jim:build` | No | Too late — should have been planned |
| `/jim:vision`, `/jim:roadmap` | No | Strategic, not technical |

### /jim:arch as Librarian — two operations, one coordination loop

1. **Linking (automatic).** Every `/jim:arch` run globs `howtos_path`, reads frontmatter, ensures relevant ARCHITECTURE.md sections link out. Idempotent.
2. **Pruning (opportunistic).** If a HOWTO references code/paths that no longer exist, flag conversationally — never auto-deprecate. Human decides.

**Creation suggestion stays out of /jim:arch.** That belongs in `/jim:plan`/`research`/`debug` where the pattern is fresh and the context is loaded.

**Coordination loop:** when `/jim:arch` detects a high-density section during its codebase scan:
1. Surface the candidate: *"Plugin Conventions → Logic-Flow Conventions is 70 lines deep with formal grammar — extract to HOWTO?"*
2. On confirmation, hand off to `/jim:howtos create directive-vocabulary` seeded with the section content
3. After creation, `/jim:arch` auto-replaces the section in ARCHITECTURE.md with a one-paragraph identity + link (per the ARCHITECTURE.md ↔ HOWTO boundary rule)

This makes `/jim:arch` the bloat-detector and `/jim:howtos` the creator.

### When NOT to suggest a HOWTO

- During spec definition (pattern doesn't exist yet)
- During build (too late)
- For one-off tasks (threshold = 3+ uses or a "would-bite-again" failure)
- For domain features (*"how login works"* is a spec; *"how we handle auth tokens"* is a HOWTO only if it's a cross-cutting convention)
- During strategic docs
- When a script fully captures the convention (the script IS the doc; HOWTO is optional orientation only)

### v1 example HOWTOs — ship 3, not 5

Enough to exercise all three template variants and prove the pattern range:

1. **`substitution-sigils.md`** (convention template) — acute pain; recent debug doc as origin (`docs/debug/20260512-skill-bash-substitution-wrappers.md`).
2. **`directive-vocabulary.md`** (convention template) — formal grammar benefits most from a dedicated guide.
3. **`bash-testing.md`** (procedure template) — non-obvious setup; shows the procedural variant.

Defer `skill-invocation.md` and `scripting-layer.md` to v1.x — useful but not needed to validate the pattern.

### Minor conventions from the tauri prior art

- **Navigation.** HOWTOs longer than ~150 lines should add `[⬑ Back to top]` anchors after major sections.
- **Length.** No hard cap; soft "consider splitting if >300 lines" guideline (mirrors SKILL.md's 500-line ceiling).
- **Cross-doc links.** Relative paths from project root (`docs/howtos/<slug>.md`); links to sibling HOWTOs use plain markdown.

---

## Next Steps

### Recommendation: SPEC

Move to `/jim:spec`. The shape is clear enough to scope; the open questions above are exactly what the PM interview should resolve.

### Prompt for `/jim:spec`

```text
/jim:spec jim:howtos

New feature: a `/jim:howtos` command for managing topic-specific technical guides ("HOWTOs") that decompose `ARCHITECTURE.md` into a modular wiki. Default location `docs/howtos/`, configurable via `jimconf.toml` (`howtos_path`). Ships with a standard HOWTO template.
Origin: `docs/brainstorms/20260512-jim-howtos.md` (see for prior art, candidate HOWTOs, heuristics, and the proposed ARCHITECTURE.md ↔ HOWTO boundary rule).
Prior-art: docs/prior-art/howtos/tauri-env-build.md

Scope decisions to interview around:
- Subcommands for `/jim:howtos` (likely `create`, `list`, `update`; possibly `deprecate`).
- HOWTO file naming (slug vs. date-prefixed) and status lifecycle.
- **Inclusion modes** (per Kiro prior art): always-loaded / glob-conditional via `paths:` / manual `@` reference / description-matched auto. Which modes ship in v1?
- Body template — the draft in this brainstorm vs. addyosmani's *Overview → When to Use → Process → Rationalizations → Red Flags → Verification* shape. compare with @docs/prior-art/howtos/tauri-env-build.md
- Which skills get proactive HOWTO suggestion logic in v1 (the brainstorm proposes /jim:plan and /jim:research as highest-signal).
- `/jim:arch` integration: does the architect link HOWTOs, prune stale ones, both?
- should jim:arch offer to make a HOWTO and get confirmation from the user? should jim:plan skill include some detail about when to create a HOWTO ?
- what about jim:research or jim:brainstorm? should those know when and when not to suggest creating a HOWTO? 
- when should those skills suggest creating a HOWTO? When should they not suggest creating a HOWTO?

Non-goals (already decided — see brainstorm): no `@jim:librarian` agent; no `llms.txt` integration; no automated staleness detection; no central INDEX.md.
- Whether this spec also ships ~3–5 example HOWTOs extracted from jim's own ARCHITECTURE.md (see "Immediate Candidates" table in the brainstorm) — proves the pattern works on jim itself.

Suggestion: link the brainstorm via the spec's `origin:` field so the spec stays traceable to this thinking.
```