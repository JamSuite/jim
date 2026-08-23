---
id: 20260802-declare-platform-jimalloc-in-the-sdlc-blueprint-s-requires-face
num: 204
title: "Declare platform.jimalloc in the sdlc blueprint's Requires face"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [blueprint, sdlc, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T08:27:17Z
updated: 2026-08-02T08:27:17Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/spec.md
---

## Description

## Description

The `sdlc` blueprint's Requires face declares no `platform.jimalloc` entry,
though `/jim:spec` consumes the allocator directly — identity binding via
`allocate spec` / `peek spec`, and realization via the reconcile path. The
`issue` group's blueprint does declare the same dependency (its
`jimalloc` edge appears in the contract graph), so the two consumers of one
surface disagree about whether the edge is declared.

Not a reconcile finding — the detectors fire on declared data only, so an
undeclared edge is invisible to the graph and to `/jim:verify`'s contract
checks. That is exactly why it needs a deliberate declaration: the omission
exempts one of the allocator's widest consumers from blast-radius facts.

Proposed action: run a group-tier `/jim:blueprint sdlc` update (or fold it
when a build's completion gate next touches the sdlc faces) declaring
`platform.jimalloc` in the Requires face, mirroring the issue group's
entry. The reconcile pass then derives the edge into the contract graph.

Surfaced during the rename/redirect record emission spec's scoping;
previously parked in the session handoff note, which is slated for deletion
once that spec absorbs what it needs — this issue is the durable carrier.
