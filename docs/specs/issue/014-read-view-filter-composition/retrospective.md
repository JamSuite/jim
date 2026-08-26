# Retrospective — read-view filter composition

One increment, start to finish: spec → research → sec → plan → sec → build →
review → verify → blueprint. It shipped, and its own review returned
`minor-drift` with two blueprint violations. This asks why, at the level of the
process rather than the code — the defects themselves are analysed in
`remediation.md`.

Two things to say up front about this document's own reliability.

**It corrected two committed artifacts.** `review.md` and `remediation.md` both
asserted that the plan narrowed the criterion the build then implemented
narrowly. Task 13's text is general, and the plan's Interface Contract lists all
eleven axes. The narrowing entered at implementation. Both artifacts now say so.
The same check found two more inversions, in a section of `remediation.md`
specifically about *how* defects were found.

**All three errors have one shape**: written from memory of the work rather than
from its record, immediately after doing it, and fluent enough to survive. That
is the same failure mode this retrospective is about, occurring inside the
retrospective. It is the strongest single piece of evidence in this document,
and it was free — it cost one `sed -n` against `plan.md`.

## The run

| stage | wall | runs | interruptions |
| :--- | ---: | ---: | ---: |
| spec (incl. amendments through approval) | 85 min | 1 | 0 |
| research | 15 min | 1 | 0 |
| sec (two passes: spec lens, dual lens) | 63 min | 2 | 0 |
| plan | 49 min | 1 | 0 |
| build (21 tasks, TDD) | 230 min | 1 | 0 |
| review (14 investigators) | 12 min | 1 | 1 |
| verify · blueprint · reconcile | ~25 min | 1 each | 0 |

25 commits in the build range, 32 to HEAD. 11 files, +2,682 / −555. 1,608 tests
green across 16 files. 24 subagents (14 investigators, 9 judges, 1 explore) at
roughly 2.4M subagent tokens.

**Outcome:** 35 ACs — 30 fully satisfied, 5 partial. 13 findings. 13 issues
filed. 2 invariant violations, both `in-change`, both resolved *fix the code*.
1 contract edge affected, holds. 0 security regressions. Plan held at
`approved`.

## What the pipeline got right

Worth naming, so remediation does not "fix" a working part.

- **The spec was correct and stayed correct.** All five partial ACs are partial
  because the *code* falls short of them, not because they were vague. The
  Socratic audit's job — keep ACs general, user-observable, and testable — is
  exactly what made the drift detectable later. A narrower AC would have been
  satisfied by the narrow implementation.
- **Research changed the design.** Finding `parse_relations` type-agnostic
  removed a whole row column from the substrate work and stopped the epic
  increment reading from a different place than the graph it renders.
- **The second security pass earned itself.** Finding 9 (`dir_given` reading
  argv by its own grammar) was a **live** defect that predated this spec:
  `stats --spec issue/011` was already broken. A dual-lens pass with the plan in
  hand found what the spec-lens pass structurally could not.
- **Measuring beat estimating.** The index-widening cost was measured across the
  real collection (+11.8% predicted) and came in at +12.0%.
- **A latent defect was folded rather than deferred.** The graph-slug narrowing
  would have become copies three and four. Fixing it inside the increment that
  would have propagated it is the right call and should be repeated.
- **The blueprint caught what nothing else did.** `#386` was found only by a
  judge run against a written invariant. Neither security pass, neither review
  investigator covering that region, nor the test suite found it. The invariant
  was authored for a different increment's concern and caught this one.
- **Verdict-before-sensor ordering held.** The review skill mandates recording
  the alignment verdict before the living-intent sensor runs. `findings=13` was
  locked before the two violations were known — so the sensor could not
  contaminate the verdict, and the verdict could not soften the sensor.
- **Read-only capability plus a disclosure norm.** Two investigators reported
  that they could not run `git show` and named which conclusions therefore
  rested on inference. Both were then closed directly against the commits. A
  restricted agent that *discloses the restriction* produces more trustworthy
  partial results than an unrestricted one that does not.

## Defect escape analysis

Where each defect became possible, where it first became *detectable*, and where
it was actually caught. The gap is the escape.

| defect | introduced | first detectable | detected | escape |
| :--- | :--- | :--- | :--- | :--- |
| `#387` guard covers 3 of 4 axes, 1 of 2 verbs | build, task 13 | build — the plan's contract listed all 11 axes | review (2 investigators + judge) | 1 stage |
| `#388` same gap, columns | build, task 13/16 | build | build's own candidate batch | 0 |
| `#390` present-but-empty operand | build, task 6 | plan — the Refusals list did not cover it | review (investigator) | 1–2 stages |
| `#397` unrecognized flag as value | **plan**, DD 4 | plan — the AC said "another flag" | review (AC investigator) | 1 stage |
| `#386` placeholder rewritten | build — wider argv into a shared wrapper | plan — blast radius of the grammar | verify sensor (judge) | 1–2 stages |
| `#395` census/Summary divergence | build, task 18 | build | review (investigator) | 1 stage |
| sec Finding 1's wrong mechanism | sec pass 1 | sec pass 1 — the code was readable | plan, by reading `ensure_index` | 1 stage |
| research's ARCHITECTURE.md claim | research | research — the doc was readable | build completion gate | **3 stages** |

Two patterns in the escapes themselves:

**Claims about artifacts, made without opening them, travel furthest.** The
longest escape is not a code defect at all — it is research asserting that
`ARCHITECTURE.md` "describes a six-field row" that needed correcting. No such
passage exists. It survived research, sec, plan, and the whole build, entering
the plan's Out of Scope as work "handled by a later gate," and died only when
the arch refresh went looking for the passage. Cost: near zero. But the same
mechanism produced security Finding 1, which asserted a specific control-flow
path through `ensure_index` that does not exist, and *that* one shaped a task.

**Nothing escaped more than about one stage once it was in code.** The gates
work. They are late, not absent.

## Root cause: one set, three enumerations

The centrepiece. `render.sh` declares seven vocabularies as `readonly`
constants:

```
STATUS_TOKENS  PRIORITY_TOKENS  TYPE_TOKENS  HELD_TOKENS
BLOCKED_TOKENS  COL_TOKENS  RENDER_OPTIONS
```

The **axis** vocabulary is the one it does not declare. Axis names exist in
three places instead:

| where | form |
| :--- | :--- |
| `render.sh:263` | a `case` pattern; names derived via `${a#--}` |
| `render.sh:287-291` | an `elif` chain of string literals |
| `render.sh:1051` | `for ax in type filed-by claimed-by` — the guard's own list |

Three independent enumerations of one set. The third is a strict subset of the
other two, and the gap is exactly `held`.

**Every enumeration was locally correct.** The guard's three axes really are the
row-scalar axes *as named by their flags*. What the author (me) missed is that
`held` reads `claimed-by` through a differently-named key — a fact visible only
by holding all three enumerations in view at once, which nothing required.

This generalises past the one bug:

- `#388` is the same guard, one surface out: columns were never enumerated at
  all, because there was no set to consult.
- `#397` is the instructive variant. `RENDER_OPTIONS` **is** declared — it is
  simply the wrong set. The rule quantifies over *any* flag; the constant
  enumerates *this file's* flags. Declaring a set does not help when the rule
  ranges over a different one.
- `#386` is the same shape in another script. `place_substitute` re-derives
  which argv positions hold placeholders by testing textual adjacency to
  `--dir`, rather than receiving the positions its caller actually built. That
  re-derivation was safe only while no caller could supply `--dir` — which this
  increment changed.
- `#394` is the latent form: the `--spec` prefix comparison is correct only
  because the allocator enforces ordinal uniqueness and fixed-width padding.
  The set of facts it depends on is real, lives in another group, and is
  declared nowhere near the comparison.

**One sentence:** *a set the rule quantifies over was re-derived at each point of
use instead of declared once and iterated — and every re-derivation was locally
correct and globally incomplete.*

## Why the gates did not catch it

Taking each in turn, because the answers differ.

**`/jim:spec-check`** audits the spec against itself — tier classification and
four probes over the ACs. It has no downstream visibility by construction. It
could not have caught this and should not be changed to try.

**`/jim:research`** grounds anchors and patterns. It found the substrate
finding and the latent slug narrowing. Coverage of a criterion's domain is not
its job.

**`/jim:sec` (both passes)** reviews for security properties. The staleness gap
is a correctness and disclosure defect, not a security one; the second pass did
find the live routing defect, which was in its lane. Asking sec to audit
universal-quantifier coverage would be asking it to be a different gate.

**TDD.** This is the deep one.

Every task had a Red test that failed, then passed. The suite is at 1,608. And
the Red test for task 13 exercised `--filed-by` and `--type` — *the same two the
implementation enumerated*.

The test could not catch the missing axis, because the test and the code were
written by the same agent, in the same context, from the same understanding of
what the axis set was. This is the **test oracle problem**: the oracle that says
what the output should be is derived from the same model as the implementation.
Classical TDD gets some protection from writing the test first, which forces
interface thinking — but writing first does not supply a second *prior*, and
that is what was missing.

Human solo TDD has the same weakness. It is worse for an LLM in one specific
way: a human writing tests after code at least switches cognitive mode from
constructive to adversarial. An agent continuing in the same context does not —
the fixtures are drawn from the same distribution as the code, with high
correlation. The mitigation has to be **structural**, not exhortative.

**The smoke test.** After the build I exercised the feature against the real
collection: `--spec`, `--priority`, `--claimed-by me`, `--cols`, `blocked`,
`--type epic`, and the refusals. The real index was in exactly the stale state
that triggers `#387`, and the guard fired correctly on `--claimed-by me`.

I did not run `list claimed` or `list unclaimed`. I smoke-tested the axes I had
built the guard for. **The same shared prior, one level up.** Twenty-three
invocations — every bare word and every flag once — would have cost nothing and
surfaced it.

## What actually caught things, and what each technique is good for

Separating these matters, because the naive lesson ("run things, don't just
read") is the opposite of what the record shows.

**Independent adversarial reading found the defects.** `#387`, `#390`, `#395`
and `#386` were each found by an investigator or judge that (a) had no memory of
authoring the code, (b) received the criterion or invariant *separately* from
the code, and (c) was told to default to unproven until evidence showed
satisfaction. Two independent investigators reached `#387` without contact.

**Execution corrected mechanisms.** What running things caught was not missing
defects but *confident, specific, wrong explanations*:

- security Finding 1 asserted a bound directory reaching `index.sh`'s
  `mkdir -p`. It does not — `ensure_index` opens with an existence guard.
- the correction to that finding then over-corrected, calling the residue
  "merely a silent wrong answer." Also wrong: the retarget writes an `INDEX.md`
  into whatever directory it lands on. **A correction inherits the confidence
  problem of what it corrects.** That finding carries a two-step correction note
  for this reason.
- my own first account of `#387` called it an empty result; it is a populated,
  wrong one.

So the two techniques answer different questions. **Reading finds what is
missing. Running settles why, and it is the only thing that reliably catches a
fluent explanation of a mechanism that does not exist.** Neither substitutes for
the other, and the suite distinguished neither.

## What would have prevented it

Ranked by cost against what they would actually have caught here.

**1. Declare every vocabulary as a constant; forbid inline literal sets.**
*Cost: near zero. Would have prevented `#387`, `#388`, and exposed `#397`.*

The project already does this seven times in one file. The eighth — the axis
set — is the one that drifted. Add `AXIS_TOKENS`, derive the parser's dispatch
from it where the language allows, and have every guard iterate a set *computed*
from it rather than retyped.

The general rule: **if a rule quantifies over a set, that set is a declared
constant, and every site that quantifies iterates the constant.** A literal
vocabulary list inline is the smell.

**2. Tests that loop over the constant, not over a sample.**
*Cost: low. Turns (1) from a convention into an enforced contract.*

```
for ax in "${AXIS_TOKENS[@]}"; do
  # against a stale index, this axis refuses or answers correctly
done
```

A new axis added to the vocabulary then enters every guard's test automatically.
This is property-based testing in the only form bash affords, and it is the
direct structural answer to the oracle problem: the test's domain comes from the
code's own declaration rather than from the author's imagination.

**3. A vocabulary smoke matrix against real data.**
*Cost: trivial — 23 invocations. Would have caught `#387` before the review.*

Not "smoke-test the feature." *Enumerate* the declared surface and run each once
against the real collection, checking exit status and the shape of the answer.
Selection is where the shared prior re-enters; enumeration is what removes it.

**4. Mutation-check the enumerations.**
*Cost: medium — seven constants, seven suite runs.*

Delete one element from a vocabulary constant and run the suite. If it stays
green, the suite does not pin that constant. This measures precisely the thing
that failed here, and 013's remediation found the same class by hand ("six cases
that pass against a wrong implementation").

**5. Bind tasks to named domains rather than restating rules.**
*Cost: low. Would have made `#387` visible at implementation time.*

Task 13 said "an axis the index does not describe." The complete domain was two
pages above it in the same document. Had the task said "for each axis in the
Interface Contract's axis list that reads a row scalar," the implementer would
have had to go and look. **A universally-quantified task should reference the
named domain, not paraphrase the quantifier.**

**6. Verify mechanism claims by execution before recording them.**
*Cost: one command. Would have prevented both wrong versions of sec Finding 1.*

A finding that says "X happens because Y" should have run Y. And a *correction*
to such a finding is itself a claim of the same kind — it needs the same
treatment, which is how the first correction shipped wrong.

**7. Verify claims about documents by opening them.**
*Cost: one `grep`. Would have prevented the longest escape in the table.*

Research asserted the contents of `ARCHITECTURE.md` without a passage to cite.
Any claim of the form "document D says S" should carry a line reference.

**8. Keep the fan-out, the read-only boundary, and the ordering.**
*Cost: already paid. These worked.*

## Agentic-specific observations

Things that are different about running this pipeline with agents rather than
people, beyond the general software-engineering lessons above.

**The shared prior is the central risk, and it is structural.** Test, code, and
smoke-test all came from one context. Every mitigation that worked here
introduced a *second* prior: an investigator with no authoring memory, a judge
given only an invariant, a constant that the test iterates instead of the author.
Every mitigation that failed asked the same context to be more careful. Budget
for second priors, not for diligence.

**Fluency is not calibration.** Three wrong causal claims in this run were
specific, well-argued, and confidently stated: two versions of sec Finding 1,
and this retrospective's own first draft of who narrowed the criterion. None
read as uncertain. The tell was not the prose — it was that none cited a line
that had been opened.

**Corrections inherit the problem.** The first correction to Finding 1 was
wrong in the opposite direction. A correction feels like a resolution and gets
less scrutiny than the original claim. It deserves more.

**Capability restriction plus disclosure beats capability.** The investigators
could not run anything. Two said so and named what it cost. That produced a
better artifact than unrestricted agents would have, because I knew exactly
which two conclusions to close myself.

**Ordering constraints are cheap contamination control.** Verdict recorded
before the sensor runs; the sensor cannot re-channel a violation from untrusted
text; grounding taken only from the caller's handed-over block. None of these
cost anything at runtime and each removes a way for a later result to rewrite an
earlier judgment.

**Fan-out economics.** 24 agents, ~2.4M subagent tokens, against a build of
~230 minutes. Yield: 13 findings, 2 violations, 4 real defects that would
otherwise have shipped — including two that produce wrong answers. Worth it. The
concentration matters more than the count: `#386` came from exactly one of nine
judges, and no investigator found it.

One honest caveat: I bundled 35 ACs into 5 investigators rather than dispatching
one per AC, with a cap of 20 and only 14 used. That was a judgment about
diminishing returns, not a cap effect, and `review.md` says so. Whether
per-AC dispatch would have found more is untested.

**Compaction is a risk surface with a specific shape.** This session compacted
twice. The handoff doc survived it and was load-bearing — but it went stale on
*configuration* within hours, asserting gates were off after they had been
turned on. Findings and corrections are durable; configuration is volatile.
**A handoff should record what was learned and point at what is configured.**

**The living-intent mechanism paid for itself in one increment.** A property
written down once, with a criticality, checkable by an agent that has only the
property and the code — caught a defect that four other gates missed, in a file
this increment never edited. That is a strong argument for writing invariants
down even when they feel obvious at the time.

## What to measure next time

If these recommendations are adopted, these are the numbers that would show it.

| metric | today | how to read it |
| :--- | :--- | :--- |
| vocabularies declared as constants | 7 of 8 | the missing one is where drift lands |
| guards iterating a constant vs. a literal | 0 of 3 axis sites | the direct measure of (1) |
| mutation survival across vocabulary constants | unmeasured | green after deleting an element = unpinned |
| escape distance per defect | ~1 stage in code, 3 for a doc claim | doc claims are the outlier to attack |
| findings per investigator | 13 / 14 | falling yield means the fan-out is saturated |
| ACs with universal quantifiers bound to a named domain | 0 | the plan-side measure of (5) |
| smoke coverage of the declared surface | ~8 of 23 invocations | selection vs. enumeration |

## Open questions

Things this run does not settle.

- **Would per-AC investigator dispatch have found more?** Untested. The bundling
  was a judgment, and the cap was not the binding constraint.
- **Is the second security pass worth its cost on every increment,** or only
  where a plan introduces a new argument surface? It earned itself here by
  finding a live defect; one data point.
- **How much of the review's yield came from the fan-out versus from the
  ground-truth framing?** The instruction to default every AC to unproven may be
  doing as much work as the independence. They were not varied separately.
- **Does the enumeration discipline generalise past vocabularies** to other
  implicit sets — the placeholder positions in `#386`, the allocator invariants
  in `#394`? Both fit the shape, but the fix for each is a different mechanism.
- **What is the right cadence for a full regenerate** versus targeted blueprint
  updates? This run recorded 0 updates since the last full generate against a
  threshold of 5; the cadence has not yet been exercised.
