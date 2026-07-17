---
spec: "standalone"
status: Needs PM Review
date: "2026-07-17"
---

<!-- Landscape/exploratory research. Longer than the 1500-word spec-research budget by design (cf. 20260504-research-plugin-interoperability.md). Prior art is link-first; no code blocks >20 lines. -->

# Research: Scaling jim's project-knowledge corpus beyond a monolithic ARCHITECTURE.md

**Problem (restated).** `ARCHITECTURE.md` grows unboundedly because it does four jobs with four different update cadences: (1) an architecture *contract* (stable boundaries, ownership, invariants), (2) a *codemap* (directories, components, entry points), (3) *engineering standards* (layout, language conventions, testing), and (4) *operational how-tos* (build, release, migrations). The user finds the hand-maintained how-to files far more useful than the doc no one reads. The ask: survey how other frameworks build a normative *knowledge corpus* (conventions/standards/best-practices — not a wiki map), fact-check the prior-art and statistical claims involved, and reach independent conclusions.

**Bottom line.** The four-jobs diagnosis is correct and jim's own repo proves it. No single framework solves the whole problem, but the composite is clearer *and cheaper* than a from-scratch design would suggest, because the loading mechanism such a design would invent already exists natively in Claude Code. This research **widens BACKLOG Task 0002 (`jim:howtos`)** from "how-tos only" to a typed knowledge corpus, and flags that spec 013's unconditional post-build refresh should be reconsidered. See Peer Feedback.

## Anchors

*Local files this work builds on (jim itself is the codebase under study).*

- `ARCHITECTURE.md:272-480` — **the exhibit.** A 208-line "Plugin Conventions" section = pure engineering-standards, embedded in an always-loaded doc. Bullets at `:309` and `:311` are 400+-word paragraphs written as **spec-by-spec changelogs** ("As of spec 017… 018… 019… 021… 022… 023… 025…"). This is the growth *and* the missing-ADR symptom in one place.
- `ARCHITECTURE.md:9-90` (Project Structure, 81 lines) and `:90-176` (diagram, 86 lines) — the *codemap* job. `:480` — Glossary = domain language. Total file: **491 lines** (native guidance is ≤200).
- `skills/arch/SKILL.md:54-79` + `skills/arch/assets/architecture-template.md` — the template that mixes contract + codemap + standards + operations into one always-generated doc.
- `docs/specs/jim/005-architect/spec.md:120-128` — where the architecture.md-derived section set was fixed.
- `docs/specs/jim/013-arch-feedback-loop/spec.md:12-19` — the unconditional post-build `/jim:arch` refresh (the churn engine).
- `docs/brainstorms/20260512-jim-howtos.md` — **comprehensive prior internal thinking** (9-project survey, Kiro mapping, three-template proposal, the ARCHITECTURE↔HOWTO boundary rule, non-goals). This research extends it; it does not replace it.
- `BACKLOG.md:68-92` (Task 0002 `jim:howtos`, "ready for `/jim:spec`") and `:278-287` (Task 0005, project-specific context extension — overlaps).
- `docs/prior-art/howtos/tauri-env-build.md` — the production how-to the user values; its own preamble warns "a generic howto template will be challenging to fit" (the multi-shape signal).

## Local Patterns

- **jim already treats living docs as institutional memory** (VISION.md "the spec/research/plan archive… compounds as institutional memory"). A knowledge corpus is squarely on-vision.
- **jim already has the two primitives a corpus needs.** Skills use progressive disclosure (description always in context, body on invoke) — the arch skill itself uses `SET … = !\`bash …\`` sentinel gates and `Skill(jim:arch)` skill-to-skill calls. The scripting layer (`jimfile.sh`/`jimconf.sh`) already resolves configurable doc paths, so a `howtos_path`/`conventions_path` key is a one-line extension of an established pattern.
- **The brainstorm already resolved most how-to mechanics** (slug naming, `evergreen`/`deprecated` lifecycle, three template variants, Manual-only v1, proactive-suggestion heuristics, `/jim:arch`-as-librarian). Treat those as settled inputs, not open questions.
- **Test-template note:** jim validates prompt-shaped features by author-time checklist (meta-skill/meta-agent DoD), not bash tests (spec 011 convention). Deterministic bits (a new config key, an index script) would follow `tests/jimconf.sh` / `tests/issues.sh` patterns via `/jim:meta-test scaffold`.

## Prior Art

15 sources verified against primary docs (2026-07-17). Two commonly-repeated claims did not survive verification; see the ⚠ flags.

### Tier 1 — Study closely (directly shape the design)

| Source | What it is | Why it matters |
|---|---|---|
| **Claude Code native memory & rules** ([docs](https://code.claude.com/docs/en/memory)) | `CLAUDE.md` hierarchy + `.claude/rules/*.md` with `paths:` glob frontmatter + Skills with `paths:`. | ✅ **Load-bearing correction to my own priors:** path-scoped rules *are* native — a rule with `paths:` loads lazily only when a matching file is read. This *is* Kiro's `fileMatch` mode, for free. `@imports` are **eager** (organize, don't save context). Official guidance: **≤200 lines** per always-loaded file; `/doctor` auto-trims derivable content. **Jim should map conventions onto native `.claude/rules/`, not invent a loader.** |
| **Kiro Steering** ([docs](https://kiro.dev/docs/steering/)) | `product.md`/`tech.md`/`structure.md` foundation + custom topic files; **4 inclusion modes** `always`/`fileMatch(glob)`/`manual(#ref)`/`auto(semantic description)`. `#[[file:…]]` references live code. | Strongest conceptual precedent for a typed, one-domain-per-file corpus with mixed routing. Note: **4 modes, not 3** — `auto` is the semantic mode. Native Claude Code covers `always`+`fileMatch`; `auto` ≈ skill `description`-match; `manual` ≈ `@`-mention. |
| **Diátaxis** ([diataxis.fr](https://diataxis.fr/)) | Docs split by user-need into **tutorials / how-to / reference / explanation**. | The canonical taxonomy the user is rediscovering by hand. Clean map: *conventions & how-tos ≈ how-to guides*; *codemap ≈ reference*; *architecture rationale & ADRs ≈ explanation*. Gives the split principled names and a "one need per doc" test. |
| **matklad `ARCHITECTURE.md`** ([essay](https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html)) | The lean/stable school: "describe things unlikely to change… unaffected by code changes… revisit a couple times a year." A **codemap**, and deliberately **avoids links** (they go stale — use symbol search). | Directly contradicts jim's current living-inventory implementation. The target shape for a slimmed `ARCHITECTURE.md`. |
| **ADR / MADR** ([Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), [MADR](https://adr.github.io/madr/)) | Append-only, immutable decision records: Title, Status, Context, Decision, Consequences. | **The fix for the "As of spec N…" changelog rotting inside conventions.** Decisions belong in dated immutable ADRs; the convention doc states only the *current* rule. |

### Tier 2 — Study for specific patterns

| Source | Pattern to borrow | Caveat |
|---|---|---|
| **arc42** ([org](https://arc42.org/overview)) | 12 optional sections; **§9 = ADRs**, **§10 = quality tree**. Explicit lean stance: "defer documentation of volatile parts… leave abstract until stable"; Level-1 view "remains quite stable." | It's a template, not a loader — informs *what stays* in the lean architecture contract. |
| **C4 model** ([c4model.com](https://c4model.com/)) | Context/Container = stable (contract); Component/Code = volatile. Code level "not recommended for long-lived documentation… generate on demand." | Justifies architecture-contract vs generated-codemap split precisely. |
| **GitHub Spec Kit** ([repo](https://github.com/github/spec-kit)) | `constitution.md` at `.specify/memory/` — a single always-on doc of non-negotiable principles. | Good "principles" tier (≈ karpathy skills); one file, not a corpus. |
| **OpenSpec** ([customization](https://github.com/Fission-AI/OpenSpec/blob/main/docs/customization.md)) | `config.yaml` with `context` (always-injected) + `rules` (per-artifact-type). | Reinforces: always-on context must stay small; scope the rest. |
| **Packmind** ([repo](https://github.com/PackmindHub/packmind)) | The only surveyed tool with real **governance** — ownership, approval, adoption tracking; can inspect a codebase and *propose* standards. | Much heavier than jim wants; study the lifecycle, don't embed. |
| **Ruler / Block AI Rules** ([Ruler](https://github.com/intellectronica/ruler), [Block](https://github.com/block/ai-rules)) | Canonical rules in one dir, **rendered/synced** into `CLAUDE.md`/`AGENTS.md`/`.cursor`/`.github/instructions`; drift detection; nesting. | The cross-agent adapter layer. Ruler is beta; Block is Rust/smaller. Maps to jim's Roadmap-Later cross-agent goal — **defer**. |
| **Matt Pocock skills** ([repo](https://github.com/mattpocock/skills)) | ADRs in `.agents/`; procedures kept as skills, not prose; a `CONTEXT.md` for shared vocabulary. | ⚠ The specific "CONTEXT.md = thin pointer file" claim is **only partially verifiable** — ADRs-as-skills is confirmed; the pointer mechanism is not. |
| **AGENTS.md** ([agents.md](https://agents.md/)) | Portable, agent-neutral entry file; nested with closest-file precedence. | **No metadata/frontmatter standard** — a bare AGENTS.md can become the same monolith. Good *render target*, not a source of truth. |
| **"Living Architecture" template** ([ceaksan.com](https://ceaksan.com/en/living-architecture-ai-architectural-documentation)) | The *opposite* pole from matklad: 10 core sections as a continuously-maintained "documentation infrastructure." | This is the school jim's current template + spec 013 landed in — and precisely why it bloats. Named here as the anti-pattern to move away from. |

### Tier 3 — Reference / wrong abstraction

- **open-gsd/gsd-core** ([repo](https://github.com/open-gsd/gsd-core)) — ⚠ **Claim debunked:** it does *not* "map code into seven scoped knowledge documents." Its code-map output is essentially **one** file (`.planning/codebase/STRUCTURE.md`); the rest of `.planning/` is pipeline state, routed by phase, not glob/semantic. Active repo, but not the corpus precedent it is sometimes cited as.
- **obra/superpowers**, **addyosmani/agent-skills** — process/quality-gate *skill libraries*; relevant to the *how-to-as-skill* half, not the conventions half. addyosmani's *Overview → When to Use → Process → Rationalizations → Red Flags → Verification* shape is the best behavioral-guide template (already noted in the brainstorm).
- **multica-ai/andrej-karpathy-skills** — a 4-principle constitution; model for a tiny always-on `Principles` block, not a corpus.
- **Cursor / Copilot / Cline rules** — all confirmed real path-scoped systems (`.cursor/rules/*.mdc` globs, `.github/instructions/*.instructions.md` `applyTo:`, `.clinerules/` one-concern-per-file). They are *render targets* for a sync layer, and evidence that path-scoped conventions are now an industry-standard shape.

## Security & Performance (evidence, risks, constraints)

**The evidence base is real** — all four commonly-cited statistics trace to 2026 arXiv papers (it's easy to assume some are fabricated; they are not):

- **AGENTS.md improves efficiency** — 124-PR paired study: median runtime −28.6%, output tokens −16.6%, comparable completion ([2601.20404](https://arxiv.org/abs/2601.20404)). *A good instruction file pays for itself.*
- **Context files dominate; skills/subagents stay shallow** — 2,926-repo study ([2602.14690](https://arxiv.org/html/2602.14690v1)).
- **Mixed corpora are the common failure** — 100-repo "configuration smells": **Lint Leakage 62%, Context Bloat 42%, Skill Leakage 35%; 91/100 files carry ≥1 smell** ([2606.15828](https://arxiv.org/abs/2606.15828)). Jim's `ARCHITECTURE.md` exhibits all three.
- **Size alone is not the villain** — a 1,650-session factorial study found **no statistically detectable adherence difference** from file size/position/structure (Bayesian affirmative-null) ([2605.10039](https://arxiv.org/abs/2605.10039)). **Implication: treat ≤200 lines as an attention/maintenance budget, not a correctness threshold. The real problem is wrongly-*typed* knowledge, not raw line count** — which is exactly why "split by job" beats "just trim."

**Risks/constraints for any jim design:**
- **VISION non-goals bind the automation.** "Transparency over automation" and human-in-the-loop at every gate mean auto-generation/auto-sync must stay opt-in and reviewable (jim already models this with `auto_*` flags defaulting `false`).
- **Untrusted-content boundary.** A convention/how-to corpus that agents write from codebase scans inherits the same injection surface jim already guards in the issue pipeline — normative docs must be reviewed, not silently promoted (Packmind's approval model is the reference).
- **Don't double-maintain.** Canonical content in one place; `CLAUDE.md`/`AGENTS.md`/rules as *generated* adapters, never hand-forked copies (Ruler/Block lesson).

## Recommendations (options + trade-offs — for PM/Architect, not decisions)

**R1 — Adopt the "one job per artifact" taxonomy.** This is the load-bearing result. Each type gets one home and one loading mode:

| Type | Contains | Native loading |
|---|---|---|
| Architecture contract (`ARCHITECTURE.md`, lean) | boundaries, dependency direction, ownership, trust boundaries, invariants, ADR links | always (kept ≤~150 lines) |
| Convention | normative rules (layout, language, testing, error handling) | `.claude/rules/*.md` with `paths:` — **native fileMatch** |
| How-to / runbook | ordered procedures (build, migrate, add-form) | manual `@`-ref / skill `description` match |
| ADR | one immutable decision + rationale | read when relevant |
| Codemap (optional) | current components/entry points/stores | generated, retrieved on demand — never a locked contract |

**R2 — Shrink `ARCHITECTURE.md` to a contract + index** (matklad/arc42/C4-backed). Move Plugin Conventions → convention files; move Project Structure/diagram → an optional generated codemap; convert the "As of spec N…" prose → ADRs. Keep a one-paragraph identity + link per moved topic (the brainstorm's boundary rule is exactly right).

**R3 — Build on native primitives; do not invent a metadata/loader.** A custom `load: always|path|semantic|manual` + `applies_to` frontmatter would largely duplicate native `.claude/rules/` `paths:` and Skill `description`. Recommendation: canonical docs under `docs/` (or `.claude/rules/` directly), lean frontmatter (`kind`, `status`, `last_verified`, `related`), and let native `paths:` do routing. This is *cheaper and more robust* than a bespoke loader.

**R4 — Reconcile the command surface (decision fork for PM).**
- *Option A — Widen `jim:howtos` into `jim:knowledge`:* one skill managing conventions + how-tos + ADRs, with `/jim:arch` slimmed to the contract. Most coherent; largest scope.
- *Option B — Ship `jim:howtos` as-scoped (how-tos only) now, add `jim:convention` + ADRs later:* fastest path, lowest risk, matches the ready brainstorm; risks a second migration when conventions get their own home.
- *Option C — Minimal:* only slim `/jim:arch` + add a `conventions/` rules dir, no new command. Least tooling; leans on native rules entirely.
- **Recommendation: B then A** — ship the ready how-to slice, but scope its spec knowing conventions/ADRs are coming, so the directory layout and `/jim:arch` boundary don't need reworking.

**R5 — Replace the unconditional post-build `/jim:arch` (spec 013) with change-type routing:** contract/ownership/trust change → `/jim:arch`; component/integration change → regenerate codemap; pattern change matching a convention's `paths:` → flag that convention for review; cosmetic rename → nothing. Preserves 013's anti-drift intent without rewriting a 491-line doc after every build.

**R6 — Defer the cross-agent sync layer** (Ruler/Block pattern) to the Roadmap-Later cross-agent phase. Note it now so the corpus is authored canonically (single source) from day one, making later rendering to `AGENTS.md`/Cursor/Copilot mechanical.

## Peer Feedback

**For PM (reshapes BACKLOG Task 0002 `jim:howtos`):**
1. **Widen the frame before `/jim:spec`.** The user's problem is the whole corpus (conventions + how-tos + ADRs + a lean contract), not how-tos alone. Decide R4 (A/B/C) first — it changes the spec's directory layout and the `/jim:arch` boundary. My recommendation: B-then-A.
2. **Good news that de-risks the brainstorm:** its "no new primitive needed — `paths:` is native" assumption is **now confirmed** against official docs. The Conditional inclusion mode is free. One nuance: `@imports` are *eager* (don't save context) — use rules/skills `paths:` for lazy loading, not imports.
3. **Conventions ≠ how-tos.** The brainstorm folds behavioral conventions and procedures together under "HOWTO variants." Diátaxis says these are different genres with different loading needs (conventions want `always`/`fileMatch`; how-tos want `manual`). Worth splitting in the spec.

**For Architect:**
4. **Reconsider spec 013** per R5 — the unconditional refresh is the churn engine once concerns are separated.
5. **Dogfood target:** jim's own `ARCHITECTURE.md` (491 lines) violates the native ≤200-line guidance and exhibits all three measured "configuration smells." It is the ideal first migration (the brainstorm's "Immediate Candidates" table already scopes it).

**Fact-check corrections** (accuracy pass):
- ⚠ **Debunked:** GSD Core does *not* map code into "seven scoped knowledge documents" (≈ one `STRUCTURE.md` + pipeline state).
- ⚠ **Partially unverified:** Matt Pocock's "CONTEXT.md as thin pointer file."
- ✅ **Confirmed:** native `.claude/rules/` `paths:`; Kiro's 4 inclusion modes; all four arXiv statistics; Packmind's inspect-and-propose + governance; Ruler/Block sync + drift detection.

## Alignment

Aligns with **VISION** (living documents as compounding institutional memory; convention-over-configuration; native to Claude Code) — a typed corpus *is* the vision executed at scale. Aligns with **ROADMAP-Later** (configurable paths; cross-agent integration — the sync layer). **One tension to hold:** VISION's "transparency over automation" and human-in-the-loop non-goals constrain any auto-generation/auto-sync to opt-in, reviewable flows — consistent with jim's existing `auto_*`-defaults-false pattern, so no divergence, but the corpus's write paths must honor it. No conflict with a locked ARCHITECTURE constraint — the recommendation is precisely to *relax* how that document is scoped.
