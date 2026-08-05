---
id: 20260805-read-the-spent-set-the-lift-already-fills
num: P-20260805-read-the-spent-set-the-lift-already-fills
title: "Read the spent set the lift already fills"
status: open
priority: medium
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T09:50:23Z
updated: 2026-08-05T09:50:23Z
origin: docs/notes/20260728-id-coordination-issue-grouping.md
---

## Description

`alloc_lift_states:3673` declares `spent` and `:3674` fills it via
`alloc_live_claim_set`. Nothing then reads it — the only two `${spent[...]}`
reads in the whole file are `:3356` and `:3434`, both inside `partition-batch`'s
builders.

The lift is protected today only as a side effect of a different rule. A vacated
ordinal carries no live claim, so `alloc_lift_state:3637` refuses it as
`destination-not-established`: the right outcome for the wrong reason, and one
that stops protecting the moment that gate moves, is reordered, or has its
condition narrowed.

The same shape was corrected once already in this cluster. Issue 209's resolution
records the lift's reserved-ordinal gate being added precisely because it had
been "safe only by the `destination-not-established` side effect", and the same
note's residual states plainly that the lift declares the spent set and never
reads it. The residual was recorded and not acted on.

Not presently exploitable, which is why this is hardening rather than a defect.
But it is the fourth door of the never-reissue rule, and a rule is only as strong
as the door that does not enforce it by name.

## Proposed action

Read `spent` in `alloc_lift_state`'s spec and realize arms, with the refusal
vocabulary `partition-batch` already uses at `:3356`, so the rule is enforced
where it applies rather than inherited from a neighbouring gate. Give it a
distinct state — `refused:destination-vacated` — so the decision table records
which rule fired rather than collapsing two causes into one message.

Fixture: a lift whose destination ordinal was vacated by an earlier rename;
assert the refusal names the vacating and that no record is appended. Then
mutation-test it by deleting the `destination-not-established` gate — the case
must stay red, which is the assertion that distinguishes enforcing the rule from
inheriting it.

## Provenance

The evidence pass that settled B″'s two pre-code forks
(`docs/notes/20260728-id-coordination-issue-grouping.md`, Sequence step 7).
Surfaced by enumerating the never-reissue rule's doors rather than the filed
issue's — the first of two cells the vacated-ordinal issue does not name.
