---
id: 20260730-align-the-registry-with-tree-scan-era-spec-ordinals
num: 144
title: "Align the registry with tree-scan-era spec ordinals"
status: open
priority: high
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T10:32:41Z
updated: 2026-07-30T10:32:41Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/plan.md
---

## Description

## Description

The coordination registry does not hold allocate records for the specs created
while `/jim:spec` still derived ordinals from the tree. `platform/011` and
`sdlc/017` both exist on disk with no record, so the allocator's high-water sits
below what the project already owns and `peek`/`allocate spec` will offer an
ordinal that is taken.

This is the live failure `sdlc/017`'s problem statement names, and shipping the
consumer does not fix it: the consumer stops *new* drift, it does not repair
drift that predates it.

The repair is a one-time developer action, not a shipped verb:

- `jimalloc.sh seed --apply` reconstructs the per-kind logs from the tree, and
  now skips pending provisional directories, so it is safe to run against a
  tree holding both realized and pending specs. It refuses when the derived set
  conflicts with what the registry holds, so read the preview first.
- Or hand-append the two missing `spec allocate` records, keeping each spec's
  own creation date in the informational date field.

Either way it must run **from the host**, against the real coordination point —
the mvm agent sandbox cannot reach the coordination remote, which is why the
build could not do it.

Verify afterwards that `peek spec platform` and `peek spec sdlc` both answer
above every ordinal present on disk.

Standing detection and repair machinery is separate work
([[20260726-detect-and-repair-registry-drift]] and its siblings); this issue is
only the one-time alignment.
