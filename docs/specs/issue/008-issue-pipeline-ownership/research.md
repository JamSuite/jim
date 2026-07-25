---
spec: "docs/specs/issue/008-issue-pipeline-ownership/spec.md"
status: Active
date: "2026-06-20"
---

# Research: Pipeline-ownership filter for candidate batches

## Anchors

The seven candidate-batch sites carry the bug surface. The fix adds a third filter; AC5 touches the plan Out-of-Scope framing; AC7 adds a meta-skill checklist line.

- `skills/spec/SKILL.md:178` (§11 batch) — filters `:197-198`, liberal heuristic `:185`.
- `skills/research/SKILL.md:133` (§10) — filters `:152-153`, heuristic `:140`.
- `skills/plan/SKILL.md:131` (§10) — filters `:150-151`, heuristic `:138`. **Out of Scope** plan-template section listed at `:107`; the batch materializes "from design decisions deferred … open questions raised during planning" at `:138` — this deferred→candidate link is what AC5 must split.
- `skills/build/SKILL.md` — completion gate `:111` (§6); **arch refresh** invokes /jim:arch at `:131` (§6.2); **end-of-build candidate batch** `:133`/`:135` (§6.3); filters `:156-157`. The build batch runs *after* the arch refresh, so its Resolution filter already catches an arch-regen candidate raised *in build* — but nothing re-examines one filed earlier in **plan** (the cross-phase bug, AC2).
- `skills/brainstorm/SKILL.md:72` (§6) — filters `:91-92`, heuristic `:79`.
- `skills/debug/SKILL.md:65` (§4) — filters `:84-85`, heuristic `:72`.
- `skills/sec/SKILL.md:223` (§14) — **structural variant**: materializes candidates only from `Route: Issue` findings (`:230`), severity→priority map (`:232-234`), finding-specific Resolution filter (`:248`); Actionability filter `:249` matches the others.
- `skills/meta-skill/SKILL.md:85-118` — the "### 4. Validate" checklist (Frontmatter / Structure / Scripting Layer / Anti-patterns subsections; `- [ ]` items). AC7's prevention line lands here. Existing anti-pattern at `:114`: *"No duplicate logic (same instructions in 3+ places → extract to a shared skill)."*
- `docs/specs/issue/002-issue-tracking-workflow-integration/spec.md:60-62` — the "**Security and Safety**" AC (untrusted-content rule) the skills cite. This is the *only* candidate-batch contract single-sourced in 018; the Resolution/Actionability filters are **not** defined here — they live only in the skill bodies.

## Local Patterns

- **Filters are duplicated, not single-sourced.** The Resolution + Actionability pair is copy-pasted verbatim across six skills; sec is a reworded variant. spec 018 defines the *untrusted-content* rule once (`018/spec.md:60-62`) and each skill carries a one-line *reference* to it ("per spec 018 § Security and Safety"). So jim already has a precedent for "define once in the 018 contract, reference from each skill" — but it has only been applied to the untrusted rule, never the filters.
- **No bash-test harness for SKILL.md prose.** Prose conventions are policed by the meta-skill Validate checklist + ARCHITECTURE.md guidance + manual fixtures, never a bash linter (specs 011/012 rejected linters explicitly). The candidate-batch steps are pure prose — there is no test file to template from, and none should be created (matches AC6/AC7).
- **Config knobs:** `issue_capture` (default `"true"`) gates the batch; `auto_issue_file` (default `"false"`) selects interactive vs auto path — both via `skills/conf/scripts/jimconf.sh get`.

## Security & Performance

- No new attack surface. The pipeline-ownership filter only *drops* candidates — it never reads new untrusted input. The existing untrusted-content discipline (`018 § Security and Safety`) is unchanged.
- The deferred retroactive-sweep (out of scope) is the only proposed mechanism that would read issue bodies (untrusted content) — correctly excluded from this spec.

## Recommendations

**Alignment:** this fix directly serves VISION's Non-Goal that issue capture is *"only a discovery artifact … not a team-coordination primitive"* — dropping pipeline-owned work removes non-discovery noise — and follows the documented candidate-batch model at `ARCHITECTURE.md:203`. No divergence from a locked constraint.

For the architect (Handoff Insights 1 & 2):

- **Insight 1 (single-source vs per-skill).** Adding the new filter to all 7 skills re-commits the exact duplication the meta-skill anti-pattern (`meta-skill:114`) warns against. Two viable shapes: **(a)** state the pipeline-ownership filter once in the 018 contract (alongside the untrusted rule at `018:60-62`) and have each skill reference it by phrase — consistent with the existing single-sourced clause and minimizing new duplication, though skills can't *execute* a shared include, so the normative wording still has to live where the agent reads it; **(b)** inline it at each batch site, matching today's duplicated Resolution/Actionability pattern — lowest blast-radius, but 7× duplication and drift risk (sec already diverged). Recommend (a) for the normative wording plus a short inline cue per skill; either way, sec's variant must be handled.
- **Insight 2 (canonical action set) — resolved.** Confirmed pipeline-owned actions a candidate could redundantly track: **(1) ARCHITECTURE.md regen** via the /jim:build→/jim:arch gate (`build:131`; governed by spec-013 `auto_arch_feedback`, `arch:85-91`) — the strong, realistic trap; **(2) the plan/build security gate** re-running /jim:sec (`plan:39-46`, `build:40-47`) — plausible as a candidate. **INDEX.md regen** (`issue/SKILL.md:149`, `ARCHITECTURE.md:77`) is technically pipeline-owned but fully internal to the issue scripts — no agent would realistically surface "regenerate INDEX.md" as a candidate. No further auto-maintenance actions qualify (researcher auto-spawn and security auto-routing are workflow orchestration, not maintenance a follow-on would track).

## Peer Feedback

For the PM (pre-approval spec refinement):

- **AC1's example list (recommend edit).** AC1 names "regenerating `INDEX.md`" as a canonical example of pipeline-owned work. Research shows INDEX regen is an internal side-effect of the issue scripts, never an agent-materialized candidate — a weak illustration that muddies the filter's intent. Recommend leading with **ARCHITECTURE.md regen** (the real trap) and using **the plan/build security-gate re-run** as the second example; drop or demote INDEX.md regen. Low-effort edit; sharpens AC1 without changing scope. **Applied** to spec.md AC #1 (INDEX.md example dropped; security-gate re-run promoted).
- **AC7 placement is clean.** The meta-skill Validate checklist (`:85-118`) is subsection-organized; a new item fits naturally (a "Candidate batch (when present)" line, or under Anti-patterns near `:114`). No structural obstacle.
- **Insight 1 has a documented tension worth a deliberate call at plan time:** jim's own meta-skill checklist flags 3+-place duplication as an anti-pattern, yet the candidate batch is already duplicated 7×. The plan should consciously decide whether 024 extends that debt or starts paying it down.
