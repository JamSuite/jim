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

### A case that cannot go red is a finding

If removing the shipped guard leaves the case green, the case is pinning
something else — usually a guard earlier in the same function, or a rejected
alternative that was never built. Fold it into the case that does go red rather
than leaving it standing. A standing case that cannot fail is worse than no case:
it reports coverage that does not exist.

Four such cases survived into the fourth review of `issue/011`, one of them the
only thing protecting an acceptance criterion's installed-base guarantee.

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

## Organizing a fix pass

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

**The suite** takes ~9 minutes and exceeds a foreground timeout. `rm -f
/tmp/suite.log` first, then run backgrounded and poll for `^Ran `. Never run two
concurrently — they contend badly, and a 16-second file has taken 5m41s alongside
another run. Do not edit files the suite reads while it runs.

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
