---
id: 20260803-stop-double-counting-a-group-realize-across-two-non-coverage-cou
num: 219
title: "Stop double-counting a group realize across two non-coverage counters"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-03T05:50:28Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

`alloc_malformed_count`'s selector admits `spec:group`:

```
case "$want:$c1" in
  spec:spec|spec:group|group:group|issue:issue) all=$((all + 1)) ;;
esac
```

while `alloc_realize_scan` requires `c1 == spec`. So a `group realize …` line
counts toward `all` on the spec pass and never toward `good`, landing in
`unidentifiable-records` — and the review traced it also incrementing
`unknown-verb-records`, since `realize` has no group form.

One crafted line therefore appears in two of the sweep's non-coverage numbers,
contradicting the comment that says the two are reported apart on purpose. The
sweep's value is that its numbers reconcile against a record count; a line
counted twice makes the report ambiguous about how many records are actually
unreadable, which is the one question that report exists to answer.

The selector is correct for `rename`, where both `spec rename` and
`group rename` are real records. It is wrong for `realize`, which has only a
spec form.

## Proposed action

Make the selector verb-aware, or restrict the realize arm to `spec:spec`.
Fixture a `group realize` line and assert it lands in exactly one counter.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 19). Not filed alongside that review's other follow-ons.

## Resolution (2026-08-05)

`alloc_malformed_count` consults `alloc_known_verbs` before counting, so a
`group realize` record lands in the unknown-verb counter alone rather than in
both it and the unidentifiable counter.

Verified exhaustively rather than by sampling: seven known verb pairs x three
shapes (well-formed, field-short, field-long) plus six unknown pairs, run through
both classifiers and the unknown-verb counter, diffed pre-fix against HEAD. The
diff is exactly one row — `group realize` going from two counters to one.
Nothing else moved, and no verb dropped from one counter to zero as a side
effect. `alloc_known_verbs` was cross-checked against the encoders and is
complete. The fixture discriminates in both directions: deleting the gate,
neutering it, adding a bogus pair, or dropping a real pair each turns it red.

Adjacent finding, pre-existing and out of scope: `group allocate` lands in *zero*
counters, so a degraded group-allocate record is invisible to the sweep's
reconciliation while the `spec`/`issue` equivalents surface as `UNREADABLE`
drift.
