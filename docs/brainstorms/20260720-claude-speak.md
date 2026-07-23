# Brainstorm: "Claude Speak" — evolving jim's writing style toward literal, efficient prose

*2026-07-20*

## The premise

The developer flagged jim's writing as unclear. The opening example was metaphor ("spine", "leg", "upstream"). But metaphor was the symptom that prompted the complaint, not the subject. The subject is in this doc's title: **make jim's prose literal, efficient, specific, and concise.**

A spec or plan is an *execution document* — someone (a human or an agent) builds from it. Any word that a reader has to interpret is a defect: a vague threshold, a term they don't know, a rule buried in rationale, the same instruction said three different ways. Metaphor is one such defect, and a minor one. The larger defects are **vague words that can't be tested**, **redundant restatement**, **undefined terms**, and **rationale padding**.

**Working rule (candidate):** Name an exact value, file, or condition. Say each rule once. Use the imperative. Define any term a new teammate wouldn't know. Cut rationale that doesn't prevent a mistake. No blanket ban on metaphor — just prefer the plain word.

This doc covers: (1) an internal audit of where jim is not literal/efficient/specific/concise, (2) verified external research, (3) whether jim's clarity is instructed or accidental, (4) a plan, (5) expected outcomes.

*This doc tries to model the style it prescribes.*

---

## Task 1 — Internal audit

Full data: `20260720-claude-speak.csv` (61 problem findings + 21 exemplars + 1 accepted-as-is, 30 files, worst first). The audit was run twice: first for metaphor (too narrow), then re-run for the real target — **vague / wordy / redundant / hedging / undefined / indirect** prose, with metaphor demoted to one minor category. The CSV reflects the second, wider run.

Columns: `dimension` (the defect type) and `fix` — **specify** (name an exact value/condition), **define** (gloss a term on first use), **cut** (delete filler), **tighten** (shorten), **imperative** (make it a command), **replace** (plain word for figurative), **keep** (exemplar).

### The defects, by prevalence (this is the real finding)

| Dimension | What it is | Prevalence | Example from jim |
|---|---|---|---|
| **vague** | unmeasurable words; can't test if followed | **highest** | `"For every non-obvious choice, write a Chosen/Why/Rejected block"` — no test for "non-obvious"; also `"reasonable defaults"`, `"where relevant"` |
| **redundant** | same rule restated in the same file or across files | high | `"No code writing — that is the coder's job"` appears in 4 agent files; `"The human decides"` 3× in pm.md |
| **undefined** | acronym/named method used before a one-clause gloss | high | `STRIDE`, `LINDDUN`, `SDLC`, `Peer Feedback`, `Constitution Check`, `Connextra`, `version anchors` |
| **wordy** | rationale that prevents no mistake; motivational padding | medium | `"This respects their priorities and avoids feeling like an interrogation."` |
| **hedging** | tentative where a command is needed | low | `"consider running /jim:vision first"`, `"you might want to create one"` |
| **figurative** | metaphor with a plain synonym | **lowest** | `"You are the early warning system for the PM"` |

**The one cross-cutting fix.** **Cross-file constraint restatement** — the same guardrail constraints (`"No code writing"`, `"never overwrite blindly"`, `"The human decides"`, `"Does NOT fix code"`) are re-typed into many agent and skill files. jim's own meta-skill rule against duplication only triggers at "3+ places" and does not catch cross-file repetition, so these survive. Stating each once clears many lines at once.

**One internal contradiction found:** `roadmap/SKILL.md` says `"More than 5-7 items per bucket"` in one place and `"~7 items"` in its self-check — two thresholds for one rule.

### One accepted exception — not every vague phrase is a defect

The phrase `"include anything an attentive developer might want to revisit"` appears in five skills (spec, build, research, brainstorm, debug) as the accumulation heuristic for the end-of-phase candidate batch: a deliberately broad net that a strict, testable filter (the fileable bar) prunes immediately afterward. It has, in practice, been working well, and we were unable to identify a specific, testable statement that would be a suitable replacement without narrowing the intended net. Leave it as-is. It is the example that *bounds* Rule 1 (Task 4): broadness is acceptable where a strict downstream check does the measurable work and no better testable wording exists. This exception is narrow — it does not cover terminal vague instructions like `"non-obvious choice"` or `"reasonable defaults"`, which have no downstream check to resolve them.

### What jim already does well (the model to propagate)

jim is at its clearest wherever the *domain forces an exact value*:

- `"After 3 consecutive failed Green attempts on the same task: STOP."` (build) — exact threshold + action.
- `"No writes to .git/, ~/.ssh/, node_modules/, .venv/, .env"` (architect) — exact enumerated paths.
- `"LINDDUN activates whenever PII, credentials, or session data is present"` (security) — exact trigger.
- `"else the literal string NOT_FOUND"` (file) — exact contract value.
- `"No confidence scores. No numeric thresholds. The question is structural."` (spec) — replaces a vague gate with one literal test.

The split is clean: skills that touch **contracts** (bash, TDD, frontmatter, path sentinels) are specific and concise; skills that touch **judgment** (pm interview, brainstorm, vision, roadmap) drift vague, because nothing pushes them to name exact conditions. That observation drives the answer to the next question — and Task 1a confirms it holds in the *artifacts* too: jim's ACs (contract-shaped) are excellent, while problem statements and user stories (judgment-shaped) drift vague and verbose.

---

## Task 1a — Internal project audit (Adrian's korswerk projects, built with jim)

These are real artifacts jim produced in Adrian's `korswerk` (Tauri/Rust/Svelte) and `korswerk-django` projects — not jim's own instruction files. This tests how jim *writes in the wild*. Surface: **50 `spec.md` + 23 brainstorms = 73 artifacts**, audited by 7 parallel readers with the same wider lens. Full data: `20260720-claude-speak-project-audit.csv`.

### Headline: jim is strong exactly where it matters most — the acceptance criteria

Across all 50 specs, the ACs overwhelmingly carry exact values: enumerated sets (`Rating ∈ {again, hard, good, easy}`), given/when/then assertions, pixel breakpoints (`248px at lg+`), status codes (`return 401 (not 403/422)`), numeric tolerances (`±0.3`), canonical hash vectors, byte-determinism guarantees. All 7 readers independently concluded the specs are **strong on literal/specific**, and that the weaknesses sit in the *surrounding prose*, not the ACs.

### The four weaknesses (in the prose, not the contracts)

1. **Vague qualifiers that leak into or beside an AC** — the genuine defects, because a coder cannot test them: `"at appropriate levels"`, `"a clear error message"`, `"friendly fallback"`, `"rendered safely"`, `"barebones HTML"`, `"a reasonable student understands"`, `"safe fallback"`, `"coherent content"`. These are exactly Rule 1's target, and they reach the one document a build executes from.

2. **Two untestable-AC species the jim-internal audit did NOT surface:**
   - **"Match the external design" ACs** — `"reproduces the quiz_player design's look, copy, states"`, `"recreates the A · Composer design at high fidelity"`. Acceptance is delegated wholesale to a mockup; nothing in the spec is testable on its own.
   - **ACs that defer their own value to Open Questions** — `"exact ordering field per Open Questions"`, `"copy along the lines of…"`, `"final wording per Open Questions"`. An AC shipped before its measurable value is decided.

3. **Wordy, motivational problem statements and user stories** — narrating pain (`"a learner loses it the moment they press Begin"`, `"a developer hits a dead end"`) instead of constraining behavior. This is where most of the bloat lives.

4. **Redundancy** — one invariant restated across overview / problem / stories / ACs / resolved-questions; Desired-State blocks restating ACs verbatim; per-AC sourcing parentheticals.

### Brainstorms: strong decisions, weak concision

The brainstorms are **strong on literal/specific** — crisp decisions with reasons, numbers, and named tradeoffs (`"vary quantization, never the model (int8 mobile / fp16 desktop)"`). They are **weak on concise**: they accrete history — retracted-then-corrected sections left in full, `/jim` prompt blocks pasted verbatim over the body, restated conclusions, and process-narration (`"honest answer"`, `"two realizations from working it through"`). Expected of ideation, but trimmable on close.

### Verdict

The artifacts **confirm and sharpen the internal thesis.** Same split as jim's own skills: precise in **contract-shaped** content (ACs, schemas, wire formats), drifting vague and verbose in **judgment/narrative** content (problem statements, user stories, UI-fidelity criteria, brainstorm prose). The build-critical part is already good; the fixable debt is narrative bloat plus a small number of untestable-AC leaks.

---

## Task 2 — External research (verified)

I re-fetched three primary sources to check the strongest claims. All three verified verbatim.

**1. deanpeters/Product-Manager-Skills `CLAUDE.md`** — testable rules: "Use short sentences and active voice"; "Define any PM jargon that might confuse an agent"; "Zero fluff: Did you cut every word that doesn't earn its keep?" It explicitly *permits* metaphor: "Include one vivid metaphor or label when it clarifies (e.g., 'feature factory')."

**2. gotalab/cc-sdd `design-principles.md`** — each adjective has an operational meaning: Declarative ("The system authenticates users" not "should authenticate"), Precise ("specific technical terms over vague descriptions"), Concise ("essential information only"), plus "consistent terminology throughout." Best compact rubric to borrow.

**3. getsentry/skills `brand-guidelines/SKILL.md`** — supplies transformations, not adjectives: "In order to" → "To"; "This might cause…" → "This will cause…" (remove hedging); "Item has been successfully deleted" → "Deleted."

### Two conclusions that settle open questions

**No competitor bans metaphor** — deanpeters permits one clarifying metaphor; Matt Pocock's skill uses metaphors to teach. **So a strict metaphor ban is not warranted.** The developer's own diagnosis was correct: the confusion came from *unclear* writing, and an instruction demanding concise, literal, specific language fixes that without a literal ban. Recommendation: **drop the ban.** Prefer the plain word; allow standard industry terms (`north star`, `source of truth`).

**The whole ecosystem converts "be clear" into testable rules.** None of them say "write clearly" and stop. Every strong example is a transformation, an exact bound, or a defined term. That is exactly jim's own best pattern — and exactly what jim's *judgment* skills lack.

---

## Task 3 — Is jim's clarity instructed, or accidental?

The developer asked directly. Answer: **partly instructed, partly a byproduct of the domain — with one instruction actively working against conciseness.**

I read `meta-skill/SKILL.md` and `meta-agent/SKILL.md`, the two skills that author every other jim skill and agent. Their "Writing style" sections and validation checklists say:

| jim already instructs | Effect |
|---|---|
| "Imperative form: Read the file, Check for X" (+ checklist item "Instructions use imperative form") | **This is why jim's commands are imperative.** Instructed, and it works. |
| "Keep lean: remove anything not pulling its weight"; budgets (≤500 lines / ≤800 tokens); "No duplicate logic (same instructions in 3+ places)" | Partial concision pressure — but the dedup rule only fires at 3+ *and* misses cross-file repetition, so 2×–3× restatements survive. |
| "No personality soup" | Blocks filler intros. Works. |

**What is NOT instructed anywhere** (these are the gaps that produced the audit findings):

- **Specificity** — nothing tells a skill to name exact values or ban vague words. The precision jim *does* have in build/security/file is a **byproduct**: bash contracts, TDD thresholds, and frontmatter rules force exact strings. Where the domain doesn't force it (interview, brainstorm, vision), the writing drifts vague. So "imperatives with numbers, exact strings, explicit branches" is **instructed only for the imperative part; the numbers/strings part is accidental.**
- **Define-on-first-use** — no rule. Hence STRIDE/SDLC/Peer Feedback/Connextra appear undefined.
- **Literal-by-default** — no rule. Minor, given the metaphor finding is small.

**The counter-productive instruction:** meta-skill says *"Explain why behind constraints — reasoning beats rigid directives"* and *"Avoid ALL-CAPS MUSTs; use rationale instead."* This is a **documented driver of the wordy/rationale-padding findings.** It is not wrong — rationale that changes behavior is valuable — but as written it invites decorative "why" on every rule. It needs a bound: keep the "why" only when omitting it causes a wrong action.

**Bottom line:** the enforcement point already exists (the meta-skill/meta-agent writing-style section). We do not need a new mechanism — we extend that section with specify/define/dedup rules and bound the "explain why" rule.

---

## Task 4 — The plan

### 4.0 The rule (specific and testable)

Replace the metaphor-centric draft with a rule built on the four qualities:

> **Jim writing style.**
> 1. **Specific over vague.** Every instruction names an exact value, file, threshold, or condition. Do not use unmeasurable words — "appropriate", "as needed", "reasonable", "non-trivial", "where relevant", "meaningful", "sufficient", "lightweight". If you cannot test whether the instruction was followed, rewrite it until you can. *Exception:* a deliberately broad heuristic may keep its broad wording when (a) a strict, testable check runs immediately downstream, and (b) no specific, testable rewrite preserves the intended breadth. Mark such cases as intentional. (Example: the candidate-batch accumulation net — see Task 1.)
> 2. **Say it once.** State each rule in exactly one place. Do not restate a constraint you already gave — in this file or another. Link to the canonical statement instead.
> 3. **Imperative and direct.** Use commands, not narration or hedging. No "consider", "you might want to", "try to", "best-effort".
> 4. **Define terms on first use.** Any acronym or named method (STRIDE, SDLC, Peer Feedback, Constitution Check) gets a one-clause definition the first time it appears, then reuse the bare term.
> 5. **Cut rationale that prevents no mistake.** Keep a "why" only when omitting it would cause a wrong action. (This bounds the current "reasoning beats rigid directives" rule.)
> 6. **Literal by default.** Prefer the plain word. A vivid label is allowed only when it is standard industry vocabulary (north star, source of truth) or genuinely shortens the explanation. No blanket ban.

### 4.1 Two layers, per skill

- **Layer 1 — the skill's own prose** (make the instruction file specific and concise).
- **Layer 2 — the language the skill injects into its artifacts** (so the spec/plan/doc it *produces* is specific and concise). Higher value: it improves every future artifact.

### 4.2 Where the rule lives, and how it reaches the artifacts

**Runtime fact that determines this:** a jim skill's `agent:` field is documentation only — it does not route — and subagents do not inherit CLAUDE.md or the parent context. So the one context guaranteed present when an artifact is written is the **skill's own `SKILL.md`**. The rule must live there (or be referenced there), not only in an agent body or CLAUDE.md.

Four parts:

1. **Canonical rule — state it once.** Add the full 6-point rule to `ARCHITECTURE.md` → Plugin Conventions → **Writing Style** (that section exists). Single human-facing source; everything else points here.

2. **Layer 1 — jim's own skill/agent files.** Extend the `meta-skill` / `meta-agent` "Writing style" checklist with specify-don't-vague, define-on-first-use, say-it-once (tighten the dedup rule to catch *any* restatement, including cross-file), and the bounded "explain why". These two skills gate all authoring, so jim's own files comply by construction. This governs how jim is *written*; it does not touch the artifacts.

3. **Layer 2 — the artifacts the skills emit.** In each artifact-producing skill, embed a **compact form** (2–3 lines, pointing to the canonical rule) in the step that writes the artifact, plus one Validation-Checklist item. This is the part that makes `spec.md` / `plan.md` / etc. follow the rule. Skills that need it:

   | Skill | Artifact | Rule form to inject |
   |---|---|---|
   | spec, spec-check | spec.md | full (execution doc) |
   | plan | plan.md | full |
   | research | research.md | full |
   | arch | ARCHITECTURE.md | full |
   | sec | security.md | full |
   | build | code + commit messages | specify + say-once (prose parts) |
   | debug | debug report | full |
   | issue | issue `.md` | full |
   | vision | VISION.md | narrative subset — specify + define + say-once + literal; relax rule 3 (imperative) |
   | roadmap | ROADMAP.md | same narrative subset as vision |
   | brainstorm | brainstorm `.md` | lightest — capture is freeform |

   Utility skills (conf, file) and the `meta-matrix*` fixtures emit no prose artifacts — skip. Optional belt-and-suspenders: also add the compact form to CLAUDE.md (covers main-session runs) and to the six artifact-writing agent bodies (pm, architect, researcher, coder, security, meta). Not required if every artifact skill carries it, but cheap insurance — and it matches how jim already handles its scripting conventions (compact in CLAUDE.md, canonical in ARCHITECTURE.md).

4. **Then one worst-first cleanup pass** using the CSV as the worklist.

**By document type:** execution documents (spec, plan, research, security, debug, ARCHITECTURE, issues) get all six points. Strategic narrative documents (VISION, ROADMAP) are prose, so rule 3 ("imperative") is relaxed there; specificity, define-terms, say-once, and literal still apply.

### 4.3 Highest-ROI cleanups (do these first — one edit clears many lines)

1. **Cross-file constraint restatement** — state each shared constraint (`No code writing`, `never overwrite blindly`, `The human decides`, `Does NOT fix code`) once in a shared location; delete the copies.
2. **Undefined terms** — add a one-clause gloss on first use for STRIDE, LINDDUN, SDLC, Peer Feedback, Constitution Check, Connextra, version anchors, Implementation Insight, fileable bar.
3. **The roadmap threshold contradiction** — pick one number (5-7 or ~7) and use it in both places.

### 4.4 Per-skill worklist

Ordered by debt (from the CSV). "Own prose" = Layer 1. "Artifact language to add" = Layer 2.

| Skill / agent | Own-prose fixes (Layer 1) | Artifact language to add (Layer 2) |
|---|---|---|
| **spec/**, **spec-check/** | Define Connextra / the four probes on first use; cut "avoids feeling like an interrogation" | "ACs name exact values/conditions. No 'appropriate'/'as needed'. Define any domain term once." |
| **plan/** | Define "Constitution Check", "Peer Feedback"; specify "non-obvious choice" and "non-trivial flows" with a test | "Plan steps name exact values; every Verify is a shell command, not a description." |
| **build/** | Cut the WS-4 forensic aside | (Artifacts are code + commits — enforce literal commit messages) |
| **research/** | Specify "sufficient local context"; drop "best-effort" hedge | "Findings state facts with file:line — exact, not 'where relevant'." |
| **vision/** | Specify "reasonable defaults" and "where appropriate"; cut "not exhaustive documentation" padding; de-hedge "you might want to" | Keep VISION prose readable; still name exact audiences (the good drill-down example already models this) |
| **roadmap/** | Fix the 5-7 vs ~7 contradiction; define "version anchors"; de-hedge "consider"; specify "meaningful themes" | "Bucket items are short noun phrases with exact version tags." |
| **arch/** | Cut the two extra restatements of "read actual code"; specify "where relevant" anchors | "ARCHITECTURE.md cites exact file:line; no 'where relevant'." |
| **debug/** | Cut two of three "Does NOT fix code" restatements; specify "what is needed" test boundary | "Report states symptom, root cause, evidence — each with a file:line." |
| **sec/**, **security.md** | Define STRIDE/LINDDUN on first use; specify "alarmist"/"concrete suggestion" as a minimum-content rule | "Each finding names the exact flaw and an exact fix." |
| **issue/**, **issue-analyst.md** | Define "fileable bar" and "discovery artifact" at first use or rename; cut the 3× injection-as-data restatement | "Issue title + body name exact, testable work." |
| **architect.md** | Specify "surface tensions" (name what to flag); cut "never overwrite blindly" (link to shared) | — |
| **pm.md** | Define "Implementation Insight", "Level-Up Method"; specify "technology-agnostic"; cut 3× "The human decides" | — |
| **researcher.md** | Expand SDLC on first use; cut the verbatim-restated grounding sentence; replace "early warning system" | — |
| **meta.md** | Specify "inadequate" (cite the research DoD); cut the duplicate "No Bash" | — |
| **meta-skill/**, **meta-agent/** | Bound "explain why"; tighten dedup rule; **add the specify + define + say-once rules to the writing-style checklist** — highest ROI | — |
| **meta-test/** | Specify "primary feedback loop" / "repeatedly"; cut "completes the meta-* family" | — |
| **conf/**, **file/** | Trim background asides; the exact-contract prose here is already the model | — |

Low priority: the `meta-matrix*` skills are internal test fixtures. Skip.

### 4.5 Additions the project audit (Task 1a) forces

The generic writing rule (§4.0) plus Layer-2 injection already fixes most of what Task 1a found — vague qualifiers in ACs, wordy problem statements, redundancy. But two artifact defects are **not** caught by "be specific / say it once," because the AC *looks* specific while quietly being untestable. These need dedicated probes in `spec-check` (which already runs Socratic probes on ACs — the natural home):

1. **External-design-deferral probe.** Reject any AC whose acceptance is "matches / reproduces / recreates the design (doc, mockup)". Require the spec to extract the testable specifics — exact copy strings, pixel values, thresholds, states — into the AC itself. The design doc is a source, not the acceptance test.
2. **Open-Question-value probe.** Reject any AC that defers its own measurable value ("per Open Questions", "along the lines of", "final wording TBD"). If the value is undecided it is an Open Question, not an Acceptance Criterion. An AC must carry its value.

Plus two lighter additions:

3. **spec: cap the narrative.** Problem statement and each user story ≤ 2 sentences; state the gap, not the pain. This is where Task 1a found most of the bloat.
4. **brainstorm: trim on close.** On session end, drop retracted/superseded sections, do not paste a `/jim` prompt block that duplicates the body, and collapse a conclusion restated across rounds to its final form. (Light touch — ideation stays freeform mid-session.)

So: **the plan addresses the project-audit shortcomings, with these four additions.** Items 1–2 are new `spec-check` probes; items 3–4 are Layer-2 lines for `spec` and `brainstorm`.

---

## Task 5 — Summary and expected net outcomes

### What we found

- **No single dominant defect.** The issues are broad, shallow, and patterned across 30 files — many small instances, not one large one. They cluster into three kinds:
  - **Vague terminal instructions** (most common) — words with no downstream check to resolve them: `"non-obvious choice"`, `"reasonable defaults"`, `"where relevant"`. Distinct from intentionally broad heuristics that feed a strict filter (the accepted exception, Task 1).
  - **Cross-file redundancy** — the same constraint re-typed across files (`"No code writing"`, `"The human decides"`, `"Does NOT fix code"`); jim's 3+-places dedup rule misses it.
  - **Undefined terms** — named methods and acronyms used before a one-clause gloss (STRIDE, SDLC, Peer Feedback, Constitution Check, Connextra). This is closest to the confusion the developer originally reported.
  - Metaphor is the smallest category.
- jim's clarity is **half instructed, half accidental.** Imperative form is instructed (and works). Specificity is a byproduct of contract-heavy domains and is absent wherever the domain doesn't force it. One existing rule ("reasoning beats rigid directives") actively drives the verbosity we found.
- **The real artifacts confirm this (Task 1a).** Across 73 spec/brainstorm artifacts from Adrian's korswerk projects, the acceptance criteria are already strong — exact values, enumerated sets, given/when/then. The debt is the same contract-vs-judgment split: it lives in problem statements, user stories, UI-fidelity ACs, and brainstorm prose. Two artifact-specific defects (ACs that "match the design" or defer their value to Open Questions) need new spec-check probes (§4.5).
- **No metaphor ban is needed.** No competitor has one, and an instruction to be specific/literal/concise fixes the confusion the developer actually hit.

### The plan in one line

Add a six-point writing rule to ARCHITECTURE.md; extend the meta-skill/meta-agent writing-style checklist (specify, define, say-once, bounded-why) so it self-propagates; then one worst-first cleanup pass, starting with the cross-file restatements and undefined terms.

### Expected net outcomes

Stated as metrics where a count exists, and marked honestly where none does. Baselines are from a read-only grep of `skills/*/SKILL.md` + `agents/*.md` (excluding the `meta-matrix*` fixtures) on 2026-07-20. This generalizes the precision jim already shows in build/security/file to the judgment skills that lack it — not an imported outside style.

**Measurable**

| Outcome | Metric | Baseline | Target | How to measure |
|---|---|---|---|---|
| Less vague prose | occurrences of the Rule-1 banned words ("appropriate", "as needed", "reasonable", "non-trivial", "where relevant", "meaningful", "sufficient", "lightweight") | ~15 | 0, or each marked intentional (accepted-exception pattern) | `grep -rioE` the word list over skills+agents |
| Terms defined | flagged terms glossed on first use (STRIDE, LINDDUN, SDLC, Peer Feedback, Constitution Check, Connextra, version anchors, Implementation Insight, fileable bar) | 0 / 9 | 9 / 9 | inspect the first occurrence of each term |
| Less duplication | files restating each shared constraint ("No code writing", "never overwrite blindly", "The human decides", "Does NOT fix code") | up to 4 files each | 1 canonical location + links | `grep -rl` per phrase |
| No contradictions | internal threshold contradictions | 1 (roadmap 5-7 vs ~7) | 0 | inspect the roadmap self-check |
| Shorter files (lower token cost) | total lines, skills+agents (non-fixture) | 3,385 | net reduction | `wc -l` / `git diff --stat` before vs after |
| Self-sustaining | banned-word + define-on-first-use check in the meta-skill/meta-agent checklist | absent | present; new skills pass | checklist item exists |

**Believed, but not directly measurable** — stated as hypotheses, not promised numbers:

- **Fewer misreads of execution documents.** No telemetry exists on reader or agent confusion. The vague-word, undefined-term, and contradiction counts above are the leading indicators we can actually track.
- **Faster onboarding.** No measurement available.
- **Low risk.** Prose-only. Verifiable as "no diffs under `scripts/` or in frontmatter `allowed-tools`/`tools`."

**Artifact-level outcome (from Task 1a) — scoped honestly.** The real-project audit shows jim's artifacts are *already strong where it counts* (the ACs). So the expected win is narrower and more credible than "fix broken specs": trim narrative bloat and close a small number of untestable-AC leaks. It is measurable by re-running the Task 1a audit after the skill changes and counting the drop in: (a) vague-qualifier ACs, (b) "match-the-design" ACs, and (c) Open-Question-deferred ACs — all countable in `20260720-claude-speak-project-audit.csv` today as the baseline. Target: (b) and (c) → 0 (the two new spec-check probes reject them); (a) → sharply reduced.

This section now follows the doc's own Rule 1: where a count exists, state it; where it doesn't, say so.

### Open decisions for the developer

1. **The "explain why" rule.** Bound it (keep rationale only when it prevents a wrong action) — agreed? This reverses part of the current meta-skill guidance, so it is a deliberate call.
2. **Dedup scope.** Extend "no duplicate logic" from "3+ places" to "any restatement, including cross-file" — or keep it lighter?
3. **Rollout.** Enforce-via-checklist-then-cleanup (recommended), or one cleanup PR first?
4. **Where the rule lives.** ARCHITECTURE.md Plugin Conventions (recommended) vs. CLAUDE.md.

---

*Footnote on metaphor (the original example): the first audit pass catalogued figurative phrases — "upstream", "load-bearing", "archaeology", "masquerading". They are real but minor, and `north star` / `source of truth` / `thin wrapper` are standard vocabulary and should stay. The fix for the few that obscure meaning is covered by rule 6 (literal by default). Metaphor is not the thrust of this initiative.*

---

## Appendix — Reusable prompt: audit any project's jim artifacts

Run this to reproduce Task 1a against any project (or set of projects) that uses jim. It scans the real `spec.md` and brainstorm artifacts, scores them on the literal/efficient/specific/concise lens, writes a CSV, and folds a summary back into this doc. Replace `<PROJECT_PATH>` with one or more repo roots.

### Step 1 — Enumerate the artifact surface

```bash
# Repeat for each <PROJECT_PATH>. Audit spec.md + brainstorms (not plan.md/research.md).
find <PROJECT_PATH>/docs/specs -name 'spec.md' | sort
find <PROJECT_PATH>/docs/brainstorms -name '*.md' | sort
# Counts:
echo "spec.md:     $(find <PROJECT_PATH>/docs/specs -name 'spec.md' | wc -l)"
echo "brainstorms: $(find <PROJECT_PATH>/docs/brainstorms -name '*.md' | wc -l)"
```

### Step 2 — Fan out parallel auditors

Split the files into batches of ~10–12 and launch one `general-purpose` Agent per batch **in a single message** (parallel). Keep spec batches and brainstorm batches separate — brainstorms are judged more leniently (ideation is exploratory). Give each agent this prompt, substituting its file list:

> Audit real spec/brainstorm artifacts produced by the "jim" SDLC tool, for prose that is NOT literal, efficient, specific, or concise (and note strong exemplars that ARE). This is NOT a metaphor hunt — focus on vague/wordy/redundant/hedging/undefined.
>
> Read these files fully: `<paths>`
>
> Dimensions to hunt:
> - **VAGUE**: unmeasurable/untestable words in an acceptance criterion or requirement — "appropriate", "clear error", "handle gracefully", "friendly", "robust", "high fidelity", "reasonable", "barebones", "safe fallback". The fix names an exact value, condition, or observable behavior.
> - **WORDY**: motivational problem-statement/story prose; rationale that prevents no mistake.
> - **REDUNDANT**: one point restated across overview / problem / stories / ACs / resolved-questions.
> - **HEDGING**: tentative where a spec should be definite — "along the lines of", "per Open Questions", "roughly", "best-effort", "ideally".
> - **UNDEFINED**: domain term/acronym used before a one-clause definition.
> - **Watch for two AC-specific defects:** (a) an AC whose acceptance is "matches/reproduces the design (doc/mockup)"; (b) an AC that defers its own value ("per Open Questions", "final wording TBD"). Flag both as VAGUE, rank 1.
> - **GOOD**: a testable AC — exact value, enumerated set, given/when/then, explicit boundary.
>
> Output ONLY rows, exact format, no header/prose:
> `RANK~~PATH~~DIMENSION~~FIX~~QUOTE~~NOTE`
> - RANK 1-5: 1=egregious (an AC you could not test); 2=notable; 3=minor; 4=GOOD; 5=GOOD exemplary.
> - DIMENSION: vague|wordy|redundant|hedging|undefined|good
> - FIX: specify|tighten|cut|define|imperative|keep
> - PATH: relative to the project parent dir
> - QUOTE: VERBATIM, max ~15 words, no `~~` or newlines
> - NOTE: ≤12 words
> Return 2–4 rows per file (worst first; include an exemplar row if the file has a notably good AC). After the rows, add one line starting with `PATTERNS:` naming the 2–3 most common weaknesses across your batch and whether the artifacts are overall strong or weak on literal/specific/concise.

### Step 3 — Compile the CSV

Collect all agent rows into `docs/brainstorms/<YYYYMMDD>-claude-speak-project-audit.csv` (or append to the existing one, tagging the project in the path). Header and schema:

```
clarity_rank,path,dimension,fix,quote,note
```

Normalize: convert each `~~`-delimited row to CSV (wrap every field in double quotes; double any internal `"`). Sort worst-first (rank 1 → 5). Correct any agent that mislabels a `good` row with a low rank (a good exemplar is rank 4–5).

### Step 4 — Synthesize

From the rows and the `PATTERNS:` lines, write three things:
1. **Headline** — are the ACs strong? (Count rank-4/5 rows.) State where the artifacts are strong vs weak.
2. **Weakness patterns** — the recurring dimensions, worst-first, each with one verbatim example. Call out any *new* defect species not already in this doc (e.g., the "match-the-design" and "Open-Question-deferred" AC defects that Task 1a first surfaced).
3. **Verdict** — does it confirm the contract-vs-judgment split (precise ACs, vague/verbose narrative), or show something new?

### Step 5 — Update this doc

- **Add a Task 1a-style section** (or a Task 1b for a new project) with the headline, weakness patterns, brainstorm note, and verdict. Name the project and the artifact count.
- **Cross-reference Task 1** — one line noting whether the artifacts confirm or contradict the internal thesis.
- **If a NEW defect species appears** (not covered by §4.0's rule), add a matching `spec-check` probe or Layer-2 line under §4.5, exactly as items 1–2 there were added.
- **Update Task 5** — add a corroboration bullet to "What we found", and, if the scope shifts, adjust the "Artifact-level outcome" note. Keep the baselines countable in the CSV.
- Re-run `grep` sanity: new section present, section order intact, CSV row count matches.
