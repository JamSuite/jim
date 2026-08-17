---
id: 20260803-decide-the-duplicate-realize-rule-once-across-its-three-readers
num: 214
title: "Decide the duplicate-realize rule once across its three readers"
status: closed
priority: medium
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:14Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

`alloc_realize_scan`'s three consumers apply three different rules to a
duplicated realize key, and none of them refuses it — which is what every other
duplicate-claim shape in `jimalloc.sh` does.

- `alloc_resolve_spec` (`jimalloc.sh:503-506`) takes the **first** record.
- The lift's `rz_of` takes the **last**.
- `alloc_lift_state` calls the same shape `refused:source-conflict`.

The resolver's first-wins direction is fail-safe — a crafted record appended
after a genuine one is inert — but the review established it is **accidental**,
a consequence of comparing against the variable the loop mutates rather than a
decision anyone took. It is also silent, where every other duplicate-claim shape
in this file is refused with both record positions named, and where the sweep
carries a `duplicate-realize-keys` hazard class precisely because the
contradiction is worth reporting.

This is the class `platform/012` paid two criticals for, and the practice the
emission spec was otherwise built around: one rule per structure, decided in one
place. The *claim* replay was extracted for exactly this reason. The realize
replay was not.

## Proposed action

Decide the rule once — refuse, or first-wins stated deliberately in the record
layer's contract — and make all three readers consume that decision. If
first-wins stays, it needs a fixture that fails when the comparison flips;
today nothing would notice.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 7). Settled by execution rather than by reading — two investigators
reasoned to opposite directions. Not filed alongside that review's other
follow-ons.

## Resolution (2026-08-05)

The rule is decided once, in the record layer. `alloc_realize_fold` holds the
single duplicate-realize decision: a duplicate naming the same ordinal is
idempotent, and two records naming different ordinals are a contradiction
refused with both record positions named. First-wins is now deliberate and
documented rather than an artifact of comparing against a mutated loop variable.

All three former readers consume it. `rz_of` no longer exists anywhere in the
tree, and the consumer enumeration is exhaustive by grep: the fold has exactly
two production callers, and the only other reader of `alloc_realize_scan` is the
non-coverage counter, which applies no duplicate rule. `alloc_lift_state` reads
only the arrays the fold fills.

The fixture this issue asked for exists and was mutation-proven: flipping the
fold to last-wins turns it red, restoring it turns it green. Contradiction
refusal and idempotent duplicates were both verified by running the real verbs
against fixture registries, not by reading.

Residual, tracked separately: the realize *writer* never consults the fold, so a
lift-then-reconcile sequence can still mint a contradiction.
