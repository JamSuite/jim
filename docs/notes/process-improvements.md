# Process improvements

Craft that has earned its place across jim's build/fix/review rounds. Each rule
carries the evidence that produced it — a rule without a scar is a preference,
and the next author needs to know which is which.

This is the transferable half of what session handoff notes carry. Handoffs are
disposable and spec-scoped; this file is neither.

*Rules originally numbered as the id-coordination cluster's "adopted practice"
set live here now, under names rather than numbers. They cross-referenced each
other as "practice 7's sibling" and so on; a number is a worse handle than a
name once the list stops being one list.*

## Verification

### Neuter the guard, watch the case go red

A fix is not proven by a passing test. It is proven by disabling the guard the
fix installs and watching the case that names it fail. Five traps, all of which
have bitten:

1. **A neuter that appears applied may not be.** Always `diff` against the saved
   copy — an empty diff means the pattern missed and you are about to record a
   proof you never ran. This has happened twice in one round. Retarget to a
   one-token change (empty a probe variable, make a path unreachable) rather than
   a multi-line replacement.
2. **Restore with `cp` from an absolute scratchpad path, and verify with
   `md5sum`.** A relative restore path is one `cd` away from silently leaving the
   neuter in place.
3. **Pass `perl` replacements through `$ENV{NEW}` and gate on `bash -n`.** An
   interpolated replacement can produce a file that parses as something else
   entirely.
4. **Assert on what a reader resolves, not on whether the attacker's text
   survives.** A frontmatter injection case that greps for the injected string
   passes whether or not the parser was fooled; assert the *field value a reader
   gets*.

   This is the trap that recurs most. It bit three times in a single round, each
   time on a case written to prove a sanitizer. Sanitized text *legitimately*
   survives — a rejected filename is quoted back in its own refusal, inert inside
   a code span — so "the string is absent" is the wrong property and fails
   against a correct fix. The right assertions are structural and countable:
   exactly one `## Issues` section, no line matching a row's shape, exactly one
   separator in the rendered row. If a case's assertion cannot be stated as a
   count or a shape, it is probably asserting the wrong thing.
5. **A layered guard needs its own proof.** Where two guards sit in one loop,
   neutering the first leaves the case green — the second catches the input — and
   the obvious readings are both wrong: that the neuter missed, or that the guard
   is redundant. Neither. The guards produce different *outcomes*, and the case
   has to assert the outcome, not the absence of damage.

   A containment check and a symlink skip sat three lines apart. With containment
   neutered nothing escaped, because the skip dropped the entry anyway — but the
   run exited 0 in silence where it should have refused and named the path. The
   fix is to assert the refusal (`rc`, the message) as well as the damage that did
   not happen, and to give each guard a case whose failure is *its* failure. **A
   proof that the hole is closed is not a proof that the guard you wrote is what
   closes it.**

   The harder variant is two mechanisms that produce the *same* outcome, where
   there is no distinguishing outcome to assert. A plan called an end-of-options
   separator "the whole fix" for option-shaped values reaching `git
   check-mailmap`. It is not: the value is also wrapped in angle brackets,
   because that is the input form the command accepts, and the wrapping alone
   neutralizes option shape — `git check-mailmap "<--help>"` with no separator
   returns `<--help>` as data. Removing either mechanism leaves the case green.

   Neither is redundant enough to delete, and no case can isolate one. Say so at
   the case: record which property is pinned and that the individual mechanism is
   not. Otherwise the comment claims a proof the case cannot deliver, which is
   the same false confidence as an overstated rationale. Two independent routes
   reached this correction in one increment — hand-verification during the build,
   and a test-discrimination audit afterwards — which is what makes it worth
   writing down rather than fixing quietly.

### A case that cannot go red is a finding

If removing the shipped guard leaves the case green, the case is pinning
something else — usually a guard earlier in the same function, or a rejected
alternative that was never built. Fold it into the case that does go red rather
than leaving it standing. A standing case that cannot fail is worse than no case:
it reports coverage that does not exist.

Four such cases survived into the fourth review of `issue/011`, one of them the
only thing protecting an acceptance criterion's installed-base guarantee.

**The inverse also happens: a case can be green because the bug is defusing the
attack.** One case written red-first passed against the unfixed code, because the
defect it targeted mangled the hostile input before it reached the site under
test. It went red the moment the *first* of two fixes landed, and green again
with the second. Treat a red-first case that passes as unexplained until you know
why — the answer is either that it pins nothing, or that a second defect is
currently masking the one you are chasing.

**And a case can be green because the fixture's own ordering defuses it.** A
symlink inside a swept directory should not be rewritten through; the case that
proved it stayed green with the guard removed, because the link sorted *after* its
target. By the time the rewrite followed the link, the target had already been
swept and there was nothing left to rewrite — the write happened and changed
nothing. Renaming the link so it sorts first made the case able to fail.

That is the same rule with a third cause. The first two are about the assertion
and about a second defect; this one is about **enumeration order inside the
fixture**. Where a case depends on the system reaching one input before another,
the ordering is part of the fixture's contract: state it in the case's comment, or
a later reader tidying a filename will silently disarm the case.

**One kind of case may legitimately stand without going red against the unfixed
code: the one pinning a guard's boundary rather than the guard.** A parser fix
refused an operand equal to one of the verb's own flag names, deliberately *not*
refusing every operand with a leading hyphen — the recordable-identity set admits
one because real addresses carry it. The case asserting that `--from -x` still
works cannot fail against the old parser, which accepted everything.

From the outside that is indistinguishable from the failure this section
describes, so it has to be told apart on purpose: **find what the case does
discriminate against, and write that in its comment.** This one goes red against
the *stricter* reading — the obvious tightening a later reader reaches for, which
would silently break every address wearing a hyphen. A case whose discriminating
mutation is a plausible **wrong fix** rather than the **absent fix** is worth
keeping; a case with no discriminating mutation at all is the finding.

The difference is one experiment. Skip it and you either delete a real guard or
keep a case reporting coverage it does not have — and this section, read
literally, tells you to delete it.

### Audit the surface, not the case

*Neuter the guard* proves one fix at the moment it lands. It cannot find the
cases that were already standing when you arrived, because nothing prompts you
to question a case you are not touching. For that, invert it: mutate the
**surface** — one behaviour removed per mutant — run the subset against each,
and record which cases go red. A case no mutant kills is the finding.

This is **mutation testing**, applied by hand rather than by a tool, and knowing
the name is worth more than the method here — the field has the vocabulary and
the known costs already. A seeded variant is a *mutant*; a test that fails
against it *kills* it; one nothing kills is a *surviving* mutant; killed over
total is the *mutation score*. Its expensive problem is the *equivalent mutant*
— a change no test can possibly detect, which is undecidable in general.
Generated implementations exist for most languages (`pitest`, Stryker,
`mutmut`, `cargo-mutants`) and for none of the shells, which is why this was
hand-rolled.

One pass over an identity surface cost twenty-three mutants at about twenty
seconds each. It confirmed six reported non-discriminating cases and found three
nobody had reported, in cases nobody was editing.

**All three were one shape: an assertion matching a substring that two branches
share.** Remove the several-domains guard on a config value and the charset gate
refuses the same input; both messages name the setting, which is all the case
matched. Remove the both-halves-of-a-remap guard and the recordability check
refuses the empty half; its message names the same flag. The shape is
searchable — **where a guard's refusal shares vocabulary with the guard behind
it, matching the shared words pins the outcome and not the guard.** Match the
phrase only this branch can produce.

A fourth cause of a case that cannot go red belongs beside the three above:
**a symmetric property asserted from one side.** Case-insensitive matching
between an operand and a stored value was driven with a lower-case operand
against a mixed-case record, so the fold on the operand's side was pinned by
nothing. Where a property is symmetric, one direction is half a case.

**Pairing is a third remedy, and the only one that recovers coverage rather than
documenting its absence.** Some cases cannot discriminate alone: an address the
alias mapping does not mention comes back unchanged whether the lookup ran or
was deleted outright, and no assertion separates those. Adding a *mapped*
address to the same fixture does — the pair says a lookup happened and left this
one alone. Reach for it before *fold it into the case that does go red* or
*record what it cannot prove*.

**Two ways the census lies, both silent, both false negatives.** They cost three
re-runs here, and both read exactly like a verdict.

- **The mutant did not apply.** A replacement requiring a unique match no-ops
  when the pattern occurs three times — and a subcommand's index-regeneration
  call usually does. Make the harness die loudly on any match count but one, and
  do not discard its stderr, which is where it says so.
- **The case did not run.** Running each mutant against a *filtered* subset is
  what makes the census cheap, and a filter named after the surface excludes
  every case named after something else. Three cases read as non-discriminating
  for a whole round because the filter never selected them.

Assert the case was *selected* before believing it survived. This is trap 1 of
*Neuter the guard* at a larger scale: an experiment that did not run is
indistinguishable from one that found nothing.

### The reach of a proof

**Neuter-and-verify proves a fix. It says nothing about what the edit is now
adjacent to.**

Three consecutive remediation rounds on one spec introduced new defects, each
time by composing two individually-correct changes. In the third round both new
defects were proven red-first against the defect they targeted, and both broke a
guard sitting one loop away in the same function:

- a discriminator fix moved a downgrade *past* the reservation loop its sibling
  downgrades sit inside — silently destroying a file on the success path;
- a routing fix correctly stopped enumerating one source, then re-added a
  different source *past* the containment guard that had been protecting it.

Neither guard was named by any open issue, so the by-file rule below did not
point at them.

**The rule that would have caught both:** after the fix, re-read the whole
function and ask what else in it depends on the state you just moved.

Applied prospectively, it works. A later round fixed an enumeration that had been
mangling untrusted filenames; re-reading the function showed the raw name now
reached a refusal message that concatenated it unsanitized, which was a fresh
row-forgery route created *by* the fix. Both edits shipped together. The rule's
cost is one careful read; its absence has cost three rounds.

### Test the mechanism, don't assume it

A fix that rests on a tool's behaviour is only as good as your belief about that
behaviour. Two assumptions in one round would each have shipped a fix that did
not do what its comment claimed:

- `--no-verify` was assumed to keep a commit subject fixed. It does not: it skips
  `pre-commit` and `commit-msg` and leaves `prepare-commit-msg` free to rewrite
  the message. Observed by installing such a hook and watching the subject
  change. The fix became `-c core.hooksPath=<nonexistent>`.
- An `:(exclude)` pathspec was assumed to drop a namespace from a staging call.
  Under `--literal-pathspecs` the magic is disabled, the pathspec matches
  nothing, and the *whole command fails* — so the "exclusion" would have broken
  the publish outright. The fix became an explicit unstage.

The same discipline applies to a claimed equivalence you are about to rely on.
Deleting a redundant re-sort rested on "bash glob order equals `sort` order under
`LC_ALL=C`". Sweeping one filename per byte value 1–255 confirmed it — and found
the single exception, an embedded newline, which turned out to be the attack the
fix existed to stop. The check cost one command and upgraded the fix's rationale
from plausible to demonstrated.

### Count the structures, not the bytes

A mechanical transform over a structured document needs a check the transform
cannot pass by accident, and text equality is not it.

Rewrapping a 214 KB `ARCHITECTURE.md` at 80 columns was verified two ways before
it was installed: both versions collapse to identical text under whitespace
normalization, and every block-structure count matches across them — fences,
headings, bullets, quotes, table rows, blank lines. The first check is the
obvious one, and it passed on an output that was **wrong**. A wrapped line had
come out beginning with three backticks, because the document discusses fenced
code and the wrap put that word first; markdown read it as a fence, parity
flipped, and several hundred lines after it were silently reclassified as code.
Whitespace normalization cannot see that — every word is still present and in
order — and neither can a person reading a 2,700-line diff.

**Where a transform preserves content but can alter structure, count the
structures on both sides.** It is one `awk` pass, it is the only check that
fails on the failure mode that matters, and it generalizes past markdown: the
same shape catches a YAML reindent that changes nesting or a table rewrite that
changes column count.

The reflow gained a rule from what the check found. A break that puts a word at
the start of a line turns that word into markup if it is `#`, a lone `-`/`*`/`+`,
a `1.`, a `>`, a `|`, or a fence — and prose *about* markup is exactly where that
fires. Carry such a word onto the previous line and let it run over budget; eight
lines of that file sit 82–85 characters wide, which is the right price.

The same session lost three lines of a notes file to a `head -N` / `tail -n +N`
splice with an off-by-three boundary, and did not notice for two commits: the
paragraph simply began mid-sentence, and a splice looks like an insertion in a
diff. When you assemble a file from slices, diff the result against its input for
lines you did not intend to touch.

### An ordering can be load-bearing and held by nothing

A sanitizer ran `tr` (strip control characters), then `sed` (strip the row
separator), then `cut` (cap the length). The order is not incidental: deleting a
control byte can bring the separator's own two bytes together — `C2 01 B7`
collapses to a reconstituted `·` — and the separator strip removes it only by
running afterwards. Reversed, a title forges a second field.

Nothing held that property: not a comment, not a test. A routine tidy-up of three
pipeline stages would have reopened row forgery silently. When a pipeline's
correctness depends on stage order, that is an invariant — write it at the
function and pin it with a case, because it is exactly the kind of thing a later
reader will "simplify".

### A green suite is necessary and says nothing more

All 903 cases passed while three `critical` defects shipped, because each was an
omission, a shared blind assumption, or deliberately reused code the suite never
re-examined. A suite tests what someone thought to test; it is silent about the
rest, and at a completion gate that silence reads as approval.

Treat "tests pass" as a precondition and **say nothing further about it in a
gate**. A gate that cites the suite as evidence of correctness is citing the one
artifact structurally incapable of reporting its own gaps.

### Fixtures inherit the author's blind spot — run it against real data

The two worst defects of one increment were found the same way, and neither by
the 78 cases written alongside the code.

A new verb shipped with 30 passing cases and was broken for its primary use.
The collision check compared raw source addresses, so two spellings of **one**
contributor — unified by the project's own alias mapping — were refused as a
merge of two people, disabling the whole feature for exactly the projects a
mapping exists to serve. It surfaced on the verb's first run against the real
collection, which held precisely that pair. Every fixture had used addresses the
mapping said nothing about.

The second was a charset gate that had stopped refusing: an alias step inserted
ahead of it reduced malformed values to a clean substring instead of rejecting
them. Found by adversarial reading. No fixture carried a bracket-bearing value.

The suite was not too small. **The fixtures were drawn from the same model of
the problem as the code, so they systematically avoided the shapes the code
mishandles.** More cases from the same author reproduce the same blind spot; a
different kind of input does not.

The practice: before believing a suite about a new verb, **run the verb against
production data once**. It is the one input nobody designed, and it costs a
single invocation. Where the data is a collection you can preview against, the
preview is free — the first real preview of this verb was what caught the design
bug.

The rule landed a second time on the same increment, from the other direction. A
migration preview gained a check for the two structural anchors its apply step
writes against, and four standing cases went red — each describing a legacy
record as title, status and priority alone, a shape the conversion could never
have completed, standing in for the ordinary case. The fixtures had been wrong
since before the check existed and nothing could see it, because every case using
them asserted something else. **A fixture that cannot survive the operation under
test is a defect the suite is structurally unable to report.** They now share a
named helper carrying the shape the real corpus has, and the impossible shape
appears only in the case that is about it.

### Reproduce a finding before believing it

A fan-out reported three criticals; one was refuted by a thirty-second shell
experiment, after **two** investigators had independently reasoned it into
existence from bash subscript semantics. That was the second consecutive build
where a reasoned-from-source finding died on contact with a shell.

The third build made the pattern impossible to dismiss: **three** of fourteen
findings were refuted, each by one command. One was an attribution hijack that
depended on git returning the *last* parseable contact from a malformed
argument — it returns the first. One was a false-negative in a collision
fallback that a second investigator, reading more carefully, showed was
fail-safe. And one was the arithmetic-subscript claim **again** — a different
investigator, a different build, the same inference from the same bash
semantics, refuted the same way.

That recurrence is the useful part. These are not random errors; a particular
kind of plausible-but-wrong reasoning about shell semantics regenerates itself
across independent readers. When a finding turns on what bash or git does with
an unusual input, the cost of checking is one command and the prior is that it
is wrong.

Reading generates findings; running confirms them. A review reporting an
unreproduced critical is reporting a **hypothesis** and should label it one. The
corollary is the expensive half: re-run the same reproduction against the fix, so
"fixed" is also a measurement rather than a second hypothesis.

The same applies one step earlier, to a *proposed* fix. Two of three proposed
actions in one criticals pass were wrong — one would have introduced a new
refusal bug if implemented literally, and one cited a precedent the registry
itself disproved. **Before implementing a proposed action, run it: confirm it
fails without the fix and passes with it.** A proposal that cannot be told apart
from the status quo has not been specified.

### A clean result does not disclose its own coverage

Two failure modes, one shape — and both read exactly like success.

**A practice that did not run leaves no trace.** A harness-injected directive
suppressed a judge fan-out; the rung ran inline and reported "10 invariants, 0
violations" over code containing two. Nothing in the report distinguished that
from a clean run. Every practice detects something about the code; none detects
its own absence.

**A practice that ran over less than it appears to leaves no trace either.** A
finding whose entire subject was "fixed one, missed the sibling" stated its own
scope as nine references under one directory; a wider sweep found four more on
live surfaces. The pass that catches an incomplete sweep swept incompletely and
reported a count that read as exhaustive.

Two rules follow. A run must **name the degradations it can see** — an unscoped
floor, a capped fan-out, an undispatched judge — and a surface whose contract
rests on independent judgment should decline to report a clean result at all when
its independence was removed. And **a stated scope is a claim, not a
measurement**: re-derive it before acting, never inherit the reporter's grep,
because the reviewer who wrote it was subject to the same incompleteness it
describes.

A related trap: **a project cannot detect its own unrepresentativeness.** Where
code hardcodes a value a configured resolver would also return, the two coincide
*here*, so every local check passes and the defect fires only where the
configuration differs — which is most installations. A green check against this
repo is evidence about this repo.

### A grep over a wrapped document measures the rendering, not the content

Four probes in one session returned wrong answers about a document that was
correct, by three different mechanisms. None of them errored, and every one
read like a finding.

- **A phrase split by the wrap.** A count of `External Constraint` citations in
  an 80-column spec came back one short, because in that one citation
  `External` ended a line and `Constraint` began the next. The document was
  right; the count was not.
- **An absence that could not have been proven.** A check that a corrected
  phrase was gone returned nothing. It genuinely was gone — but the same
  pattern returns nothing for a phrase that merely wrapped, so the method
  could not distinguish removal from invisibility. A clean result from a
  pattern that could straddle a break is not evidence.
- **A marker that means two things in two sections.** Counting `- [ ]` to get
  acceptance criteria over-counted by two, because open questions use the same
  checkbox marker further down the file. The count was of a syntax, not of a
  population.
- **A diff filter eating the lines it was meant to keep.** Reading a diff as
  `grep '^[+-]' | grep -v '^[+-][+-]'` — added and removed lines, minus the
  `+++`/`---` headers — silently dropped every **added markdown list item**,
  because `+` followed by a list `-` matches the exclusion exactly. The
  conclusion drawn was that a hunk touched nothing it in fact touched.

The shape is one: **a pattern matched against rendered text measures the
rendering.** Wrapping, sibling syntax elsewhere in the file, and the diff's own
markers are all part of that rendering, and none of them is part of what you
were asking about.

Three remedies, each one command:

- **Unwrap before searching prose.** `tr '\n' ' ' | tr -s ' '` then grep. Any
  phrase question about a hard-wrapped document should go through it.
- **Scope before counting structure.** `sed -n '/^## Section/,/^## Next/p'`
  first, because the same marker legitimately means different things in
  different sections and a whole-file count silently unions them.
- **Read diffs by hunk, not by line prefix.** `git diff -U0` and read the
  hunks, or match `^\+` and `^-` separately rather than composing a class that
  a list marker can satisfy.

This is *The measurement apparatus is a source of error* in its cheapest form.
What makes it worth its own entry is that all four failures were **silent and
plausible**: three under-reported and one over-reported, and every result was a
number or an emptiness that fitted the story being told, so none of them looked
like an anomaly.

**Not one was caught by the result looking wrong.** Each was caught by a second
measurement taken a different way — and the first only because a hand tally
made minutes earlier disagreed with it by exactly one. That is the argument for
the remedies above being defaults rather than things reached for when
suspicious: suspicion is the input none of these four produced.

### Name the set before you write the enumeration

Every corpus-shaped guard in one pass was too narrow in the same way: a sanitizer
sweep covering 1 of 16 files; a width guard missing the two spellings that caused
the drift it exists to catch; a stray-file detector that could not see the
directory named in its own description; a doc sweep omitting every agent body; an
audit covering one arm of six. In each case a correct derivation pattern already
existed nearby and was not used.

The practice is not "check the corpus". It is: **when you write a guard, name the
set it must cover before you write the enumeration that covers it, and make the
enumeration derive from that name.** A hard-coded list is the failure; a
`<thing>_verbs()` helper the guard iterates is the pattern.

Note what this rule is blind to on its own, and why it needs the neuter
discipline beside it: a guard can be mutation-proven *and* have a corpus too
narrow to matter, because the case that goes red is scoped to the same narrow
corpus. Mutation testing proves a guard **discriminates**. It cannot tell you the
set was too small.

The counter-example is worth as much as the pattern, and it arrived in a file
that already held two derived sweeps. A third sweep beside them carries its verbs
in an array written into the test, under a comment claiming "a fourth verb, or a
fourth surface, has to be added everywhere or fail here". The surfaces are
looped, so a fourth surface would. A fourth verb would not — and one had already
shipped without reaching even the script's own header roster, unnoticed by the
check whose entire purpose was that class. **A sweep that carries its own list
has the defect it exists to catch, one level up.**

That one resisted derivation, and the reason is the useful part: the script's
verbs are not one population. Some are called by other scripts and belong in no
operator table; some are hand-run and belong in all of them; nothing in the
script separates the two, so a sweep reading its dispatch would demand rows for
verbs that should have none. **When a population cannot be derived, that is a
finding about the code, not a licence to hand-write the list.** It was filed
rather than bodged.

### Fixture the caller, not just the function

Two of the worst defects in one build lived in code whose tests call the function
directly, because the condition — a concurrent writer, a subdirectory CWD —
cannot be staged through the command surface. Each function was correct in
isolation and wrong in context.

When a plan proposes a guard whose fixture cannot go through the front door, that
is the signal to **fixture the caller** and to **state the guard's premise
explicitly as a claim to check**. One of those two rested on "`mv` preserves the
inode", which is false across a filesystem boundary and was never written down
anywhere.

## Organizing a fix pass

### Prefer removing the construct to guarding it

When an unsafe construct turns out to be redundant, delete it rather than
hardening it. An index enumeration round-tripped filenames through a word-split
array assignment to sort them — but the glob that produced the list had already
sorted it, so the sort bought nothing and cost containment. Quoting the split
would have hardened a construct that did not need to exist; removing it deleted
the splitting surface outright, and dropped a `sort -z` dependency the proposed
fix would have added.

The same move applies to a guard whose correctness depends on a claim about
somebody else's behaviour. A sweep appended one provider's entries *past* its
containment check, justified by a comment asserting those entries were safe "by
construction" — true of one of the provider's two arms. The fix is not to ask
which arm ran, but to make containment a property of the enumeration itself:
every path must resolve inside the root it came from. A guard that asks nothing
about its provider cannot be wrong about it.

That shipped, and the price is worth naming: on the arm that *does* materialize,
the new check is redundant, and it costs three lines. Redundant containment is a
cheap thing to buy and a coupling to a provider's internals is an expensive thing
to keep — the exchange rate is not close. Expect the redundancy to read as
over-engineering to a reader who only sees the safe arm, and say in the comment
why it is there.

### A verb's contract is what its consumers gate on

Before making a function "more honest", read what branches on its output. Two
verbs answered adjacent questions — one *"should you re-exec through the placement
door?"*, the other *"which arm, and here is the directory"* — and a consumer read
the first as though it were the second, which is how a containment gap arrived.

The tidy-looking fix is to make the first verb report the arm. It is wrong: entry
scripts gate their re-exec on that value, so the "honest" answer would stop them
routing and silently drop the auto-commit that an acceptance criterion depends
on. A containment bug would have been traded for a publishing bug.

**A verb's contract is the union of what its callers do with it, not what its
name suggests.** Establish that before changing what it returns.

### An item can dissolve rather than being fixed

An issue that lists several symptoms will sometimes lose one when the cause moves.
A hygiene issue named two things about one enumeration: that a routed collection's
worktree fork was being swept, and that the index-regeneration guard could never
fire for that fork. Dropping the fork from the enumeration answered the first and
left the second with nothing to be about — there is no longer a fork in the sweep
whose index would need regenerating.

**Say so in the resolution.** "Dissolved" and "not done" are opposite facts that
look identical in a diff, and a reader checking the issue's item list against the
change will otherwise find an item with no matching edit and no explanation. The
same note is what stops a later round re-fixing a symptom whose cause is gone.

### An inconsistency is evidence, not a verdict

An issue reported two quiet failure paths in one script as a single defect: a
timestamp resolver that emptied its value and let the run report success, and a
publish call that returned without unwinding the door every other exit in the
function unwinds. The first was real. The second was correct, and "fixing" it
would have destroyed work — the placement door frees a handle only after a
successful publish, so a refused commit deliberately keeps the developer's edits
for a retry, and adding the missing abort would have discarded them to make the
code look symmetrical.

Every other rule in this file widens a fix. This one narrows one: **an asymmetry
is evidence that something differs, not evidence that something is wrong.**
Establish which before changing it, particularly when the symmetry argument is
the whole case for the change.

The issue itself asked for exactly that — "worth determining rather than leaving
to inference from an inconsistency" — and that is the shape to copy when filing.
A reporter who cannot tell an oversight from a deliberate difference should say
so; it is the line that stopped this one being fixed into a bug.

The answer then belongs at the asymmetry. It read as an oversight because nothing
at the site said otherwise, and it would have read that way again to the next
person. The fix for this class is usually a sentence rather than a change.

### Check the remedy against the goal, not the symptom

An issue titled "single lines exceed what its consumers can read" asked for one
thing: wrap the document. Its strongest evidence was something else — the skill
that maintains the file cannot read it, because its own differential-update step
instructs reading the document fully and the whole-file read is refused for size.

Wrapping alone would have satisfied the title and left the evidence untouched.
Reflowing a file does not shrink it: the bytes are identical and the read is
refused exactly as before. The fix that shipped had to change the reading step
too — by section rather than whole — which is worth doing only because wrapping
makes a bounded read cost what it asks for rather than whatever the surrounding
paragraph weighs.

**Where an issue states a symptom and a goal, check the proposed remedy against
the goal.** The two agree often enough that the habit is easy to skip, and the
gap is invisible at review: every criterion the title names is met.

What remained afterwards was a different problem wearing the same symptom — one
section is more than half that document, which no formatting rule addresses. It
was filed rather than folded in, which is the other half of the discipline: a
remedy that does not reach the goal is either extended or its remainder is
tracked, never quietly declared sufficient.

### A census that outgrows the task is a filing

Censusing the mechanism sometimes finds a root much larger than the task in
flight. Asked to fix three issues so a set of blueprints would be correct, a
census found that no `Requires` token on any group face resolved to any
`Provides` entry: the two halves are named in disjoint vocabularies — the
artifact on one side, the capability on the other — so three of the reconcile
pass's six finding classes are decided by reading prose rather than by a join.
Repairing that is a naming pass across four blueprints plus a mechanical check.

The instinct is to re-plan around the root. Don't: **file it, widen the issues
that understate their own rule, and finish the track already in flight.** The
committed batch has a known end and the root does not, so trading one for the
other turns a finishable pass into an open one — and the census survives in the
record either way. Three issues were widened and three filed in a single commit;
the remediation then closed its remaining six.

File the root as its own issue and have the instances point at it. Without that,
the next person fixes an instance under the naming that caused it, which for this
one means adding a face entry only judgment can match — the exact state the
instance was filed about.

### A contract names a site; a site is not a class

Nine of sixteen contracts in one pass were satisfied exactly where the issue
pointed and left unapplied at an unnamed sibling site. One verb recurs three
times as the neglected sibling, across three independent fixes.

**When a fix establishes a rule, enumerate the rule's doors before closing the
issue** — not the issue's doors. The issue names where the defect was noticed,
which is evidence about who noticed it, not about where the rule applies.

Draw that enumeration on the right axis, which is the second half of the lesson.
A later pass did enumerate faithfully — as *verb × entity* — and still missed the
defect class, because the defects lived in *verb × rule*: which verbs read the
structure without going through the classifier at all. The matrix was right; its
axes were not. Ask what the rule is, then what touches the rule.

The third instance adds the trap that makes this rule hard to follow: **an issue
that names a sibling site looks like it has already done the enumeration.** One
issue reported an ungated path composition and carried a `## Scope` section
naming one sibling of the same shape — "both are the same one-line fix and belong
together". Both were fixed, the suite was green at 1,551 across both commits, and
the issue closed with a resolution naming the pair. There were three. The third
was the same rule's fallback arm in a function neither the issue nor the fix pass
had looked at.

A partial enumeration suppresses the independent one. An issue naming no sibling
prompts the question; an issue naming one *answers* it — and the answer is the
more trustworthy for having been written by whoever found the defect. Read a
`## Scope` section as the reporter's hypothesis about reach, which is the status
*A stated scope is a claim, not a measurement* already gives every other stated
scope.

What caught it was the axis. The invariant engine's judge was asked whether the
rule held, not whether the issue was fixed, so it enumerated every site composing
a path and counted guards: **0 / 1 / 1** across three sibling functions. Where a
rule names a call, that census is the mechanical form of this whole section —
count the guard per site and expect a uniform number. **A census that disagrees
with itself is the finding**, and it costs one `awk` pass over the function
ranges. Prefer it to re-reading the issue.

A fourth instance, on the very next task, showed the census works prospectively
— and showed a second way a `## Scope` section defeats it. This one named no
sibling. It named the *question*: "the swallow pattern is shared with `--expect`
elsewhere in the same file, so a fix should consider whether to harden the idiom
generally." A deferred enumeration reads as diligence, and it is one, but the
deferral is only honoured if the fixer actually runs it — and it is the easiest
line in an issue to read as background rather than as work.

Run here, the census was a grep for the *idiom* rather than a count of guards:
five sites across three parsers, where the issue demonstrated two. The three it
had not demonstrated included the worst — a value-less `--expect` consumed the
flag authorizing a destructive whole-collection write and left the drift guard
unarmed, because an empty expectation is indistinguishable from asking for no
check. The reported cases were the mild ones.

So the census has two forms and both cost one command: **count a named guard per
site** where the rule names a call, and **grep the idiom** where the rule is a
shape. Either way the number should come out uniform. A Scope section that
raises the question without answering it is the strongest signal there is to run
one.

The fifth instance is worth the most, because it happened *after* everything
above was written down. A documentation pass — four issues, no code among them —
reproduced the pattern three times running, one pass after this section gained
the census. **A rule stated in prose does not fire on its own.** Whoever is
fixing an issue is reading the issue, and the issue is where the partial
enumeration lives; a notes file is not in that path.

It also moved the rule off code. Every instance above is a guard, a composition
or a parser idiom. These were documents. One issue named two surfaces carrying
an instruction that had gone wrong, and the instruction was wrong in four. One
asked for four frontmatter fields to reach an example block when no document
named a verb that moved any of them, so the fields could not be documented
without the verbs. One asked for a tool grant to be scoped, which turned out to
require the written convention the grant was scoped against to move with it.
Prose drifts from code exactly the way a sibling function drifts from its
guarded twin, and it is enumerable the same way.

That gives the census a third form, and it is the best of the three because it
survives the pass that ran it: **derive the expectation from the authority and
diff the copy against it.** Where a document enumerates what an array
enumerates, do not compare the two lists by eye, and do not write the expected
list into the test either — read the array and assert the document mentions each
element. Two such checks landed in that pass: one deriving a script's documented
verb enum from the array it dispatches on, one deriving a skill's granted
scripts from the call sites in its own body. Counting a guard and grepping an
idiom are things you run; this one is a thing that stays run.

The sixth instance looked more like diligence than any of the others, and it is
the sharpest form of the whole section: **an enumeration of what has been
recorded is not a census of the rule.** Asked whether any other group face
carried the gap one issue described, the obvious census was the project's
declared cross-group contract edges — a real enumeration, mechanically derived,
over the authoritative artifact. It answered "exactly one", and it could not have
answered anything else: it searched only the couplings somebody had already
declared, and an undeclared coupling was the entire subject of the issue.

Censusing the *mechanism* instead — every byte-identity marker in the code —
found four coupling families across three group boundaries, three of them
undeclared on at least one side. The registry knew about one.

So before running a census, ask what the population is made of. **If the set you
are about to enumerate is itself a record of the thing you are looking for, the
census is circular** and will confirm whatever the record already says, with all
the authority of a mechanical count. Census the mechanism — the markers, the call
sites, the code that would exist whether or not anyone wrote it down.

This is the sibling of *By file, not by issue* below, at a different moment: that
one governs reading a whole function while editing it, this one governs
enumerating a rule's reach before declaring it held.

### Assert the verb's assumed property at plan time

Two of one build's three plan deviations were the same defect: an instruction
naming the right change in the wrong place. One of them — a task that said
`rename-tracked` where it meant `move-spec-dir` — went on to generate two
separate issues.

A plan task names verbs it does not implement. **For each named verb, assert the
property the task assumes it has**, at plan time, before any code exists. This
acts earlier than everything else in this file; every other rule here fires at or
after the change.

### A second reader is a disagreement risk, not a correctness risk

Both of one build's criticals traced to a single root: a classifier, the
resolvers, and a realize path applied three different rules for what establishes
a claim — and no reader was wrong on its own.

So when a task adds a reader of a structure something already reads, the question
at plan time is not "is the new reader correct?" but **"what makes the two
agree?"** Convention is the answer that fails. A shared predicate is the one that
holds.

### By file, not by issue

Before editing any function, read the whole function and check every open issue
that names it. A pass organized by issue once edited the exact line carrying a
filed critical-adjacent defect, changed one variable on it, and left the defect.

Its limit is stated above: it finds the *filed* defects in a region, not the
unfiled invariants the region depends on.

### Write the guarantee and the mechanism separately

When the same author writes the code and the prose that claims what the code
guarantees, in the same pass, the guarantee sounds established. One round
produced three artifacts stating a security property the code inverted, plus a
canonical snippet consumers copy that encoded the unsafe case.

Prefer: implement, then verify the claim against the implementation as a separate
act — ideally by a different reader.

## Records

### A resolution note is the durable record

Closing an issue takes a dated `## Resolution` naming what shipped, the commit,
and the case that pins it. A status flip alone leaves the resolution discoverable
only by grepping commit trailers.

**When a note is more complete than the change, the next reader inherits a false
clean.** This has now been caught twice, in consecutive reviews:

- a note claimed a header "names the parsing tools it actually uses" when three
  header inaccuracies remained;
- a note implied a whole file's stale counts were restated when only one pair was.

**The instrument for this is a dated `## Correction` appended to the issue**,
naming precisely what did not land. It is better than editing the original
resolution, because the overclaim itself is information: it tells the next author
which claims in this collection are load-bearing and which were written from
memory.

### Name the guard that ships pinned by nothing

Some guards cannot be driven from outside: the failure they catch is unreachable
because an earlier call fails first, or because the directory they check is one
the script creates and owns. Ship them anyway when they encode a rule the code
depends on — but **say in the resolution that nothing pins them, and why**.

Two consecutive rounds have each shipped one and recorded it as unpinned: a
directory-enumerability precondition, and a check that a provider handed back a
non-empty path. The alternative is leaving them for a later test-integrity sweep
to report as coverage gaps, which is how the same class arrives as a review
finding instead of a known, argued decision. An attempt to reach one that turns
out to exercise different code entirely is worth recording too — it is the
evidence for the unreachability claim.

**Record what makes the guard load-bearing despite being unreachable**, not just
that it is unpinned. The second one reads like paranoia until you know that the
empty string it refuses would have made the loop below it glob the filesystem
root. That sentence is the difference between a guard a later reader keeps and one
they delete as dead code.

### Narrowed, not closed

An issue narrowed rather than closed takes a `## Progress` section naming the
half that remains — and that remainder must be *filed*, not merely described.
"Deferred rather than dropped" is only true if something tracks it. Two issues
closed with `## Progress` remainders that appear in no tracked set.

### Reconcile a review's finding count against its dispositions

One review reported **20** findings. Its filing pass produced **9** issues. Six of
the eleven remaining were neither fixed nor deliberately left — they were lost,
and nothing noticed, because no artifact holds both numbers. The review records
its findings; the issues record themselves; nothing says *every finding has a
disposition*.

Unlike every other rule here, **this check is arithmetic**. The ledger already
stores `findings=N`; a gate can demand N dispositions, each one *fixed* (with a
commit), *filed* (with an issue), or *left* (with a reason).

Do it mechanically or it will not hold. A later pass tried it in prose and
published "twelve findings, twelve dispositions, no remainder" over rows that
sum to fourteen — the pass that adopted the rule broke it in the artifact
announcing it.

### A fold is a waypoint; record the restoration target verbatim

Folding a blueprint invariant to match reality is the right move when the code
contradicts it — the alternative is a document that lies. But the fold silently
rewrites *intent*: an assertion becomes a description, and nothing in the surface
distinguishes a deliberate temporary weakening from a considered statement of
what the group is for. The pre-fold text survives only in git.

So a fold has two halves and only the first is automatic. Write the weakened
text, **and** record on the issue that owns the fix: the pre-fold text quoted
verbatim (so restoration is mechanical, not archaeological), that closing is
incomplete until the invariant returns at least as strong, and which clauses
should *not* come back — a fold is also the moment to notice the original
conceded too much or named a retired mechanism.

Every other rule in this file detects something that went wrong. This one guards
a step that went **right**, which is exactly what makes the loss invisible.

The inverse costs as much: an invariant that still asserts what the code stopped
doing. One blueprint states that a vacated ordinal is permanently gapped
"whatever shape the log takes" while an open `high` issue describes a path
handing that ordinal back — with nothing on either side pointing at the other.
When you find one, connect them, so the issue names its restoration target and
the blueprint is not read as current.

### Close each issue as its fix lands

One spec fixed fourteen issues and closed none, because no plan task covered it —
and the collection misrepresented the project's state until a later review
reconciled it. A batch close at the end is a window in which the tracked set is
knowably wrong, and it is exactly the window in which someone else reads it.

### A line number is the first thing in a record to rot

An issue's `## Where` section named two call sites by file and line. Both were
right when filed. Both were wrong inside the same increment — not because the
defect moved, but because the file grew by roughly 450 lines around them while
the fix landed. Checking the record against current code by those numbers now
arrives at an unrelated assignment and an unrelated conditional.

That produces two different wrong readings, and the record cannot distinguish
them: that the defect was fixed somewhere else, or that the reporter was
careless. Neither was true. The record was accurate, the fix was complete, and
only the coordinates had moved.

**The codebase already knows this about itself.** Script comments are forbidden
from carrying cross-file line ranges, because the rename and split verbs
renumber the very things a reference points at. Records have the same exposure
and no such rule, and they are worse off in one respect: a stale comment sits
beside the code that invalidated it, where the next reader of that function
trips over it. A stale record sits in another directory and is read months
later by someone who was not there when it moved.

The remedy is not to drop line numbers. They are how a finder communicates
precisely at the moment of discovery, they cost nothing, and a record without
them is harder to act on. It is to **pair every coordinate with something that
survives it** — the function name, the symbol, the rule — so that when the
numbers go stale the record still says what to look for. `render.sh:324` alone
rots; `render.sh:324, the stats blocking rollup's slug pattern` degrades into
a search.

The verification half follows from *A contract names a site; a site is not a
class*, and sharpens it: **a site named only by line number is not a site at
all once the file moves.** So confirm a record against the rule it describes,
never against the coordinates it quotes. Closing the issue above meant
censusing every slug character class in the tree and finding two deliberate
families whose boundary held — one command, and it answered a question the
line numbers could no longer even pose.

Two forces make this bite hardest exactly where it did. A record filed by
research and fixed during the same increment is the shortest-lived set of
coordinates in the project, because the build reshapes the file underneath it.
And a record left open past its fix — the failure above — keeps accruing rot
for as long as it stands.

### Never hand-edit a derived artifact

A table whose header says *derived — do not edit* will be regenerated. Rows added
by hand vanish at the next regeneration, silently, and until then they mask the
missing declaration that would have produced them honestly.

Two contract-graph rows were hand-carried into `BLUEPRINT.md` after a round added
two real cross-group dependencies. The correct move was to add the reciprocal
`Requires` entries to the consumer blueprints; the reconcile then derives the rows
and keeps deriving them. When the graph was next reconciled the hand-added rows
dropped, and the gap surfaced as a dead-surface finding — which is the system
working, one round later than it should have.

**Blueprints and `ARCHITECTURE.md` are edited only through `/jim:blueprint` and
`/jim:arch`.** A surgical hand-edit bypasses the skill's grading, its
present-tense and provenance scans, and its `Last updated` stamp.

## Reviews

### Fan-out is the evidence, not the reading

An author reviewing their own range produced `minor-drift`/5 findings where a
fan-out over identical commits produced `major-drift`/15. The fan-out is not a
speed optimization — it is the independence the verdict rests on. A review whose
coverage section reads clean must mean the investigation happened.

`review_fanout_cap` bounds it. Exceeding the cap needs explicit authorization,
and a capped run must name the un-investigated remainder rather than presenting
partial coverage as complete.

### Adversarial verification, and the value of "refuted as worded"

Spending independent readers on *refuting* a fix — each told to default to
refuted and to produce a reproducing input — pays in two distinct ways, and the
second is the less obvious one.

It finds properties nobody had written down: the sanitizer stage order above was
surfaced by a refuter attacking a claim, not by the author who wrote the pipeline.

And a refutation of the *wording* is worth as much as one of the fix. A claim
that removing a re-sort "changes no ordering" came back refuted — not because the
fix was wrong, but because for the one input that mattered the old code had not
produced a different order at all; it had produced a corrupted array with an
element that had lost its directory prefix. The fix was stronger than its own
rationale claimed, and the comment was corrected to say so. A rationale that
overstates is a future reader's false confidence.

Give each refuter a distinct lens rather than three copies of the same brief;
redundant refuters find redundant things.

### Verify a fanned-out investigator's baseline

Two of four investigators in one review reported their worktree had been
provisioned **1164 commits stale** and reset it before working. All four
confirmed their baseline in-report, and any result that did not confirm its
baseline was not used.

An investigator's report is only as good as what "HEAD" meant to it. Require the
baseline in the report — an unconfirmed one is not a weaker result, it is a
result about unknown code.

### Run the living-intent sensor before the completion gate

One `high`-criticality invariant was contradicted **by design**, in two
blueprints, and nothing forced the fold until the sensor ran — after the gate.

The fold-back loop's value is not the report it writes. It is the contradiction
it refuses to let pass silently, and it can only refuse before the gate closes.

### A verdict is a measurement — amend it when the evidence lands late

The review records `review finished alignment=…` **before** composing
`review.md`, so the artifact can report its own metrics; and the living-intent
sensor runs after that, by design, so its outcomes can never set the verdict.
Those two orderings interact badly on one path: evidence that genuinely bears on
alignment can arrive after the verdict is already on the ledger.

One review recorded `minor-drift` over 31-of-33 criteria and a clean task
breakdown. The sensor then reported a `critical` invariant violated; verifying
that claim by hand showed the build had introduced a regression falsifying both
the script's own security-model header and the `ARCHITECTURE.md` paragraph
refreshed during the same build. That is drift against an alignment ground
truth, found late. The verdict was amended to `major-drift` and both lines stand
on the append-only ledger.

Hold the distinction precisely, because it is the thing that could be abused:
**the sensor's outcome must not move the verdict; evidence surfaced while
verifying that outcome is ordinary evidence and must.** The test is whether the
new fact bears on a ground truth the verdict already answers — spec criteria,
plan tasks, architecture conventions. "An invariant is violated" does not
qualify. "The code contradicts a document this build wrote" does.

Amending is cheap and the trajectory is what the append-only ledger is for.
Rationalizing the first verdict to avoid a second line is the failure — it
produces an artifact that is wrong in the one direction nobody re-reads.

### Convergence is a confidence signal worth recording

When two or three investigators on *different* assignments reach the same defect
by different routes, that finding is confirmed rather than plausible — and worth
marking as such in `review.md`. Three of the sharpest findings in one review were
each reached independently two or three times; each had survived three prior
reviews that found it once or not at all.

### Judge the subject, not the instrumented range

`jimledger.sh files` returns the *build's* change set. Post-build work —
fix passes, remediations, review-remediation rounds — falls outside it. Three
consecutive reviews of one spec judged a tree the instrumentation described at
one-sixth its file count, each recording the gap and working around it by hand.

The same change set drives the living-intent sensor's judge selection, so the gap
has correctness consequences and not merely reporting ones: a remediation
touching a *new* file leaves that file's invariants unjudged while the review
reports clean coverage.

Judge the working tree, and say in `review.md` that you did.

## Mechanics

**The suite** takes ~9 minutes on a quiet VM and exceeds a foreground timeout.
`rm -f /tmp/suite.log` first, then run backgrounded and poll for `^Ran `. Never
run two concurrently — they contend badly, and a 16-second file has taken 5m41s
alongside another run. Do not edit files the suite reads while it runs. **Budget
for far worse under load**: one round's run took 25 minutes, and a single
`index.sh` fired alongside it hit a 2-minute timeout. Plan the wait as work you
do elsewhere, not as a poll loop.

**"Concurrently" includes subagents.** A round ran three adversarial agents
building git fixtures while the suite was in flight and watched throughput
collapse — the same contention, arriving from a direction the rule did not
obviously name. Sequence the fan-out and the suite.

**A fixture must never write through a path the system under test handed back.**
One placement verb returns a *repo-relative* prefix on one of its arms, and a
test process's working directory is the project's own checkout — so
`printf > "$dir/x.md"` landed in the real collection. Three cases did this before
it was caught; nothing was committed, but files appeared in a production
directory. Anchor every fixture write at the fixture's own root
(`"$repo/${OUT#*$'\t'}"`), and treat a returned relative path as a trap rather
than a convenience. It also masked a bug: one of those cases had been passing for
an unrelated reason.

**Load-dependent flakes** wrap work in a fixed `timeout` and can return rc 124
under full-suite contention. Two cases in `tests/jimalloc.sh` have this shape.
Re-run before investigating a 124.

**Filing** writes the body to a temp file with the Write tool first, then calls
the emitter with `--body-file` — never inline an untrusted body into a shell
command. Filings need `--auto` (no human reviewed the batch) or `--reviewed` (one
did); an interactive batch is always the reviewed case. Regenerate `INDEX.md`
**once** after the last filing, not per issue.

**Slugs cap at 64 characters and truncate mid-word.** Keep issue titles short
enough to survive it.

**A filing batch inherits the collection's integrity state.** Filing regenerates
`INDEX.md`, which re-derives every warning from the collection as it currently
stands. With a schema migration pending, that wrote 233 "closed but records no
outcome" lines into a tracked artifact — noise that had nothing to do with the
issues being filed, and that vanished the moment the conversion ran. Sequence a
pending data migration **before** a filing batch, or the batch's own commit
carries the migration's backlog. The same reasoning applies to any operator
action that regenerates a derived artifact: it publishes whatever is true at
that moment, not whatever the action was about.

**Config path keys are `<key>_path` in TOML.** `brainstorms_path`, `specs_path`,
`issues_path` — the bare names are for the behavior knobs (`issue_placement`,
`auto_review`). The CLI takes the short name and the resolver appends the suffix,
so a fixture writing the bare name for a path key gets **the default, silently**.
That is a case passing for the wrong reason with no error anywhere: the run does
exactly what it would have without the config line. Assert the resolver's answer
(`jimconf.sh get <key>`) when a fixture's whole point is a non-default root.

The same suffix defeats a *sweep* the other way round. A check comparing
`jimconf.sh keys` against a documentation table reports every path key as
undocumented — ten false alarms indistinguishable from real ones, and they read
as "README is missing ten keys" until you go and look at the resolver. A
roster sweep has to accept both spellings. It also has to accept a family row: a
table may legitimately document five keys in one line (`health_threshold_<signal>`
naming each signal in its text), which is the better document and invisible to a
check demanding a row each. Read family prefixes out of the document rather than
splitting the key — two of those five carry an underscore in their own suffix.

**Commit subjects** are ≤50 characters, lowercase, imperative, with IDs in
trailers only. This one is honoured in the breach — 74 of 140 subjects in one
spec's range exceed it — which is worth knowing before you assume the corpus is
the standard.

**A commit's type must match its content.** A behavioral change never ships under
`docs` or `test`. One range carried three that did: a `docs` commit that changed
script runtime behavior, a `test` commit that added a load-bearing arm to a
production function and fixed a real variable clobber, and a `docs(arch)` commit
that silently carried three sweep fixes. Mistyped commits are invisible to
anyone reading the log to find where behavior changed — and rewriting them later
is not an option, so the discipline has to hold at commit time.

**Pointing `/jim:review` at a spec directory has two preconditions.** Its
`review.md` must not already be the `origin:` anchor for tracked issues (the run
overwrites it, orphaning their provenance), and the target ledger's recorded
`head_sha` must actually match the range you mean to review — one recorded a
`head_sha` that was an *ancestor* of the intended range's start, so the run would
have diffed the wrong code entirely. Either failure means running the review as a
freestanding pass instead.

**The ledger's write path is unvalidated; its two read paths disagree about what
they show.** `cmd_event` joins its `k=v` arguments with `;` and appends — no key
allowlist, no shape check, no sanitizer. So a new counter key needs no script
change to be *written*. What it does next depends on which reader sees it:
`events` re-emits the field verbatim, so the key **displays**; `metrics` iterates
a fixed code-literal stage list (`LEDGER_STAGES`) and never reads that field, so
the key is **silently invisible**. Adding a counter and confirming it in `events`
therefore proves nothing about `metrics`. Neither the script nor the platform
blueprint records this — the blueprint states the fixed-key `metrics` guarantee
and not the asymmetry behind it.

**Realize assigns ordinals in glob order, not filing order.** `scan_pending`
enumerates `P-*` directories with a shell glob, so the sort key is the
provisional token: chronological across days, and **alphabetical by slug within
one day's batch**. Two specs filed an hour apart on the same date get their
ordinals by title, not by when they were filed.

**Bash and tooling traps that cost real time:**

- `local a=1 b="$a"` does not work. `local` expands every argument before
  assigning any, so `b` sees an unbound `a` under `set -u`. Split the statement.
- `assert_eq` is the only equality helper — there is no `assert_ne` or
  `assert_contains`. The house idiom for absence is
  `assert_eq "label" "0" "$(… | grep -c …)"`.
- `assert_match` is ERE, so `(foo)` is a capture group, not literal parens. A
  pattern like `… (truncated)` silently matches `… truncated`.
- `grep -rn … .` omits the `./` prefix, so a path filter anchored on `^\./docs/…`
  matches nothing and looks like a filter with nothing to exclude.
- `grep -o` with wide context on `ARCHITECTURE.md` gets OOM-killed. Use `awk`
  with `split()`, or `sed -n` by line number.
- `skills/issue/scripts/index.sh` is repo-root-relative and fails after a `cd`
  into the collection in the same compound command. Run it as its own step.

## Environment

The coordination remote is unreachable from the sandbox VM, so every filing
returns a `P-` provisional ordinal. This is the designed degradation, not a
failure. The host realizes them with `reconcile.sh --apply`; until then the
issue's identity is structurally distinct but already spent — the allocator is
append-only, so a refusal *after* allocation burns an ordinal no later run can
reclaim.

That last property is worth checking whenever a script gains a new refusal: does
it fire before or after identity is spent?
