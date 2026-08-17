---
id: 20260713-align-nothing-to-reconcile-face-counters-with-ledger-int-typing
num: 76
title: "Align nothing-to-reconcile face counters with ledger int-typing"
status: open
priority: medium
labels: [reconcile, ledger]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-13T07:15:20Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/017-reconcile-face-counters/review.md
---

## Description

## Observation

The reconcile pass's "nothing-to-reconcile" short-circuit (fewer than two
blueprint-bearing groups) does not run blueprint § Reconcile Step 2a, which is
full-run-only. Spec 044 and spec 045 both note in their Out-of-Scope sections
that on this path the four face counters "ride as `na`". However, `jimledger.sh`
types `faces` and `faces_max` as **int** (`RECONCILE_INT_KEYS`), accepting only
`^[0-9]+$` — not int-or-na. Only the four graph-health counters
(`groups`/`cycles`/`fanin`/`uncovered`) carry the int-or-na carve-out
(`RECONCILE_NA_KEYS`).

`reconcile-methodology.md` § Outcome counters compounds the ambiguity: it states
`faces`/`faces_max` are "always non-negative integers", which contradicts the
"ride as `na`" note.

## Impact (potential)

If a short-circuit `blueprint finished` event actually emits `faces=na` /
`faces_max=na`, the shared `RECONCILE_AWK` validator (`MODE=last`/`series`) would
treat it as a documented key with a bad value and exclude the whole event as
malformed — so a short-circuit reconcile would drop out of `last-reconcile` /
`reconcile-series`. Not observed at runtime here (the emitted value is decided by
the skill at execution time); this is a static contradiction between the docs,
the whitelist typing, and the Out-of-Scope notes.

## Provenance

Pre-existing — introduced with the spec-044 face counters and the short-circuit
handling; spec 045 explicitly left the short-circuit path unchanged. Surfaced by
the spec-045 post-build review's living-intent sensor (the
`reconcile-durable-record` judge); see that spec's `review.md` § Living intent.

## Proposed action

Decide the intended short-circuit contract and make the three sources agree:

1. What the short-circuit actually emits for
   `faces`/`faces_max`/`faces_max_group`/`fanin_group` (blueprint SKILL.md
   § Reconcile Step 3).
2. The `jimledger.sh` whitelist typing — either add the face keys to the na
   carve-out, or keep them int and forbid `na` on the short-circuit.
3. The `reconcile-methodology.md` § Outcome counters wording and the spec
   044/045 Out-of-Scope notes.
