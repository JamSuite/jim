---
id: 20260813-nine-review-findings-that-were-never-filed
num: 347
title: "Nine review findings that were never filed"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [review, records, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-13T11:00:48Z
updated: 2026-08-13T11:00:48Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

The B″ post-build review produced 25 findings. Sixteen were filed as tracked
issues. The rest were left in the review note, which is disposable — so they
were about to be lost when it is deleted. Recorded here rather than as eight
separate issues, since none blocks anything and several are one edit.

**Findings 20, 21 — documentation drift beyond what the stale-sites issue
covers.** The "3-digit ordinal" claim false at five sites; "per-script test
files only" false on two surfaces plus a counterexample the same build added;
a project-structure tree omitting eight test files, eight skill directories and
two agents; nine of twelve line-range claims wrong; a `README.md` description of
`catch-up` falsified by that review's own finding 7. Two closed issues' `##
Resolution` sections still say a blueprint sentence "rides the docs pass" after
the docs pass rewrote both, with no commit trailer tying either to it.

**Finding 22 — a third verbatim copy of `display_field`** created with no
byte-identical pin, in a repo whose established convention for exactly this is a
single-source helper plus a triplicate-identical test case.

**Finding 23 — dead code shipped.** `alloc_class_label`'s `RENAME-SRC →
vacated-ordinal` arm is unreachable from either caller.

**Finding 24 — one of the six cases added to close the fixture-blindness batch
discriminates nothing** — documentation shaped like a test, in the batch whose
entire purpose was eliminating that.

**Finding 18 — the review's own recounts were wrong**: "20 commits" against an
actual 19; a suite delta stated as 1148 → 1182 against an actual baseline of
1140.

**Finding 15 — the review broke the rule it was applying.** Its disposition
table reads "Twelve findings, twelve dispositions, no remainder" over rows
summing to fourteen, with at least five of eleven distinct findings carrying two
dispositions against the stated one-per-finding rule. The general mechanism is
tracked separately; what is recorded nowhere is that the pass anticipating this
failure mode then committed it.

**From the B′ review, F12 — convention breaches**: an AC id in a commit header
rather than a trailer; one hand-authored commit with no `Issue:` trailer; six
subjects over 50 characters; a non-POSIX `seq` in a test; one of 39 new `case_*`
functions carrying the canonical `# AC:` header.

## Action

Triage. Findings 22 and 23 are code and worth taking. 20 and 21 belong with the
existing documentation-drift work. 15, 18 and F12 are records hygiene — worth
keeping visible precisely because they are the failures that a review of a
review found, and that class has now recurred across three passes.

Verify before acting: these were read out of a review note written 2026-08-05
and not re-derived against the current tree. Each claim is a hypothesis until
reproduced, which is the rule that same review argued for.
