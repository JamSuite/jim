---
id: 20260803-decide-the-duplicate-realize-rule-once-across-its-three-readers
num: P-20260803-decide-the-duplicate-realize-rule-once-across-its-three-readers
title: "Decide the duplicate-realize rule once across its three readers"
status: open
priority: medium
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:14Z
updated: 2026-08-03T05:50:14Z
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
