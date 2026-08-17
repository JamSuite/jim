---
id: 20260805-close-the-fork-amplification-class-at-readability-instead-of-rec
num: 235
title: "Close the fork-amplification class at readability instead of record kind"
status: open
priority: high
labels: [id-coordination, alloc, security, performance]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:11Z
updated: 2026-08-05T22:20:11Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

The memo scoping fix narrows the fork-amplification surface but does not close the
class.

The pre-fix vulnerability was real and larger than filed — measured against a
seeded registry with adversarial records on the push-writable coordination branch:

```
600 x "issue allocate" rows in specs.log   ->  606 forks,  39.05 s   (baseline 6 forks, 1.58 s)
1000 x "spec realize" rows in issues.log   -> 3006 forks, 288.26 s
```

The fix narrows by *record kind*. The exploitable property is *readability*.
`alloc_valid_specid` returns 1 on an id with no `/` before touching the boundary,
so a slug in such a record is unreachable to every consumer — and the warmer
crosses it anyway:

```
600 x "spec allocate notanid evilslugNNNNNN 20260802 mallory" in specs.log
  HEAD          : 607 forks, 101.50 s      <- 30x amplification
  warm stripped :  20 forks,   5.89 s
  tokens actually read by any consumer: 0
```

Same on the issues log. 0.165 s of serialized subprocess per crafted record,
inside the read-only `sweep`, linear and unbounded: a ~400 KB push is roughly 27
minutes per sweep, per clone. The docstring at `:198-213` states the correct rule
("crossing a token no consumer will ever read spends one subprocess per distinct
token"); the implementation at `:214-238` approximates it as `kind not in log`,
which is a strict subset.

Two related gaps in the same family:

- The warming rule is applied at 3 of 9 dispatch verbs. Six unwarmed verbs show
  72-91% repeat waste (`resolve spec` 53 forks / 5 distinct). The naive fix is
  wrong and was measured: warming `resolve` made it *slower* on jim's registry
  shape (53 -> 70 forks), because the warm wins only when distinct log tokens are
  fewer than the repeats saved. The structural fix is the 13 sites that call
  `alloc_canon_specid` inside a command substitution and discard the memo write:
  `:493, 647, 696, 955, 1249, 1685, 1746, 3174, 3451, 3453, 3857, 3865, 3871`.
- "An unrecognised scope ... fails loudly" is inaccurate. `:216-219` does a bare
  `return 1` with nothing on stderr under `set -uo pipefail`, and none of the five
  call sites checks the return value.

## Proposed action

Gate the warm on *readability*, not kind: skip a token the boundary would reject
for structural reasons the consumer also rejects, or cap the work a single log can
induce. Then fixture a malformed-but-right-kind record and assert the crossing
count does not scale with it.

Separately: make the unrecognised-scope path emit on stderr, and fix the memo
discard at the 13 command-substitution sites rather than adding warms.
