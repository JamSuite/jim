# Blueprint "Why" — Interview & Merit Report

*2026-07-29 · A structured why-finding interview on jim's blueprint system, and a merit judgment. The interview subject is the blueprint developer; the interviewer/analyst is an LLM agent (Claude), which also served as a consumer-witness for one question.*

---

## 1. Intent of the exercise

The blueprint system grew organically out of `/jim:review`, and its "why" had only ever been narrated as history — not established on its own terms. The goal of this exercise was to **identify the durable "why" of blueprints** — why they are useful or needed, and what gap in functionality they fill — through a structured interview rather than a retrospective story.

Two integrity constraints governed it:

- **Historical reasoning excluded.** Brainstorms, spec rationale, and decision records for the blueprint feature were deliberately kept *out* of the interview design, so blueprints had to stand on their own technical merit and demonstrated value. Only the feature's *current-state mechanics* (SKILL.md) and its *operational outputs* (commits, filed issues) were used as evidence.
- **Judgment reserved.** No merit verdict was offered until the interview completed and the problem/solution statements were settled by the developer.

The interview leaned on the 5-Whys technique, jim's own problem/solution frameworks (the `vision` skill's Problem/Solution structure and a feature-scoped problem-statement view), and recognized qualitative-interview best practice.

---

## 2. Methods considered and used

### Research — the methods drawn on

| Method | Contribution to finding the "why" | Trap it prevents |
|---|---|---|
| **The Mom Test** (Fitzpatrick) | Ask about past behavior/facts, not opinions; stories over hypotheticals; never pitch. | The subject flattering the feature — acute risk since the subject is the builder. |
| **Critical Incident Technique** (Flanagan, 1954) | Force recall of *specific past episodes* that helped or hindered, before generalizing. | Abstractions with no evidence under them. |
| **JTBD Switch / Four Forces** (Moesta) | Reconstruct the timeline of a real decision; Push+Pull vs. Anxiety+Habit; target demand not preference. | Confusing "features I like" with "the job I hired it for." |
| **5 Whys** (Toyoda/Toyota) | Chain from surface action to root need, each rung grounded in evidence. | Stopping at a symptom; vague chains. |
| **Laddering / Means-End Chain** | Climb attribute → functional consequence → psychosocial consequence → value. | Naming a mechanism and calling it a value. |
| **Problem-statement framing** (Miro) | Gap / Orientation / Impact / Importance; stay solution-agnostic; must be paraphrase-able back. | A problem statement that smuggles the solution inside it. |
| **jim `vision-template`** | Output shape: Problem (Ideal/Friction/Consequence) + Solution (Mechanism/Function/Result). | — (target artifact structure) |
| **Feature-view frame** | Output shape: User / Desired Outcome / Current Behavior / Friction / Impact / Job-to-be-Done. | — (target artifact structure) |

The through-line across all of them: **history over opinion, specific incidents over summaries, and a deliberate disconfirmation pass.**

### Design — the neutrality contract actually applied

1. **Spontaneous-first naming** — the developer named the parts; mechanics (contract graph, invariants, reconcile) were only introduced once forcing tradeoffs.
2. **Anchor before laddering** — no "why" was asked until a concrete episode sat under it.
3. **Equal airtime to disconfirmation** — every "when did it help" was paired with "when did it not, and when were you fine without it."
4. **Behavior, not hypotheticals.**
5. **Two candidate jobs held apart** — *defining durable intent* vs. *verifying against it* — with evidence, not the interviewer, ranking them.
6. **One anchored question at a time**, recursive drill-down.

### Evidence-gathering actually used

- **Git history** of blueprint-touching commits — established that the blueprint step runs as routine end-of-pipeline machinery (a daily `update 000-blueprint` / `update project map` / `record verification run` triplet), low-impression by design.
- **Issue-origin forensics** — 132 issues mapped by `origin:`; ~15 are genuine blueprint-system *outputs* (origin = a `000-blueprint` spec or `BLUEPRINT.md`), distinct from the many dev-issues about *building* the feature.
- **Issue #52** read in full as the anchor incident: `/jim:verify jim` found invariant `inv-3` violated (judge verdict `partial`) across `issue`, `partition`, and `meta-matrix` — none in front of the developer — surfacing a real least-privilege over-grant (Gap 2) alongside a cosmetic convention divergence (Gap 1), both filed at `critical`.
- **#102** as the "obvious" case: a partition decision (ledger → platform group) materialized as tracked code-change work.
- **LLM consumer-witness testimony** — for the developer's "oracle" hunch, the interviewer answered as the actual consumer of blueprint-derived context, grounded in the expensive, non-reproducible multi-source ingestion it performed during this very session.

**Sources:** The Mom Test (mtlynch.io; blog.uxtweak.com); Critical Incident Technique (nngroup.com); JTBD Four Forces (jobstobedone.org); 5 Whys (easyrca.com; imd.org); Laddering (uxmatters.com; dscout.com); Miro problem statement (miro.com/product-development/how-to-write-problem-statement).

---

## 3. Final problem & solution statements

*Settled by the developer. `[delivered]` = grounded in a real incident on the blueprint branch; `[projected]` = a credible bet not yet witnessed.*

### Feature Problem Statement (feature-view frame)

> A jim-managed project accumulates its own declared architectural intent and constraints, but a developer's — and the LLM's — attention is local to the current task. Nothing reaches code outside that task to keep it aligned, mechanical tools can't check project-declared semantic rules, and reconstructing the current architecture means high-volume, high-variance, staleness-prone ingestion.

- **The User:** A developer (and the LLM agent) evolving a non-trivial, multi-group project with jim who wants to **guide and maintain their application's architecture** as it grows — keeping the code aligned to its own declared intent and constraints.
- **The Desired Outcome:** Keep the codebase continuously true to its own declared intent and constraints as it grows, and reason about it — and its cross-cutting impact — from a current, trustworthy view.
- **The Current Behavior:** Ingest ARCHITECTURE.md + dozens of specs and artifacts + git history + refs (the blueprint feature alone is 27 specs), filter, build a timeline, reason — tens of thousands of lines, reasoned differently every pass. Newly-decided rules never propagate back across pre-existing code.
- **The Friction:** Local attention leaves drift silent; mechanical tooling can't reason about semantic project-declared invariants (a grant broader than a skill's actual usage isn't a syntax error); prose docs rot silently, so they must be re-verified, burning back the tokens.
- **The Impact:** Declared standards silently rot across code no one is looking at; the agent's architectural reasoning is inconsistent and expensive; in high-stakes projects, that silent drift is exactly where real defects hide.
- **The Job to Be Done:** *"Keep my growing project true to its declared architecture as it evolves, and give me and my agent a current, trustworthy, low-variance view to build and verify against."*

### Solution Statement (jim vision-template frame)

> A per-group current-state spec plus a project map and cross-group contract graph — written in a durable, present-tense register and continuously checked against the code — that flags drift from declared intent anywhere in the codebase and offers a stable, verified view of the architecture to reason from.

- **The Mechanism:** Amalgamate each group's responsibilities, provides/requires faces, and named load-bearing invariants from specs/architecture/code; bind spec-groups to the application's domain territory; verify continuously via a mechanical floor **+ registered host-toolchain commands + an adversarial agent/judge layer** that tries to *disprove* each invariant.
- **The Function:** Retroactively flag code outside the current task that violates a declared invariant `[delivered — #52]`; surface a plan's blast radius before any code is written `[delivered]`; turn partition decisions into tracked code-alignment work `[delivered — #102]`; and stand as a stable, pre-verified entry point the LLM builds context from `[projected — SDLC ingestion not yet wired]`.
- **The Result:** A newly-declared standard sweeps the whole codebase; drift surfaces as tracked issues; decisions are grounded in a current contract graph instead of re-derived from volume — **a continuous alignment layer over your existing tooling.**

**Positioning note:** blueprints are an *architectural* alignment tool, not a security tool. Security invariants (e.g. #52's least-privilege grant) are one class of invariant among many; the system *integrates* the host toolchain and *complements* a security team rather than substituting for either.

---

## 4. Verdict

*The analyst's (LLM's) merit judgment, delivered after the interview closed.*

**Overall:** The "why" is real and self-justifying for what blueprints deliver today; the larger ambition is a well-founded bet; and the feature currently carries more machinery than its demonstrated value requires. All three hold at once.

### Holds up on its own merit — no bet required

1. **Semantic invariant enforcement across code outside your attention.** Uncontested and demonstrated: #52 is a clean proof — verify reached code the developer wasn't touching and surfaced a real over-grant nothing else in the workflow would. LLM judgment over project-declared intent is structurally beyond pre-LLM tooling.
2. **The contract graph / blast-radius-at-plan.** Highest consumer value and wired today. Cross-cutting impact is where local reasoning — human and LLM — is weakest and most error-prone; a precomputed, verified requires/provides graph is real leverage.

Together these justify the feature's existence at a **modest but real** value level. The value is aggregate *insurance* (the catches are "no-wow"), scaling with how many real invariants are declared and how much the code churns.

### Still a bet — projected, not demonstrated

1. **The oracle** (blueprint as agent-context entry point) — unwired. The consumer-side value was validated in-session, but "I'd expect value if you build it" is a promissory note. It is the biggest claimed upside and the piece not yet in the pipeline.
2. **Value scaling with stakes** — witnessed only at jim's low stakes; the high-stakes payoff is inferred. (The "a mature toolchain crowds it out" challenge was answered soundly: the semantic-judgment residue survives.)

### Honest weak spots

1. **Signal quality is capped by invariant authoring + criticality calibration.** #52 filed a divergence it *itself* rates "no permission-scope hole" at `critical`, beside a genuinely real one. Mis-graded criticality manufactures noise, and noise is corrosive precisely because the whole value proposition is "you can lean on it."
2. **Machinery-to-value ratio — the sharpest concern.** 27 specs of heavy machinery (reconcile choreography, migrate arms, downgrade grading, present-tense/provenance self-scans, health hooks, face counters) delivering, today, mostly low-drama catches plus blast radius. If the oracle doesn't land and higher-stakes use doesn't materialize, the complexity is under-justified by the dogfooding evidence alone.
3. **The differentiator inherits LLM variance.** The judge layer — the headline capability — is the least deterministic and most expensive part; a `partial` verdict can wobble run-to-run. The mechanical floor + registered toolchain exist to anchor it, but the distinctive value carries the distinctive nondeterminism.
4. **Two architecture artifacts.** Blueprints and ARCHITECTURE.md must not drift into two sources of truth; the differentiators justify the split only while the boundary stays crisp.

### Bottom line

Jim genuinely *needs* the enforcement and contract-graph legs — they are how "LLM-assisted agentic development" earns architectural correctness that neither generic tooling nor a context-narrowing agent provides. The distinctive long-term value lives in the **unbuilt oracle**, which is exactly why it is the thing worth wiring next: it is the highest consumer-value piece, and building it converts the biggest bet into delivered value. The cheapest thing protecting everything else is invariant/criticality discipline — the surface is only ever as trustworthy as its worst critical flag.

> **In one sentence:** the enforcement engine and contract graph earn their place now, the architecture-oracle is a bet worth making and the next thing worth wiring, and the real risk isn't that the idea is wrong — it's that the machinery outruns the realized value while the best part stays unbuilt.
