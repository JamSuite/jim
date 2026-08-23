---
id: 20260813-a-review-finding-does-not-carry-the-scope-it-was-derived-from
num: 344
title: "A review finding does not carry the scope it was derived from"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [sdlc, review, coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-13T11:01:06Z
updated: 2026-08-13T11:01:06Z
origin: "20260728-id-coordination-issue-grouping.md (retired; see 5e712bf)"
---

## Description

## Description

A review finding states a scope — "nine references under `agents/`" — and the
next reader inherits it. That scope is a claim about where the reviewer looked,
not a measurement of where the rule applies, and nothing in the artifact
distinguishes the two.

This has paid out at least three times. The sharpest instance: a finding whose
*entire subject* was "fixed one site, missed the sibling" stated its own scope as
nine references, and a wider sweep found four more on live skill surfaces. The
pass that catches an incomplete sweep swept incompletely, and reported a count
that read as exhaustive.

The general form is recorded in `docs/notes/process-improvements.md` (*A clean
result does not disclose its own coverage*). The mechanical half is not built,
and the cluster note that first named it said so explicitly: **"Not yet
tracked."** It has stayed untracked since.

## Action

Make a finding carry the scope it was derived from, so the next reader can
re-derive rather than inherit — the same shape as the fan-out disclosure already
built for a suppressed delegation, where the run names the degradation it can
see instead of reporting a clean result.

Concretely: a finding that rests on an enumeration should record what was
enumerated (the command, the corpus, or the derivation), and a reader acting on
it should re-run that rather than trusting the count. Where the scope is
unrecoverable from the artifact, the artifact is incomplete and should say so.

This is a `/jim:review` surface change, not a bug fix — it changes what a finding
is obliged to carry.
