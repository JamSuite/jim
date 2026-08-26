# Remediation — read-view filter composition

Written after the post-build review returned `minor-drift` and the living-intent
sensor returned two violations. This records where the increment actually
stands, what the open issues have in common, and the order I would fix them in.
It is analysis, not a plan: nothing here has been approved, and the sequencing is
a recommendation.

## Where we stand

*This section and the order below record the state at writing, before any of it
ran. What actually happened — including where this analysis was short — is in
§ What running it settled, at the end.*

The feature works. A developer composes several filters in one query, names
themselves rather than an address, scopes a census to one spec's follow-up work,
and chooses columns for a single query. Against the real 380-issue collection,
`list --spec issue/011 --priority high,critical` returns seven records,
`--filed-by me` returns 126, and `stats --spec issue/011` reports its scope
before its counts. The suite is green at 1,608 tests across 16 files, all 21
plan tasks are `[x]`, and 30 of 35 acceptance criteria are fully satisfied.

Two of the remaining five produce a **wrong answer** rather than a missing one.
Independent investigators found both by reading; running them confirmed the
behaviour and corrected my own first account of one.

| artifact | state |
| :--- | :--- |
| `spec.md` | approved — 35 ACs |
| `research.md` | `Needs PM Review` — the VISION contention, non-blocking |
| `security.md` | `Needs Plan Review` — 12 findings, all routed and applied |
| `plan.md` | `approved` — 21/21 tasks, **held** pending this remediation |
| `review.md` | **`minor-drift`** — 13 findings, `undelegated=0` |
| living intent | 13 sensed · 7 holds · **2 violated** (both `in-change`) · 4 skipped by scope |
| contracts | 1 edge affected, holds |
| collection | index regenerated onto the widened row, +12.0% |

The plan is held at `approved` because it is not yet true that this build's own
review and sensor came back clean. Marking it complete now would record a
judgment the artifacts contradict.

## What the open issues have in common

Thirteen issues were filed across the build, the review, and the blueprint fork
— `#386`–`#398`. Two are high. Two are blueprint violations. They overlap by
one.

### The three that block

**`#386` — the placement wrapper rewrites a caller's own text.** *(high ·
blueprint violation · `placeholder-by-position`)*

`place_substitute` decides whether an argument that *is* `{}` is a real
placeholder by asking whether the preceding argv element is literally `--dir`.
It has no way to know which script's grammar produced that adjacent token — the
check is textual adjacency and the function's interface carries nothing else to
key on.

This increment made that adjacency reachable from caller text. Two of its own
properties combine: a filter flag's operand may be any string (the operand guard
refuses only this file's own option names, and `--dir` is not one of them), and a
single trailing unclassified word becomes the residue slot, so a bare `{}`
survives classification. Reproduced end to end in a placement-configured
repository:

```
$ render.sh list --label --dir '{}'
error: unrecognized filter token: /tmp/<run>/collection
```

That path is the run's real materialized collection directory. The caller's own
`{}` was rewritten with it.

On this read path the harm is a spurious refusal and a run-local path on stderr
— not the durable-identity corruption the invariant's own text warns about,
which needs a write verb whose grammar accepts both halves. But
`place_substitute` is shared verbatim by every entry script, so the class is
wider than the one route. What this increment did was produce its first
reachable instance.

**`#387` — the schema-staleness disclosure covers three axes on one verb.**
*(medium · blueprint violation · `staleness-gated-reads`)*

The increment introduced a second class of staleness — an index whose mtime is
current but whose *schema* predates the widened row — and the disclosure that
catches it. The disclosure enumerates `type` / `filed-by` / `claimed-by` and
lives only in `cmd_list`. The invariant it serves is stated over any axis the
index cannot answer, on either read verb.

```
$ render.sh list --claimed-by holder@example.test <dir>   rc=1  refuses    ✓
$ render.sh list unclaimed <dir>                          rc=0  lists it   ✗
$ render.sh list claimed <dir>                            rc=0  no matches ✗
$ render.sh stats --filed-by dev@example.test <dir>       rc=0  Open: 0    ✗
```

The `unclaimed` line is the worst of the four: not an empty result a reader
might question, but a populated one that positively misreports a held record as
unheld. The bare words `claimed` / `unclaimed` bind an axis named `held`, which
reads the very `claimed-by` field the guard protects — under a different key, so
the enumeration misses it. The census view shares the parser, the matcher and the
row reader with the list view, but not this.

**`#390` — a present-but-empty filter operand matches everything.** *(high · not
a blueprint violation, and the worst user-visible defect of the three)*

```
$ render.sh list --label auth <dir>    1 match    (correct)
$ render.sh list --label ,,, <dir>     2 matches, rc 0
$ render.sh list --label '   ' <dir>   2 matches, rc 0
```

An operand yielding no alternative leaves its axis key unassigned, and every
matcher reads an unassigned axis as one nobody named. The operator typed a
narrowing flag and received a widening one, silently, at status 0.

This is the failure the file's own `need_operand` commentary argues against, in
its own words: *"the flag that was consumed goes unapplied, and the value it
became is one nobody typed — and on a read surface both halves are silent,
because a narrower query and a query that matched little look the same."* The
guard catches the absent and flag-shaped cases and misses this one.

### The pattern underneath them

`#386` is its own shape. The other two, and four more below, share one:

**An enumeration stood in for a rule.**

| issue | the rule | the enumeration that shipped |
| :--- | :--- | :--- |
| `#387` | any axis the index cannot answer, on either verb | `for ax in type filed-by claimed-by`, in `cmd_list` |
| `#388` | the same, for a column | not enumerated at all |
| `#397` | "a value that is another flag" | membership in `RENDER_OPTIONS` |
| `#390` | an operand that does not yield a filter | absent, or flag-shaped |

Each enumeration is correct about what it lists. Each is a strict subset of the
rule above it, and in every case the gap is silent — the code takes the
optimistic branch and returns a plausible answer.

**These have three different origins, and only one is the plan's.** Task 13's
text is general — "a filter names an axis the index does not describe" — and the
plan's Interface Contract lists all eleven axes, `held` among them. For `#387`
and `#388` the plan supplied both the rule and the complete domain, and the
implementation enumerated a subset of it two pages later. `#397` *was* narrowed
at plan time, deliberately and with a stated rationale about addresses wearing a
leading hyphen. `#390` was named by neither.

So the fix is not "write better plans." What the four share is structural:
`render.sh` declares seven vocabularies as `readonly` constants — status,
priority, kind, held, blocked, columns, options — and the **axis** vocabulary is
the one it does not. Axis names exist in three places instead: a case pattern
that derives them from flag names, an `elif` chain of literals, and the guard's
own hand-written list. Three independent enumerations of one set, and the third
is a subset of the other two. **A set the rule quantifies over was re-derived at
each point of use instead of declared once and iterated.**

`#397` is the instructive variant: `RENDER_OPTIONS` *is* declared — it is simply
the wrong set for the rule, which quantifies over any flag rather than over this
file's own. Declaring a set does not help when the rule ranges over a different
one.

A second, weaker shape connects `#386` and `#394`: **a guard whose correctness
rests on the narrowness of its inputs, with nothing stating the dependency.**
The placement wrapper's adjacency rule held while no caller could supply
`--dir`; the `--spec` prefix comparison holds only because the allocator
enforces ordinal uniqueness and fixed-width padding, two invariants that live in
another group and are referenced nowhere near the comparison.

### The rest, grouped

**Same-rule siblings of the blockers** — `#388` (a column naming an unanswerable
field renders blank at rc 0, the same indistinguishable emptiness one surface
further out) and `#397` (an unrecognized flag accepted as a flag's value).
Both close naturally with the blocker they belong to.

**Latent couplings** — `#394` (the `--spec` boundary, above) and `#398`
(`migrate.sh` and `transition.sh` still pass untrusted values to awk through
`-v`, the channel this project decided against and `backfill.sh` already avoids;
pre-existing, untouched by this build).

**Cleanup this increment owes** — `#391` (`is_filter_token` had three callers
before the build and none after; task 8 replaced its last caller without
deleting it) and `#393` (eight comments still cite a spec, AC or Finding number,
which this project forbids because its own rename verbs renumber what they
name).

**Correctness edges** — `#389` (a `depends-on` target absent from the collection
reads as unblocked rather than as unjudgeable), `#392` (a person query is
whitespace-trimmed, so the one class of identity the spec promises is reachable
"by naming it exactly" is not), `#395` (moving the census counts from the index's
Summary lines to the rows made the two able to disagree — an adversarial-input
divergence this build introduced).

**Test debt** — `#396`, six behaviors correct by trace and pinned by no case.

## Suggested remediation

### Order

**First, `#387` with `#388`.** They are one fix wearing two labels. The
condition is already computed from state the row loop keeps (`seen_rows`,
`saw_type`); lifting the check into a helper both read verbs call, adding `held`
to the enumeration, and extending it to `FILTER_COLS` closes the invariant
violation, the AC gap, and the column gap in one diff. Doing `#387` alone would
leave the identical hole one surface out, which is how it got there.

Worth deciding while in there: a *filter* that cannot be answered makes the
whole result wrong, while a *column* that cannot be filled leaves the rows
correct and one column blank. Refusing may be too strong for the column — a
disclosure line beside the view, like the closed-hidden one, may fit the
severity better. Either beats silence.

**Then `#390` with `#397`.** Also one shape: the operand guard's enumeration of
bad operands is short by two entries. Refuse when a flag yields zero
alternatives after splitting and trimming, and refuse a `--`-prefixed operand
while continuing to carry a single-hyphen one through — the latter matches the
design decision's own stated rationale exactly, which was about addresses
wearing a leading hyphen, not about double-hyphen tokens.

Those two steps clear one of the two blueprint violations, the medium
`staleness-gated-reads`, and three of the five partial ACs — the ones citing
Findings 1, 2 and 3. They do not clear `placeholder-by-position`: that is
`#386` below, and the plan's gate is not satisfied until it lands too. The
two partial ACs left over cite Finding 6 (`#392`) and Finding 9 (`#394`),
both further down this order.

**Then `#386`.** It is last among the blockers because it is the only one whose
fix is not local to this increment's code — the weakness is in
`place_substitute`, which every entry script shares, and the right repair is a
design choice rather than a missing branch. The substitution infers intent from
adjacency; the options, in increasing strength, are to have callers pass the
placeholder *positions* they built rather than have the wrapper re-derive them
from text, to track only the flag the wrapper itself emitted, or to refuse a
caller-supplied argument that is exactly a placeholder token in each parser.

The first removes the inference entirely and is the one I would take, but it
changes a shared interface — which is exactly why it should not be bundled with
the read-view fixes above.

**Then `#391` and `#393`**, the cleanup this increment owes. Both are deletions.
`#393` is worth doing across the sibling scripts in the same pass rather than in
`render.sh` alone, or the sweep gets forgotten half-done.

**Then `#392`, `#395`, `#389`** — real, small, and none of them urgent. `#392`
has the neatest fix (trim around the delimiters rather than around the whole
value, which keeps `high, critical` working and leaves `" alice"` intact).

**`#396` as the surrounding code is next touched**, not as a batch — except its
fifth item, which pins a type-gating property in `insights-graph` that a future
edge-reader refactor could silently drop. That one is worth doing on its own.

**`#394` and `#398` last, and deliberately.** Neither is a defect today. `#394`
is a dependency to *state* rather than a bug to fix — the acceptance criterion
positively wants the loose prefix match. `#398` is pre-existing and bounded by
its callers' own gates; it is worth doing because the project already decided
the channel is where the guarantee belongs, not because anything is reachable.

### What not to do

**Do not fold either invariant to match the current code.** Both violations
resolved `fix` at the blueprint fork, so `placeholder-by-position` and
`staleness-gated-reads` still declare the properties the code must return to.
Softening either would encode a regression as intent — and in `#387`'s case
would mean writing down that a census may answer confidently from an index it
knows cannot answer.

**Do not fix `#387` without `#388`, or `#390` without `#397`.** Each pair is one
enumeration short of one rule. Fixing half of either leaves the other half
looking deliberate.

**Do not treat `#389`, `#392`, `#394`, `#395`, `#398` as urgent.** They are real
and small, and bundling them into the blocker work would obscure it.

**Do not reach for `--cols` or `unblocked` as scope to trim.** Both were
explicit additions the developer pulled into scope after they had been proposed
as out of it.

### A process note worth keeping

**Independent adversarial reading found the defects; execution corrected the
mechanisms.** It is worth separating those, because the first sentence of this
section originally said the opposite and had to be checked against the record:

- `--label ,,,` matching everything, `list unclaimed` misreporting a held
  record, and the census/Summary divergence were each **found by reading** — by
  an investigator or a judge given the criterion separately from the code and
  told to default to unproven. Running them confirmed all three.
- What execution actually corrected were **confident, specific, wrong claims
  about mechanism**: security Finding 1 asserted twice that a bound directory
  would reach `index.sh`'s `mkdir -p`, and both versions were wrong; a test
  assertion of mine claimed a read never indexes a named empty collection, and
  it does; and my own first summary of `#387` called it an empty result when it
  is a populated, wrong one.

So the two techniques answer different questions. Reading finds *what is
missing*. Running settles *why*, and it is the only thing that reliably catches
a fluent explanation of a mechanism that does not exist. The suite was green at
1,608 tests throughout — it never distinguished either.

Two more worth recording, both about the review itself:

- The feature's own disclosure fired on its first real query. The
  unanswerable-axis guard refused `--claimed-by me` against this repository's
  tracked index immediately after the build, because that index predated the
  widening. The mechanism worked — and it is what exposed the two axes it does
  not cover.
- Two investigators reported that they could not run `git show` and said so
  rather than inferring. Both comparisons were then closed directly against the
  commits. A read-only boundary is only safe when the agents inside it disclose
  what it cost them.

## What running it settled

The order above was executed in full — steps 1 through 5, in the sequence
given. Ten issues are closed: `#386`, `#387`, `#388`, `#389`, `#390`, `#391`,
`#392`, `#393`, `#395`, `#397`. The suite moved 1,608 → 1,623. Both blueprint
violations resolved `fix`, never `fold`, as § What not to do asked. The plan's
gate is satisfied: review and sensor have both come back against the fixes
rather than the original build, so the hold this document describes is
discharged.

| step | issues | commit |
| :--- | :--- | :--- |
| 1 | `#387` + `#388` | `9f292f0` |
| 2 | `#390` + `#397` | `95d56cc` |
| 3 | `#386` | `9cc6185` |
| 4 | `#391`, `#393` | `da7bd34`, `0d7c820` |
| 5 | `#395`, `#392`, `#389` | `74a91d2`, `d63357d` + `2a22a21`, `52d071e` |

### Where this analysis was short

Five places, each worth more than the fix it misjudged.

**The steps-1+2 claim was wrong twice** and contradicted the paragraph two lines
below it. Corrected in place; the sentence now says what steps 1+2 actually
clear. The count error came from never mapping the five partial ACs back to
their findings.

**`#393` was scoped to one file and was mostly in five others.** This document
counted eight comments — accurate for `render.sh`, and two of those were already
gone by the time the sweep ran. The group held **34**, and the convention is
project-wide: three scripts in two other groups carry ~58 more, now `#401`. The
instinct to warn against a half-done sweep was right; the size estimate behind
it was out by four times.

**`#395` was called small and was three classification sites.** The index judged
raw scalars while writing sanitized ones, so besides the Summary count, both
vocabulary checks judged a value they did not print — `type: "issue<0x01>"`
warned `unrecognized type: issue`. One rule computed from two values at three
points, which is the retrospective's shape again, in a defect this document
grouped as a correctness edge.

**`#392`'s "neatest fix" collides with step 2 — and aims at the wrong input.**
The collision is real, and naming it was this document's best call: trimming
around the delimiters does keep `high, critical` working, but the edge trim is
also what makes step 2's yields-no-alternative refusal work. Remove it and
`'   '` becomes a recordable alternative matching nothing instead of refusing,
and `case_issues_render_operand_naming_no_alternative_refuses` fails on it.

What this document, the review finding and the issue all had wrong is *which*
values were unreachable. `" alice"` — the example all three reached for — was
already reachable, by `alice` and by `" alice"` alike, because the row reader
ate leading whitespace and the query's own trim landed on the same string. Two
trims were cancelling. The unreachable class was **trailing** whitespace, and
it was unfilterable by every spelling rather than by all but the exact one. So
the fix was two seams, not one: the query side, and the row reader trimming
underneath it. Fixing only the recommended half would have left the index
contradicting its own readers.

**`#389` was filed with a fallback that does not exist.** Grouping it as a
correctness edge was right. Its issue offered leaving it to "the index's
dangling-edge warning, which already fires" — but that warning reports missing
reciprocity, not a missing target, and fires identically for a dependency that
resolves perfectly well. Nothing reported the absence on any surface. An option
written down as the status quo turned out not to be one.

### What it did not anticipate at all

Re-running the living-intent sensor against the fixes surfaced work this
document has no entry for, because it is analysis of a review rather than of the
code: `#399` (the schema gate cannot see a partly converted collection — the
premise this increment carried to two more surfaces), `#400` (**critical** — the
skill's own usage templates inline `title` and `origin` into the command line
its scripts route the body around), and `#402` (**high** — the vocabulary
discipline holds inside each script and breaks between them).

`#374` also escalated from a wrong counter to a blocked capability: the faces
verb loses a provides entry that does not lead with a backticked token, and one
dotted key per requires bullet. A reconcile over a changed face now has to
choose between a stale graph and a fabricated leak.

Step 5 added two more, both found by probing rather than by the sensor.
`index.sh` warns `names an umbrella not in the collection` when a `part-of`
target is missing and has no analogue for `depends-on`, so the collection
already has the shape of that check for one relation type and not the other.
And the blueprint's `row-shape-is-the-writers` is stated writer-side only —
the row reader now upholds its read-side half, which the invariant does not
yet say.

### What still stands

`#396` next, as the surrounding code is touched — except its fifth item, which
is worth doing on its own — then `#394` and `#398` last, and deliberately.

§ What not to do stands unchanged. Its two rules were both borne out, and step 5
supplied a third instance of the same lesson from a different direction: not two
issues that had to be fixed together, but one issue whose fix had to reach two
seams, because the trim it named was applied at both and cancelling.
