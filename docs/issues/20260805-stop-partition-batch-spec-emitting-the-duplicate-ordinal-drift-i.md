---
id: 20260805-stop-partition-batch-spec-emitting-the-duplicate-ordinal-drift-i
num: P-20260805-stop-partition-batch-spec-emitting-the-duplicate-ordinal-drift-i
title: "Stop partition-batch spec emitting the duplicate-ordinal drift its own classifier calls unrepairable"
status: open
priority: critical
labels: [id-coordination, alloc, registry, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:06Z
updated: 2026-08-05T22:20:06Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

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
