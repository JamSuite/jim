---
origin: docs/research/20260717-architecture-knowledge-corpus.md
supersedes: docs/brainstorms/20260512-jim-howtos.md
---

# Brainstorm: Scaling jim's project-knowledge corpus — the /jim:arch knowledge ladder

*2026-07-17*

Supersedes and extends [`20260512-jim-howtos.md`](20260512-jim-howtos.md) (the original "decompose
ARCHITECTURE.md into HOWTOs" thinking). Grounded in the deep-dive research
[`docs/research/20260717-architecture-knowledge-corpus.md`](../research/20260717-architecture-knowledge-corpus.md).
The 05-12 doc is still worth reading for its 9-project prior-art survey and the settled how-to
mechanics; this doc widens the frame from *how-tos* to the *whole knowledge corpus* and answers the
command-model question the 05-12 doc left open.

## Problem & goal

`ARCHITECTURE.md` doesn't scale, because one always-loaded file does **four jobs with four different
update cadences**:

1. **Architecture contract** — stable boundaries, dependency direction, ownership, trust, invariants.
2. **Codemap** — directory tree, components, entry points (churns with every commit).
3. **Engineering standards** — layout, language conventions, testing, error handling.
4. **Operational how-tos** — build, release, migrations.

jim's own repo is the exhibit. `ARCHITECTURE.md` is **491 lines** (native guidance is ≤~200): a
208-line "Plugin Conventions" section (`:272-479`) of pure engineering-standards embedded in an
always-loaded doc, an 80-line Project Structure + 85-line diagram (`:9-175`) doing the volatile
codemap job, and decision history narrated inline as **"As of spec 017…018…019…022…023…025…"**
changelog prose crammed into three bullets (`:309-311`) — a missing-ADR symptom. The 100-repo
"configuration smells" study ([2606.15828](https://arxiv.org/abs/2606.15828)) names exactly these:
jim's file exhibits all three measured smells (Lint Leakage, Context Bloat, Skill Leakage).

**Convergent real-world evidence.** In another project the operator already solved this by hand:
renamed "howtos" → an `arch/` folder of topic files (`BUILDING_RELEASING.md`, `PROJECT_LAYOUT.md`,
`FRONTEND_ARCHITECTURE.md`, `BACKEND_ARCHITECTURE.md`, `CICD.md`, `DATA_MIGRATIONS.md`) and manually
edits `ARCHITECTURE.md` to link out to them. Note what that instinct reveals: humans organize
knowledge **by topic**, and those topic files freely mix genres (`PROJECT_LAYOUT` is a convention,
`BUILDING_RELEASING` is a how-to, `CICD` is both). The hand-maintained topic docs get used; the
monolith doesn't.

> **Goal.** Make jim's architecture/knowledge documentation *scalable*: a lean, stable
> `ARCHITECTURE.md` **contract + index**, with topic knowledge extracted into a configurable `arch/`
> folder, each artifact self-describing its type so its loading mode is derivable — **without**
> forcing the operator (or Claude) to choose between competing commands. Upgrade `/jim:arch` from a
> monolith-generator into the corpus **librarian**, and make the spec→plan→build pipeline recognize
> (and know when *not* to suggest) extraction candidates.

## What changed since 2026-05-12

The 05-12 brainstorm proposed a standalone `/jim:howtos` command. The research widens and corrects
that in four load-bearing ways:

- **The problem is the whole corpus, not how-tos.** Conventions, how-tos, decisions, and the codemap
  are distinct genres (Diátaxis) with distinct loading needs — folding them all under "HOWTO
  variants" was too narrow.
- **The native loading mechanism already exists.** `.claude/rules/*.md` with `paths:` frontmatter is
  literally Kiro's `fileMatch` mode, for free — a rule loads lazily only when a matching file is
  read. **jim should not invent a loader.** (`@imports` are *eager* — they organize, they don't save
  context; use `paths:`/skills for lazy loading.)
- **The codemap is optional and volatile** — "never a locked contract" (research R1; matklad; C4's
  code level). It's exactly the Project-Structure + diagram bloat in today's contract.
- **ADRs fix the changelog rot.** The "As of spec N…" prose belongs in dated, immutable decision
  records; the convention doc should state only the *current* rule.

**Still valid from 05-12, carry forward:** the ARCHITECTURE↔topic **boundary rule** (keep the
one-paragraph identity + link, move the recipe out); the observation that one template won't fit all
(the tauri prior art) — now expressed as `kind`s, not template variants; the **proactive-suggestion
heuristics** (10-line rule, third-time's-the-charm, failure-loop) and the **"when NOT to suggest"**
list; `/jim:arch`-as-librarian; Manual-first loading; slug naming; `evergreen`/`deprecated` lifecycle.

## The organizing model: the knowledge-rung ladder

"Which command?" was never the real question. The real question for any piece of project knowledge
is: **which artifact type is its right home?** There is a spectrum — and the operator's own doubts
("`/jim:convention` vs `/jim:howtos` — will I know which to use? Will Claude?") dissolve once you see
that *genre determines where a doc lives and how it loads, not which command creates it*.

| Rung | Artifact | Its job | Home | Loading | Belongs here when |
|---|---|---|---|---|---|
| **Contract** | `ARCHITECTURE.md` | how the system **IS** (stable) | repo root | always-loaded | boundaries, dependency direction, ownership, trust, invariants |
| **Convention** | `kind: convention` doc | how the agent should **BEHAVE** (guidance/style) | `docs/arch/` | `paths:` rule (lazy) | adopt-while-coding; you want it legible & hand-editable (e.g. your Django-form style) |
| **How-to** | `kind: howto` doc | how to **DO X**, as reference | `docs/arch/` | `@`-ref / index link | consulted occasionally; low agency |
| **Procedure (active)** | **project skill** | **DO X** on demand, consistently | `.claude/skills/` (indexed from the corpus) | `description` trigger | it's a *verb* you'd invoke; recurs; you want identical execution (e.g. `add-svelte-component`) |
| **Decision** | `kind: adr` doc | **WHY** we chose X (immutable) | `docs/arch/` | read when relevant | rationale that would otherwise rot as "As of spec N…" |
| **Enforceable** | **hook / lint / test** | a machine-checked rule | `settings.json` / tooling | automatic | drift is unacceptable *and* a machine can check it |
| **Codemap** | `kind: codemap` doc | what **EXISTS** now (volatile) | `docs/arch/` | generated on demand | never a locked contract |

Read top-to-bottom, the executable rungs form a **promotion ladder**:

> `ARCHITECTURE.md prose` → `docs/arch/ topic doc` → `project skill` → `hook / lint / test`

This is the same escalation as "when does a rule become a linter?" The answer to *both* "when does a
doc become a skill?" and "when does it become a hook?" is one rule: **knowledge graduates a rung when
it moves from something the agent should *read*, to something it should *do*, to something a machine
should *enforce*.**

### Doc → skill: the hardest fork, answered concretely

- **Noun vs verb.** A doc is "the migration procedure"; a skill is "migrate the database." If you'd
  *invoke* it, it's a skill. If you'd *read* it, it's a doc.
- **Agency & recurrence.** Runs often + you want identical execution → skill (wrap the deterministic
  part in a script). Rare, one-off, or mostly-judgment → doc.
- **Clear trigger.** "When adding a component…" earns a skill's `description`-match. Ambient style
  the agent should just *know while coding* does not — that's a `paths:`-scoped convention doc.

**Worked examples (the operator's own cases):**
- *Django form conventions* = **convention doc**, `paths:`-scoped to form files. You invoke nothing;
  you want the style adopted ambiently, and you want to *find it and edit it easily* — a doc in
  `docs/arch/`, not something buried.
- *`add-svelte-component`* = a genuine **skill** — invokable verb, recurs, benefits from identical
  execution, has a natural trigger.
- *database-migrations* = **splits across rungs.** The "expand-contract, never destructive" rule is a
  convention doc; "run a migration" is a skill (+ script); "no raw SQL in a migration" is a
  lint/hook. **A "topic" is not one artifact** — the librarian may decompose it.

### On "skills feel buried in `.claude/`, and dynamic loading is opaque"

That opacity is a **real design input**, not just a preference — and it shapes two rules:

1. **Default to a doc.** Only promote to a skill when the invokable-verb nature clearly wins. Docs in
   `docs/arch/` are plainly visible, git-diffable, and hand-editable — the operator's stated need.
2. **One cross-rung index.** The librarian maintains a single index (owned by `ARCHITECTURE.md` / the
   arch folder) that lists the project's **skills and hooks alongside its docs**. A `SKILL.md` in
   `.claude/skills/` is still discoverable, reviewable, and editable from the same place as
   everything else. The "hidden + opaque loading" problem dissolves without giving up skills where
   they earn their keep.

### Guardrails

Every promotion — extract-to-doc, promote-to-skill, enforce-with-hook — is a **proposal jim shows as
a diff for human approval**. Nothing auto-promotes. This honors VISION's "transparency over
automation" and "human-in-the-loop at every gate," consistent with jim's existing
`auto_*`-defaults-`false` pattern. jim *proposes* the rung and the rationale; the human decides.

## The command model: consolidate around /jim:arch — no command fleet

The research (R4) sketched a possible fleet (`/jim:map`, `/jim:convention`, `/jim:howto`,
`/jim:knowledge sync/check`) and even recommended a phased "ship howtos, add conventions later"
(B-then-A). **We diverge:** a fleet re-introduces exactly the "which command do I use, will Claude
know?" problem. The ladder shows why we don't need one — genre is *frontmatter*, not a command.

**Recommendation: one command surface, `/jim:arch`, upgraded to the corpus librarian.**

- **`/jim:arch`** maintains the lean `ARCHITECTURE.md` contract + the cross-rung index, and gains the
  librarian behaviors: (a) **extract** a high-density section to `docs/arch/<topic>.md` and replace
  it with a one-paragraph identity + link; (b) **place/route** by writing `kind:` frontmatter so
  loading mode is derivable; (c) **link** — keep the index and the in-doc back-links current;
  (d) **prune** — flag topic docs whose referenced code no longer exists (never auto-deprecate).
- **Drop `/jim:map`.** "map" is confusing and the codemap is optional. Handle it as a regenerated
  `docs/arch/codemap.md` (or a clearly-labeled "generated, may drift" appendix) — no command.
- **Absorb `jim:howtos` (BACKLOG Task 0002).** "howto" becomes a `kind:`, not a command. The 05-12
  design isn't lost — its mechanics move onto the ladder.
- **Executable-rung scaffolding is a v1.x follow-on.** Ship the *doc* rungs and the *ladder model*
  first; the skill scaffolder and hook/lint generator come after (see Follow-ons).

**Tradeoff, stated honestly:** this front-loads more `/jim:arch` work than shipping how-tos alone,
but it buys **one mental model and no second migration** when conventions/ADRs arrive. `.claude/rules/`
and `AGENTS.md` remain **deferred render/sync targets** (research R6) — we author canonically in
`docs/arch/` (matching the operator's habit) and render to those later, never hand-fork.

## The ARCHITECTURE.md ↔ topic boundary rule (from 05-12, still exactly right)

`ARCHITECTURE.md` keeps the **one-paragraph identity** of each topic (what it is, why it exists,
where it lives) + a link; the topic doc holds the recipe (rules, examples, anti-patterns). The "As of
spec N…" prose is *not* a convention — it's decision history, and it moves to ADRs. This is the
smallest change that fixes bloat while keeping `ARCHITECTURE.md` a navigable orientation doc.

## Proactive suggestion — and when NOT to

The pipeline should notice extraction/promotion candidates *where the pattern is fresh and context is
loaded* — not nag. Carry the 05-12 heuristics forward:

- **`/jim:plan`** — the "10-line rule": architect writing >10 lines of *how* inside Implementation
  Anchors → suggest a doc/skill.
- **`/jim:research`** — "third time's the charm": same pattern in 3+ files with drift.
- **`/jim:debug`** — "failure loop": a bug caused by violating an undocumented convention → suggest
  capturing it (each debug→doc is "never again").
- **`/jim:brainstorm`** — **end-of-session routing offer only.** When a session concludes with "this
  is how we'll handle X going forward," offer to hand the candidate to `@jim:architect` for
  placement on the ladder.

**When NOT to suggest:** during `/jim:spec` (the pattern doesn't exist yet); during `/jim:build` (too
late — should have been planned); mid-`/jim:brainstorm` (stays open-ended); for one-offs (threshold =
3+ uses or a would-bite-again failure); for strategic docs; and when a script/hook already fully
captures the rule (the enforcement *is* the doc).

## Named follow-ons

- **[1] Rework spec 013 (the churn engine) → change-type routing.** Today `/jim:build` unconditionally
  invokes `/jim:arch` post-build (spec 013 even lists change-detection and delta-scan as *out of
  scope*). Reverse that: contract/ownership/trust change → refresh `ARCHITECTURE.md`;
  component/integration change → regenerate the codemap; a pattern matching a convention's `paths:` →
  flag that convention for review; cosmetic rename → nothing. Preserves 013's anti-drift intent
  without rewriting a 491-line doc after every build.
- **[2] Dogfood: slim jim's own `ARCHITECTURE.md`.** The ideal first migration. Extract Plugin
  Conventions (`:272-479`) into `docs/arch/` topic docs (directive-vocabulary, substitution-sigils,
  scripting-layer, bash-testing…), convert the `:309-311` "As of spec N" bullets to ADRs, move
  Project-Structure + diagram to a `codemap` doc, leaving a lean contract + index under the ~200-line
  target. Proves the ladder on jim itself.
- **Executable rungs (v1.x).** Scaffold *promotion*: propose-a-hook/lint/test for enforceable rules
  (reusing native Claude Code hooks / the `update-config` surface / jim's `pre_commit` &
  `pre_completion` keys — no new primitive), and a **project-skill scaffolder** for doc→skill
  promotion. Note this is distinct from `jim:meta-skill` (which builds *jim-plugin* skills, not the
  operator's project skills) and overlaps BACKLOG Task 0019 (extensibility / a per-project "kim").
- **Cross-agent sync (Roadmap-Later).** Render the canonical corpus into `.claude/rules/`,
  `AGENTS.md`, Cursor/Copilot formats (research R6; Ruler/Block pattern). Flagged now so the corpus
  is authored single-source from day one, making later rendering mechanical.

## Open questions for the /jim:spec interview

- [ ] **Folder name & config key.** `docs/arch/` (matches the operator's habit) with a new
      `jimconf.toml` key (default `docs/arch`)? Key name — `arch`, `arch_docs`, `knowledge`?
- [ ] **ADR mechanism.** Full MADR files, or a lightweight dated `docs/arch/decisions/` log? How do
      the "As of spec N" bullets convert — one ADR per spec, or one per decision?
- [ ] **Librarian shape.** A `/jim:arch` subcommand set (`extract`, `link`, `prune`), or a new mode
      of `@jim:architect`? Does extraction stay interactive-only in v1?
- [ ] **Which rungs ship in v1.** Doc rungs (convention/howto/adr/codemap) + the ladder model + the
      index in v1; skill/hook *scaffolding* deferred to v1.x — confirm the cut.
- [ ] **`kind` set & frontmatter.** Finalize `kind` values and shared frontmatter (`kind`, `status`,
      `last_verified`, optional `paths:`, `related`).
- [ ] **Cross-rung index.** Where does it live and how is it rendered — a section in `ARCHITECTURE.md`,
      a generated `docs/arch/INDEX.md`, or both? (05-12 deferred a central index; the ladder makes one
      more justified now, since it must span docs + skills + hooks.)
- [ ] **Which skills get the proactive nudge in v1** (05-12 leaned `/jim:plan` + `/jim:research`;
      this doc adds `/jim:debug` and an end-of-session `/jim:brainstorm` offer).
- [ ] **Project-skill scaffolder vs. `jim:meta-skill` vs. Task 0019 "kim"** — one capability or two?

## BACKLOG bookkeeping

- **Task 0002 (`jim:howtos`)** — reframe as *absorbed* into this effort; "howto" is a `kind`, not a
  command.
- **Task 0019 (extensibility / "kim")** — note the overlap: the doc→skill promotion / project-skill
  scaffolder is the same seam.
- **Task 0006 (VISION)** — the "institutional memory" framing already supports a typed corpus.

## Next steps

### Recommendation: SPEC

The shape is clear enough to scope; the open questions above are exactly what the PM interview should
resolve. Scope v1 to the **doc rungs + ladder model + librarian + index**, with the executable rungs
and spec-013 rework as fast-following specs.

### Prompt for `/jim:spec`

```text
/jim:spec jim:arch-knowledge-corpus

Upgrade /jim:arch from a monolithic ARCHITECTURE.md generator into a project-knowledge "librarian"
that maintains a lean ARCHITECTURE.md contract + a cross-rung index, and extracts topic knowledge
into a configurable arch/ folder (default docs/arch/, new jimconf.toml key). Each topic doc carries
`kind:` frontmatter (convention | howto | adr | codemap) so its native loading mode is derivable —
no new loader, no command fleet. v1 = doc rungs + the knowledge-rung ladder model + librarian
extract/link/prune + the index. Absorbs BACKLOG Task 0002 (jim:howtos): "howto" becomes a kind.
Origin: docs/brainstorms/20260717-jim-arch-knowledge-corpus.md (see for the ladder table, the
doc→skill/hook discriminators, the boundary rule, proactive heuristics, and open questions).
Research: docs/research/20260717-architecture-knowledge-corpus.md.

Interview around: folder name + config key; the kind set + shared frontmatter; ADR mechanism;
librarian as subcommands vs. an @jim:architect mode; where/how the cross-rung index is rendered;
which skills get the proactive nudge in v1; and the v1-vs-v1.x cut (doc rungs now; skill/hook
scaffolding later).

Fast-follow specs (scope-aware now, build later): [1] rework spec 013's unconditional post-build
/jim:arch refresh into change-type routing; [2] dogfood-slim jim's own 491-line ARCHITECTURE.md
using the new librarian.

Non-goals (v1): no /jim:map command; no cross-agent sync to .claude/rules/ or AGENTS.md (Roadmap-
Later render target); no auto-promotion (every extract/promote/enforce is a diff-reviewed proposal).
```

## What changed since 2026-07-17 (the blueprint branch)

*2026-07-24*

Specs 026-052 (`feat/blueprint`) shipped `/jim:review`, the blueprint system (`000-blueprint` living
specs, the `BLUEPRINT.md` context map, the contract graph, `/jim:verify`, `/jim:partition`), and the
pipeline ledger — none of which existed when the ladder above was drawn. They land directly on the
ladder's endpoints and on two of the follow-ons: the v1 shape **narrows and de-risks**, but the model
itself holds. Grounded in `docs/features/{blueprints,review,ledger}.md` and the blueprint-aware
competitive refresh `docs/research/20260724-competitive-landscape-sdd-skills.md`.

- **Blueprints claimed the Contract and Enforceable rungs — re-scope the corpus to the middle.**
  *Contract:* the `000-blueprint` now carries criticality-graded, load-bearing **invariants**, and
  `BLUEPRINT.md` carries boundaries/ownership/dependency-direction as the partition + derived contract
  graph — a *verifiable* second home for what the Contract rung held (the blueprint reads
  `ARCHITECTURE.md` as a source, so they coexist). *Enforceable:* the verify engine's `Check`
  vocabulary (`pattern`/`structure`/`registry:<name>`/`judge`) is a **declarative** enforcement path —
  attach a check to an invariant and the engine runs it — instead of "promote the doc to a hook" for
  architectural rules. **Consequence:** re-center the corpus on the rungs blueprints deliberately
  exclude — **convention / how-to / adr / codemap** — and *reference* the blueprint for the two it now
  owns, never duplicate them.

- **The librarian's hardest unbuilt mechanics already exist — reuse, don't reinvent.** "Every
  promotion is a diff for human approval" = the blueprint **update guard** + **gate-presentation rule**
  (spec 040). "Extract a high-density section" = the blueprint's **targeted section diff**. The
  `auto_*`-defaults-false autonomy = `auto_blueprint`'s **criticality-graded** writes. The
  present-tense discipline the convention rung needs = spec 050 (`blueprint-present-tense`) + the
  provenance guard (052), already operationalized and policed. The **single-writer surface** is the
  working proof of "the librarian owns the corpus."

- **Follow-on [1] is partly overtaken — merge it with the fold-back loop.** The
  review → `/jim:verify --from-review` → fix-code/fold-intent loop is already a post-build,
  change-scoped, human-gated knowledge refresh — the change-type router [1] wanted, built for
  blueprints. Reconceive [1] not as a bespoke router bolted onto spec 013 but as
  **`/jim:arch --from-review`**, a sibling to `/jim:blueprint --from-review` that shares the review's
  diff classification. There are now *two* post-build knowledge mechanisms (013's `ARCHITECTURE.md`
  refresh and the review loop); [1]'s real job is to **unify** them.

- **Follow-on [2] gains a boundary to define.** jim now has its own `docs/specs/jim/000-blueprint`, so
  dogfood-slimming can't move every invariant into a `kind: convention` doc — some belong in the
  blueprint's invariant floor. First-pass rule: project-wide conventions/orientation → `docs/arch/`;
  group-scoped, verifiable, criticality-graded invariants → `000-blueprint`. jim being single-group
  makes it the *sharpest* place to force that boundary.

- **The ADR rung got a stronger mandate — it is the home for "why".** Blueprints are present-tense by
  doctrine; the ledger is content-free by design — so **neither captures rationale**. Yet the branch
  created exactly the decisions the ADR rung exists for: every **fold-intent vs fix-code** fork and
  every **partition rename/split/merge** is a load-bearing decision whose reasoning otherwise
  evaporates (the ledger keeps only the `op=` count). The corpus's `kind: adr` rung should become the
  home for blueprint fold-back and partition-op rationale. Blueprints didn't fill the ADR gap — they
  **widened** it.

- **A new organizing axis: per-group vs flat corpus.** The doc assumes a flat `docs/arch/`. The
  partition doctrine's vertical-first **groups with code territory** raise a new fork: should
  convention/how-to docs live *with their group* (beside its `000-blueprint`), with `BLUEPRINT.md` as
  the project spine and the cross-rung index folding into it? One for the interview.

**Still right, undisturbed:** the librarian-as-single-authoring-surface call — blueprint/verify/partition
are different *verbs*, not competing authoring commands, so "no fleet for the same act" still holds;
the present-tense discipline (now proven on the blueprint tier); read→do→enforce (blueprints added a
*declarative* enforcement path beside the generative one); and ADRs still needed, more than before.

### Suggested prompt update (left unapplied, per request)

The `/jim:spec` prompt above still describes the pre-blueprint scope. Before scoping this, revise it
to:

- **Narrow v1 to the middle rungs** (convention / how-to / adr / codemap) + librarian + index, stating
  the corpus is **layered on** the blueprint — deferring Contract/Enforceable *content* to
  `000-blueprint` and `/jim:verify`, which now own those rungs.
- **Reframe follow-on [1]** as `/jim:arch --from-review`, unified with the review → verify → blueprint
  fold-back loop, rather than a standalone spec-013 change-type router.
- **Add interview items:** the `ARCHITECTURE.md`-contract ↔ blueprint-invariant boundary; the ADR rung
  as the home for fold-back and partition-op rationale; and flat-vs-per-group corpus layout.
- **Point the librarian at the blueprint's reusable machinery** (update guard, gate-presentation,
  targeted section diff, criticality-graded `auto_`) instead of inventing its own gates.
- **Extend the non-goals:** keep the existing three; add "don't duplicate blueprint invariants in
  convention docs."
