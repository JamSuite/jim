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

---

## Closing: what the remediation taught

*Added after the remediation ran to completion and the plan was marked
complete. Everything above analyses the build. This analyses the second pass —
fixing what the build shipped — which turned out to have a failure mode of its
own, and one that generalises further than the build's did.*

**The run:** 50 commits from the remediation's first to the plan's close (32
`docs`, 9 `fix`, 6 `chore`, 2 `test`, 1 `refactor`). Thirteen issues closed, six
filed. `tests/issues.sh` 384 → 402 cases; the suite 1,608 → 1,629. Under
`skills/` and `tests/`, 10 files, +1,468 / −317. Five blueprint invariant edits,
every one additive, none of them touching a Provides entry. One closing
`/jim:verify --since` with 11 change-selected judges: 8 holds, 3 violated, 4
skipped by scope, 0 undelegated.

### The one finding: everything that failed here failed by looking like it worked

The build's root cause was *a set the rule quantifies over, re-derived at each
point of use — every re-derivation locally correct and globally incomplete*.
The remediation found that shape again, one level up, in almost everything it
touched. Not in code this time: in the **records, tests, runs and probes** used
to fix the code.

| what | presented as | actually |
| :--- | :--- | :--- |
| a filed issue | a complete account of a defect | one instance of a class |
| a filed reproduce | a runnable recipe | a hypothesis about a mechanism |
| a test green on first run | a behaviour pinned | possibly a test that cannot fail |
| `case_…_wikilink_in_inline_backticks_ignored` | an assertion | a fixture whose token the shell ate, and two assertions structurally unable to fail |
| a killed suite process | a finished run | 124 of 401 cases, no summary line |
| a `sed` mutation | applied | silently no-op'd on an escaping mistake |
| `grep -c` on a log | a count of zero | a refusal to read a file it judged binary |
| `--spec issue` | a narrowed query | three groups, at status 0 |
| `stats --cols` | a column selection | accepted and discarded |
| `new.sh --slug` on a collision | a filing | a filing and a silent deletion |

Ten items, one shape. **A false success is the failure mode that survives every
gate**, because every gate is looking for a reported failure. The build's
version of this was a code path that took the optimistic branch. The
remediation's version is an *artifact* — a record, a case, a log line — that
reads finished.

That reframes the build retrospective's central recommendation. "Declare the
set and iterate it" fixes the code-level instance. The general form is harder:
**arrange for the thing that failed to say so.** Mutation testing does that for
a test. Running a reproduce does it for a record. `grep -a` does it for a log.
An `awk` replacement that asserts its own match count does it for an edit. None
of these is diligence; each is a mechanism that converts a silent wrong answer
into a loud one.

### Filed records are instance-shaped, and the remediation is where the class appears

Eight records were found materially short of their own defect — seven of the
thirteen closed, plus `#402`, which was extended rather than closed:

- `#393` counted eight citations in one file. There were 34 across six, and two
  of the eight were already gone.
- `#395` was grouped as a small correctness edge. It was three classification
  sites computing one rule from two values.
- `#392` named one trim. There were two, at opposite ends of one path,
  cancelling — and the input it named already worked.
- `#389` offered a fallback that does not exist: the warning it pointed at
  reports missing reciprocity and fires identically for a dependency that
  resolves.
- `#396` listed six test gaps. One was already closed by an earlier fix, and
  two of the remaining five were described wrongly.
- `#398` named three `awk -v` call sites where the group holds ten, and rested
  on a convention wider than the one the project actually keeps.
- `#394` analysed the ordinal half of its own defect and missed the group half,
  which was the reachable one — and the fix it proposed would not have closed
  it.
- `#402` named two vocabulary duplications; an independent judge found six.

This is not sloppiness, and treating it as sloppiness would produce exactly the
wrong remedy. **A record is written at the moment of discovery, from the
instance in front of the finder, and the filing gate is deliberately cheap so
that capture happens at all.** A sweep for the class is not cheap. So the
instance is what gets written down, and the class is discovered later — during
remediation, by someone holding the whole file open.

The consequence is structural and worth stating plainly: **`remediation.md` was
an analysis of records, so it inherited their scoping.** Its § *Where this
analysis was short* has five entries, and the pattern in them is uniform — the
*sequence* it recommended was sound every time, and the *size* was wrong
repeatedly. An order built from instance-shaped inputs orders the instances
correctly and mis-estimates all of them.

The cheap mitigation is not "file better issues." It is to treat the first act
of fixing an issue as a **sweep for siblings**, before any code changes — the
`#393` sweep found 26 more citations in one `grep`; the `#398` sweep found seven
more call sites in one. Both took a minute and both changed the shape of the
work.

### The reproduce is the least reliable part of a record

Two issues carried concrete, confident reproductions that did not reproduce.
Both named the right defect and the wrong input. The asymmetry has a cause: a
defect is *observed*, while a reproduce is *reconstructed* from a mental model
of the mechanism — and the mechanism is precisely what the finder had wrong.

So a reproduce inherits the model's error while wearing the authority of a
command line. That is worse than no reproduce at all, because it is actionable:
someone will run it, see it behave, and conclude the defect is understood.
`#392`'s `" alice"` was already reachable, by two spellings; the unreachable
class was trailing whitespace, which no spelling reached. Fixing what was filed
would have changed nothing and closed the issue.

**A filed reproduce is a hypothesis with a command attached, and both halves
need running.**

### Green on the first run is not evidence

Every one of the five cases written for `#396` passed immediately. So did the
wikilink case that had been passing for the wrong reason since it was written —
its fixture body was double-quoted, so the shell ate the token it was built to
test, and the case then asserted that a body containing no wikilink produced no
edge.

Correcting the quoting was not enough, and this is the part worth carrying:
even spelled correctly, **neither of its assertions could fail**. One looked for
an edge to a slug the token could never produce; the other needed a target that
fails the id validator, and the token passed it, because that validator guards
containment rather than slug shape. A test can be structurally incapable of
failing, and reading it will not tell you — it looks exactly like a test.

What distinguished the pinning tests from the decorative ones was **mutation**:
break the behaviour the case claims to pin and watch it fail. That is already
recommendation (4) above, scoped to vocabulary constants. The remediation
widens it: it applies to every characterization test, and it is the only cheap
technique that answers the question "does this test do anything?"

One mutation in this session silently failed to apply, and the case passed —
for the third distinct reason in one paragraph. The check needs its own check:
every subsequent replacement asserted its own match count and refused at zero.

### Second priors kept paying, and one of them was human

The build retrospective's strongest claim is *budget for second priors, not for
diligence*. The remediation is a long confirmation, with one addition it did not
anticipate.

- Independent judges confirmed by their own route what I had established by
  hand — the identity gates `#398` rests on, and the `awk -v` channel change.
- A judge reached the `row-shape-is-the-writers` reader gap independently, and
  phrased the consequence better than the note that had been sitting in the
  handoff for a day: a reader-side regression *"would not, on the letter of this
  invariant, constitute a violation."*
- A judge found the pinned-slug overwrite **while judging something else**, and
  classified it correctly as outside the invariant it was judging rather than
  stretching a verdict to cover it.
- A judge caught a factual error I had committed into `ARCHITECTURE.md` an hour
  earlier — a claim of parity between two call sites, written from my memory of
  a fix rather than from the call sites.

And the addition: **`#394`'s real defect surfaced because the developer asked
whether it was worth fixing.** Nothing in the pipeline was going to ask that. I
had reported the record's own framing back — a dependency to state rather than a
bug — because it was filed by a careful reader and read plausibly. The question
forced a probe, the probe found the group-segment collision, and the record was
re-scoped and re-priced. A second prior does not have to be an agent; it has to
be someone who did not write the thing.

The corollary is uncomfortable and belongs here: **the parts of this remediation
that no second prior touched are the parts I would trust least.**

### The measurement apparatus is a source of error

Twice the probe was wrong rather than the code. A scratch directory accumulated
a stray `.md` while I drafted an issue body in it, and the indexer read it as an
issue — inflating a count from 3 to 4. A `grep` looked for the wrong fixture
titles and reported that every query matched nothing, including one a passing
test asserts matches.

Both were caught before anything was written down, but neither was caught by
design — I noticed one number looked odd and one result looked impossible. When
a session is dominated by probing, the probe becomes a live source of error, and
it has no test suite. The habits that helped were mundane: a negative control on
every probe that claims something is refused, and rebuilding a fixture from
scratch rather than reusing one that had been edited.

### What the remediation got right

- **The order held.** Every pairing `remediation.md` insisted on — `#387` with
  `#388`, `#390` with `#397` — was correct, and each pair really was one
  enumeration short of one rule. Fixing half of either would have left the other
  looking deliberate.
- **No invariant was folded to match the code.** Five blueprint edits, every one
  additive. Where a violation was real and pre-existing, it was routed to an
  issue rather than legislated away — including a `critical` one found in the
  closing minutes, where folding would have been the cheaper exit.
- **Fix the shared cause, not the instance.** Applied consistently once the
  pattern was visible, and it kept finding more than the record named.
- **The handoff documents were load-bearing across two compactions.** They were
  also wrong about their own suite timings until measured, which is the same
  lesson in miniature: a document is an artifact, and artifacts read finished.

### What I would change

1. **Sweep before fixing.** The first act on any issue is a repository-wide
   search for siblings of the thing it names. It is one command and it changed
   the size of the work in every case where it was run.
2. **Mutate every characterization test.** A test written to pin existing
   behaviour is green by construction; the only evidence it pins anything is
   that it fails when the behaviour is broken.
3. **Assert the match count on every mechanical edit.** A `sed` or `awk`
   replacement that does not check how many times it matched is a change that
   can silently not happen.
4. **Pass an invariant's text verbatim, and mark supplementary questions as
   supplementary.** One violation in the closing run was against a property this
   session put in a judge's prompt rather than one the blueprint states. Folding
   it would have written an assumption into the group's intent. When a violation
   comes back against a supplied property, the finding is that the invariant is
   silent — and silence is what needs fixing.

### Open questions

- **Should the filing gate ask for a sweep?** Making capture more expensive is
  exactly what the actionability gate is designed not to do, and eight
  under-scoped records is the cost of that choice. Whether a one-line "siblings
  searched: y/n" field would pay for itself is untested, and it might simply
  move the guessing.
- **Can a reproduce be marked unverified?** Every record here presents its
  reproduce with the same confidence, whether it was run or reasoned. A record
  that distinguished the two would have saved two of the eight.
- **Is there a cheap detector for a structurally-inert assertion?** Mutation
  finds them, but only for behaviour someone thought to break. The wikilink
  case's assertions were inert for a reason no mutation of that file would have
  surfaced — the fixture never contained the input.
- **How much of the closing verify's yield came from independence versus from
  the invariants being written down at all?** Three of the eleven judged
  invariants returned violations, two of them pre-existing and neither
  previously known. The invariants were authored months apart, for other
  concerns, by the same author as the code they caught.
