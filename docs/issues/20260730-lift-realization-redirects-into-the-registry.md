---
id: 20260730-lift-realization-redirects-into-the-registry
num: 143
title: "Lift realization redirects into the registry"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T06:45:19Z
updated: 2026-08-03T05:46:40Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/spec.md
---

## Description

`sdlc/017` (coordinated spec identity) realizes provisional specs into real
ordinals and records each provisional→real mapping as a durable ledger
redirect — deliberately mirroring the partition operations' `moved=`
durable-record pattern — while emitting no registry record, because redirect
emission is the rename-emitting follow-on's charter.

This issue is the lift: when the rename-emitting work lands, realization
mappings recorded on the ledger should become registry redirect records, so a
commit trailer frozen while a spec was provisional
(`Spec: <group>/P-<date>-<slug>`) dereferences through the registry like any
renamed id.

Two things make this more than a data copy:

- **The frozen record grammar cannot express a provisional source.**
  `spec rename <old> <new> <date>` requires `<group>/<NNN>` on both sides
  (the spec-id validator demands an all-digits ordinal), while a provisional
  identity's ordinal slot carries the reserved `P-` prefix — grammar-distinct
  by design. Emitting the lift means deciding the grammar question: extend
  the rename-source token class, add a distinct record verb, or rule the case
  out deliberately.
- **The fold must not count a lifted provisional source.** The shared
  high-water counts rename sources so vacated ordinals stay permanently
  gapped; a provisional source never held a real ordinal, so a lifted record
  must never raise any group's high-water. Grammar-distinctness should make
  this automatic — worth an explicit fixture rather than an assumption.
- **The recorded mapping is untrusted input.** The specs-root ledger is
  ordinary branch content, writable by anyone who can push a branch, so the
  lift must not transcribe it blindly: charset-gate every element on read
  (the `vacated-max` `consider()` precedent) and corroborate the mapping
  against registry state before emitting. A tampered realize event must
  never become a registry redirect pointing an arbitrary citation at an
  attacker-chosen target — the phantom-resolution shape already recorded on
  the rename-emission issue. Surfaced by `sdlc/017`'s spec-phase security
  review (Finding 5).

Decide inside the rename-emitting follow-on's scoping
([[20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche]]);
this issue exists so the obligation created by `sdlc/017`'s ledger-redirect
decision is not lost between the two specs.

## Resolution (2026-08-03)

Delivered by `blueprint/025`. The grammar fork resolved as **a distinct record
verb**, not a widened rename-source token class:

```
spec realize <group>/P-<date>-<slug> <group>/<NNN> <date> <who>
```

That keeps the reserved `P-` form out of rename parsing entirely, so the
vacating fold can never count a provisional as a consumed ordinal — the
fold-safety this issue asked for, structural rather than special-cased and
without a fixture standing between the guarantee and its mechanism.

The record is emitted **live**, in the same CAS batch as the realization's own
allocate, so no window exists where the ordinal is durable and the citation that
became it resolves nowhere. That left the lift as pure repair, which is what
sharpened its idempotency from a nicety into its whole contract.

The untrusted-input obligation held: corroboration is recomputed entirely inside
the publish builder on every CAS attempt, every emitted field is charset-gated,
and the review traced `cmd_pair_events`' awk end to end without constructing an
escape.
