# Process improvements

Craft that has earned its place across jim's build/fix/review rounds. Each rule
carries the evidence that produced it — a rule without a scar is a preference,
and the next author needs to know which is which.

This is the transferable half of what session handoff notes carry. Handoffs are
disposable and spec-scoped; this file is neither.

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

**Config path keys are `<key>_path` in TOML.** `brainstorms_path`, `specs_path`,
`issues_path` — the bare names are for the behavior knobs (`issue_placement`,
`auto_review`). The CLI takes the short name and the resolver appends the suffix,
so a fixture writing the bare name for a path key gets **the default, silently**.
That is a case passing for the wrong reason with no error anywhere: the run does
exactly what it would have without the config line. Assert the resolver's answer
(`jimconf.sh get <key>`) when a fixture's whole point is a non-default root.

**Commit subjects** are ≤50 characters, lowercase, imperative, with IDs in
trailers only. This one is honoured in the breach — 74 of 140 subjects in one
spec's range exceed it — which is worth knowing before you assume the corpus is
the standard.

## Environment

The coordination remote is unreachable from the sandbox VM, so every filing
returns a `P-` provisional ordinal. This is the designed degradation, not a
failure. The host realizes them with `reconcile.sh --apply`; until then the
issue's identity is structurally distinct but already spent — the allocator is
append-only, so a refusal *after* allocation burns an ordinal no later run can
reclaim.

That last property is worth checking whenever a script gains a new refusal: does
it fire before or after identity is spent?
