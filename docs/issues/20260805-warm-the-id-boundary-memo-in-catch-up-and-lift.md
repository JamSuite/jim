---
id: 20260805-warm-the-id-boundary-memo-in-catch-up-and-lift
num: 234
title: "Warm the id-boundary memo in catch-up and lift"
status: closed
priority: medium
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:44Z
updated: 2026-08-05T10:21:33Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

`alloc_warm_token_memo` has exactly two call sites, both in `cmd_sweep`
(`:2890`, `:2891`). The sibling hot paths re-derive the same tokens over the same
logs and pay the entire pre-fix cost.

Measured on a full copy of the live registry (65 specs, 219 issues), counting
`jimfile.sh valid-id` forks:

| verb | forks | distinct | repeats | wall |
| :--- | ---: | ---: | ---: | :--- |
| `sweep` (HEAD) | 291 | 291 | 0 | 13–14 s |
| **`catch-up` preview** | **815** | 291 | **524** | 27–69 s |
| **`lift` preview** | **564** | 72 | **492 (87% waste)** | 10.7–11.6 s |
| `seed` | 289 | 289 | 0 | — |
| `reconcile spec` (empty stdin) | 0 | 0 | 0 | — |

`catch-up` re-runs the same classifiers over the same logs, so it now pays the
sweep's *entire* pre-fix cost un-warmed — **it is slower than the sweep it exists
to fix**. `lift`'s waste ratio is the worst of the three: 87% of its crossings are
repeats of 72 distinct tokens.

Issue #218 was scoped to the sweep, so this is outside its letter and squarely in
its class. Neither the issue nor the completion handoff mentions the sibling
paths.

Note the warmer must be fed by here-string, not pipe — a pipe silently makes it a
no-op by running it in a subshell. `cmd_sweep` gets this right at `:2890-2891`;
any new call site needs the same form.

Fix the fork-amplification bug first (filed separately) — warming more paths with
the current cross-kind case list would widen that surface rather than narrow it.

## Proposed action

Hoist the warm into `cmd_catchup` and `cmd_lift` with the same here-string form
`cmd_sweep` uses, after the case-list scoping fix lands.

Extend the crossing-count fixture to cover at least one non-sweep verb, so a new
entry point that forgets to warm is visible.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 6). Third appearance of
`catch-up` as the door an id-coordination fix skipped.

## Resolution (2026-08-05)

Fixed as proposed, after the fork-amplification fix this issue said to land
first. Both `cmd_catchup` and `cmd_lift` warm the memo in their own shell before
anything below them captures into a subshell, and both feed the warmer by
here-string — the pipe form this issue warned about is now pinned by a mutation
that turns the case red.

The fork-probe harness the sweep's crossing-count case carried inline is now a
shared helper, and the "no token crosses the boundary twice" invariant is
asserted for all three verbs rather than only the one it was written for. That
is the point of the issue restated as a test: an entry point that forgets to warm
is visible, instead of being outside the letter of the item that introduced the
memo.
