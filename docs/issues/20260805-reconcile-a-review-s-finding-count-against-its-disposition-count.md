---
id: 20260805-reconcile-a-review-s-finding-count-against-its-disposition-count
num: P-20260805-reconcile-a-review-s-finding-count-against-its-disposition-count
title: "Reconcile a review's finding count against its disposition count"
status: open
priority: high
labels: [sdlc, review, ledger]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T12:01:51Z
updated: 2026-08-05T12:01:51Z
origin: docs/notes/20260728-id-coordination-issue-grouping.md
---

## Description

A review records its findings. The issues record themselves. **No third thing
says every finding has a disposition** — so a finding can be neither fixed nor
deliberately left, and nothing anywhere notices.

Measured, twice:

- Spec B's review reported **20** findings; its filing pass produced **9**
  issues. Six of the eleven remaining were simply lost.
- The same range shipped a spec that closed **none** of the issues it fixed —
  recorded once as item 7 of *What C′ changed* ("the build did not close the
  issues it fixed"), then repeated seven issues' worth.

This is the sibling of the practice that says coverage of a result is not
visible in the result — but with a property none of its neighbours have: **the
check is arithmetic.** A count against a count, at a gate, with no judgment in
the loop. The ledger already stores `findings=<n>`; what is missing is the
obligation that `<n>` dispositions exist.

C′-fix's review actually did this — "five fixed, seven filed, six left" — but in
prose, in a handoff note, by hand. A lesson recorded in a working note has no
mechanism behind it.

## Proposed action

Make the disposition a counted obligation of the review artifact rather than a
convention.

- Each finding carries exactly one disposition: **fixed** (with the commit),
  **filed** (with the issue id), or **left** (with a reason). "Left" is a first
  class outcome — the goal is that nothing is lost, not that everything is done.
- `/jim:review`'s completion reconciles the two counts and refuses to report
  clean when they disagree, naming the shortfall the way every other degradation
  in that skill is named.
- Carry the reconciliation onto the `review finished` event, so the arithmetic
  survives the conversation. `cmd_event` joins `k=v` tokens with no allowlist, so
  a counter needs no script change; note that the `metrics` channel iterates a
  fixed key set and will not surface a new key without a deliberate extension,
  and a test pins that boundary.

The sibling half is the same shape and worth settling together: a build that
fixes an issue should close it, and a spec that ships should be able to say which
issues it closed. That is countable from the same two sources.

## Scope note

This is a change to the review surface, not to the id-coordination machinery it
was discovered in. It wants its own pass — it touches `/jim:review`'s skill body,
its template, and its ledger event, and the "left" disposition needs a decision
about how much reason is enough.

## Provenance

Adopted practice 10 in `docs/notes/20260728-id-coordination-issue-grouping.md`,
argued for adoption by the thirteenth revision and scheduled for filing in the
B-double-prime pass. The two measurements above are from that note.
