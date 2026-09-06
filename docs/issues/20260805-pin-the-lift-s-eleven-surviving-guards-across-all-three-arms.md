---
id: 20260805-pin-the-lift-s-eleven-surviving-guards-across-all-three-arms
num: 241
title: "Pin the lift's eleven surviving guards across all three arms"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [id-coordination, alloc, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:26Z
updated: 2026-08-05T22:20:26Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

The lift's guard corpus is one arm wide.

Issue 225 counted nine guards and named five; all five discriminate, each failing
exactly one case. Independent enumeration of `alloc_lift_state` (`jimalloc.sh:3738-3811`)
and `alloc_lift_states` (`:3820-3921`) finds **28** guards, of which **11 survive
the entire suite** under a deletion-style mutation.

The shape is systematic — every refusal class is asserted on the spec arm and no
other:

| refusal | realize | spec | group |
| :--- | :--- | :--- | :--- |
| `destination-conflict` | pinned | pinned | pinned (the class 225 fixed) |
| `destination-not-established` | BLIND `:3758` | pinned | BLIND `:3797` |
| `source-conflict` | BLIND `:3749` | pinned | BLIND `:3788` |
| `source-claimed` | n/a | pinned | BLIND `:3805` |
| `unrepresentable` (src) | BLIND `:3857` | pinned | BLIND `:3879` |
| `self-rename` | n/a | BLIND `:3761` | BLIND `:3786` |
| `have` | BLIND `:3748` | pinned | pinned |

These are not dead branches. Each was proven load-bearing by deleting it and
observing the outcome change from a refusal to `emit`:

```
G5  group destination the registry never established
    HEAD          : group core nowhere ... refused:destination-not-established
    guard deleted : group core nowhere ... emit
B2  realize source not a valid provisional id
    HEAD          : realize EVIL/../not-a-prov core/001 ... refused:unrepresentable
    guard deleted : realize EVIL/../not-a-prov core/001 ... emit
```

`destination-not-established` on the group and realize arms is the corroboration
gate itself — what the function's own header calls "what makes the ledger a
witness rather than an instruction" — and the ledger is content anyone who can
commit can write. The source-token validators are what keep an `EVIL/../x`-shaped
token out of an appended record.

Two further holes in the same family:

- No fixture exercises a **live-and-spent** destination, so a mutant restoring
  exactly the pre-fix semantics (`spent[$dst] && ! live[$dst]`) passes all 323
  cases.
- The entire **issue-side** vacated-ordinal arm (`:1882-1888`, and `SPENT-TREE` in
  `blocked_issue:3157`) has no test. The shipped code is correct — verified end to
  end — but nothing pins it.

Separately, one of the six cases added to close the batch discriminates nothing:
`case_jimalloc_lift_refuses_a_redirected_spec_destination` (`tests/jimalloc.sh:4050`)
asserts an alternation `refused:(destination-conflict|destination-vacated)$` of
which only the second branch ever fires, over the same log as its neighbour. No
mutation in a 30-mutation sweep turns only it red.

## Proposed action

Pin the eleven surviving guards, prioritising the five that change an outcome from
refusal to emission on ledger-derived input: the group and realize
`destination-not-established`, both source-token validators, and group
`source-claimed`.

Add the two missing corpus cases — a live-and-spent destination, and the
issue-side vacated-ordinal arm.

Replace the alternation in the redirected-spec-destination case with the single
outcome that actually fires, or delete it as a duplicate of its neighbour.
