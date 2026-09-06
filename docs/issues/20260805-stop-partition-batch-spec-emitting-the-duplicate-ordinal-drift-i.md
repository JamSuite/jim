---
id: 20260805-stop-partition-batch-spec-emitting-the-duplicate-ordinal-drift-i
num: 251
title: "Stop partition-batch spec emitting the duplicate-ordinal drift its own classifier calls unrepairable"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, alloc, registry, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:06Z
updated: 2026-08-06T06:38:55Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

`partition-batch spec` writes a state its own classifier calls unrepairable
drift, so every renumber permanently fails the registry-tree-consistency
invariant.

The builder emits `spec allocate <new>` then `spec rename <old> <new>`
(`skills/file/scripts/jimalloc.sh:3504-3505`). `alloc_spec_replay:1663` calls a
rename onto an already-live destination a `DUP`, which `cmd_sweep:3020` puts in
`drift_rows` and `alloc_catchup_compute:3159` puts in `CU_BLOCKED` as "an
operator decides which side is right". No operator can: the grammar has seven
encoders and zero tombstone, precedence or revoke primitive.

```
allocate spec jim "Alpha"; allocate spec jim "Beta"
printf 'jim/001\tplatform/001\talpha\n' | partition-batch spec 20260802
  -> jim/001  platform/001    rc=0

sweep
  -> drift:
       duplicate-ordinal  spec  platform/001  records 5 and 6
     rc=3

catch-up --apply
  -> catch-up: nothing to append - every tree identity already has a record
     cannot repair (an operator decides which side is right):
       duplicate-ordinal  spec  platform/001  records 5 and 6
     rc=3
```

`jimconf.toml:17` wires `verify_command_id-sweep` to that sweep, and the platform
blueprint's `registry-tree-consistency` invariant (high) reads its exit code. So
on any project that runs `/jim:partition`'s renumber, that invariant fails from
first use and stays failed.

jim's own registry is clean only because it was built by `lift`, which writes the
rename alone — `partition-batch spec` has never been run here.

The replay's own header (`:1636-1639`) claims there is ONE replay "because the
integrity report and the emission refusals must not be able to disagree about
what 'already claimed' means." They do disagree.

## Proposed action

Decide which side is wrong and make them agree. Either the emitter stops pairing
an `allocate` with a `rename` onto the same destination (the rename alone already
establishes the claim, which is what `lift` does), or the replay stops calling
that pairing a `DUP` when the allocate and the rename name the same destination
in the same batch.

Whichever is chosen, fixture a `partition-batch spec` renumber followed by a
clean `sweep` at rc 0 — the property this issue exists to restore.

## Resolution (2026-08-06)

Fixed on the emitter side, which is the side that was wrong.
`alloc_partition_spec_publish_builder` now emits the **rename alone** per pair —
the paired `spec allocate <dst>` is gone. The builder already requires a live
source, so the replay moves *that* claim onto the destination; the allocate was
a second claim on an id the rename was about to take, which the same replay
reports as `DUP`. Shape 1 (renumber = new allocation + redirect tombstone) is
retired for the spec arm: what establishes a destination and what the integrity
report calls established are now one decision.

The alternative — teaching the replay not to call that pairing a duplicate —
was rejected on two counts. It folds a correct integrity rule down to match an
emitter, and the detection would have to key on record adjacency plus a shared
`<date>`/`<who>`, a shape any crafted log can imitate.

**`lift` is not the precedent it looks like.** This registry holds 52
destinations carrying both an allocate and a rename and **zero** `DUP` rows,
because the lift's rename sources are not live claims — its renames are pure
redirects over destinations the seed had already established, so they never
reach the claim-moving branch. The argument for dropping the allocate is not
"lift does it" but that the rename already carries the claim from a live source.

**The `<slug>` column is now load-bearing rather than ignored.** A rename record
has no slug field; the destination inherits the source's. A pair naming a
different slug is asking for a record the grammar cannot write, so it is refused
by name — which keeps it from surfacing later as tree-vs-registry `MISMATCH`
over an ordinal that has already bound. The check sits *after* the destination
gates, so a pair wrong in two ways reports the contradiction about the registry
before the one about its own fields. `alloc_live_claim_set` fills a `live_slug`
map for it; all three of its callers declare the array, since under `set -u` an
undeclared associative array would silently become an indexed one with an
arithmetic subscript.

Operator-visible consequence, documented in `skills/partition/SKILL.md`: a slug
refusal at Close means the tree and the registry already disagree about that
spec's slug, and `jimalloc.sh sweep` is where that gets settled.

`case_jimalloc_partition_batch_spec_emits_pairs` was **rewritten**, not merely
adjusted — it asserted the paired allocate, and its stated reasoning ("every
destination is established by a record of its own") was the defect. Its header
now records why that reasoning was wrong rather than treating it as superseded.
New: `case_jimalloc_partition_batch_renumber_leaves_no_drift` (the property this
issue exists to restore — renumber, move the tree, `sweep` rc 0, `catch-up`
nothing to say), `case_jimalloc_partition_batch_refuses_a_slug_change`, and
`case_jimalloc_partition_batch_destination_gate_precedes_the_slug_gate`. All
mutation-tested: restoring the paired allocate, neutering the slug check,
starving `live_slug`, and moving the slug gate ahead of the destination gates
each turn their fixture red.
