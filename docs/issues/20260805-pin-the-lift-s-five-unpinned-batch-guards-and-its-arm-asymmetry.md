---
id: 20260805-pin-the-lift-s-five-unpinned-batch-guards-and-its-arm-asymmetry
num: 225
title: "Pin the lift's five unpinned batch guards and its arm asymmetry"
status: closed
priority: medium
labels: [id-coordination, registry, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:43Z
updated: 2026-08-05T10:21:33Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

`alloc_lift_state`'s behavior is correct — the cross-run idempotency hole is
closed, a reorder attack is repelled, and preview/payload/published are one
computation. But five of the nine guards that make it correct survive deletion
with the entire 1137-test suite green.

Mutation audit, each guard deleted in isolation and the full suite run:

| deleted guard | failing tests |
| :--- | ---: |
| `rn_dst[spec]` — cross-run destination closure | 1 |
| in-batch guard `:3761-3768` | 4 |
| `batch_src` / `batch_dst` from `:3762` | 2 / 1 |
| **`rn_src[spec]` — cross-run *source* closure** | **0 of 1137** |
| **`rz_dst` — realize destination closure** | **0 of 1137** |
| **`rn_src[group]`** | **0 of 1137** |
| **`rn_dst[group]`** | **0 of 305** |
| **first-recordable-wins ordering (reverse the row scan)** | **0 of 18 lift cases** |

`refused:destination-conflict` is emitted from three sites (`:3620`, `:3635`,
`:3649`) and asserted **nowhere** in `tests/`. Independently confirmed by
enumerating every refusal string the suite asserts: `source-claimed`,
`duplicate-in-batch`, `source-conflict`, `reserved-ordinal`, `unknown-event`,
`destination-not-established`.

The ordering mutation is the sharpest: invert first-recordable-wins and the build
records the *wrong* row of a duplicate pair, and every lift fixture still passes.

Issue #207's contract asked that "a destination **(or source)** already claimed by
an earlier record in this same batch is refused on **every run**". The destination
half is pinned cross-run; the source half is not.

There is no runtime defect here today. The cost is that the next refactor of
`alloc_lift_state` can silently remove a guard and stay green — reintroducing
exactly the defect that took a major-drift review to find.

## Proposed action

Add cases asserting `refused:destination-conflict` on each of the three arms, the
cross-run source closure, and the realize destination closure. Add an ordering
case that pins *which* row of a duplicate pair is published, not merely that one
is refused.

Separately: the **spec** arm never checks `rn_src[spec\t$dst]` — a destination
that itself renamed away — which the **group** arm does check at `:3648` and whose
rule the group arm's own comment states. Safe today only via the `live[$dst]`
gate, which is the same "safe by the `destination-not-established` side effect"
pattern #209 identified and fixed one line below. Filed here rather than
separately because both belong to the same arm-symmetry pass.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 5).

## Resolution (2026-08-05)

Every guard the mutation audit found surviving now has a case, and the audit was
re-run to confirm each one discriminates.

- `refused:destination-conflict` was emitted from three arms and asserted from
  none. One case covers all three; a second covers the group arm's **other**
  direction, because the two halves of that check (a destination another rename
  arrived at, versus one that itself renamed away) each leave the other's case
  green when deleted.
- The cross-run **source** closure — the half of issue 207's contract that was
  never pinned — has its own case.
- The realize destination closure has its own case.
- **The ordering contract is pinned by outcome, not by count.** The case asserts
  *which* row of a duplicate pair is emitted and which is marked, so inverting
  first-recordable-wins fails rather than passing on "one of them was refused".

**The arm asymmetry resolved differently than the issue proposed.** Adding
`rn_src[spec\t$dst]` to the spec arm would be dead code: `spent` holds every SRC
row the replay produces, so it is a strict superset of the spec renames `rn_src`
indexes — and it also covers ordinals a *group* rename moved, which
`rn_src[spec…]` never sees. The rule is enforced, by the broader predicate. The
group arm reaches for `rn_src` only because it has no spent set keyed by group
name. That reasoning is now recorded at the site, so the redundant check is not
added back.

Seven mutations, all red.
