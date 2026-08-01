---
id: 20260801-realize-occupancy-gate-reads-the-configured-specs-dir-not-its-ro
num: 193
title: "Realize occupancy gate reads the configured specs dir, not its root"
status: closed
priority: low
labels: [scripts, spec, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T06:36:07Z
updated: 2026-08-01T10:01:09Z
origin: docs/notes/20260801-c-prime-fix-handoff.md
---

## Description

## Context

The realize path's occupancy gate in `skills/spec/scripts/reconcile.sh:253`
calls:

```
held="$(jf spec-ordinal-holder "$group" "$ord")"; held_rc=$?
```

without `--root`. The sibling caller in `skills/ledger/scripts/jimledger.sh:629`
does pass `--root`.

## Problem

Without `--root`, the helper reads the **configured** specs directory rather
than the `$root` the gate is guarding. The gate can therefore answer a question
about a different tree than the one it is about to write to.

There is no live divergence today — but only because the worktree-top guard
added in the C-prime-fix forces the two to be equal. That is an unstated
dependency between two guards written for unrelated reasons: relax or relocate
the worktree-top refusal and this gate silently starts consulting the wrong
tree, with no test covering the difference.

## Proposed action

Pass `--root "$root"` at `:253` so the gate reads the tree it guards, making the
call independent of the worktree-top guard's incidental normalization. Match
`jimledger.sh:629`. Consider a test that runs the realize path with a configured
specs dir differing from `$root`, so the dependency cannot silently reappear.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding P2). Pre-existing,
not introduced by that build. Anchor re-confirmed 2026-08-01 — the missing
`--root` is visible in the source. Latent: no reproduction exists today because
the guard makes the two paths agree.

## Resolution (2026-08-01)

Fixed — `--root "$root"` is now passed, matching the sibling call in
`jimledger.sh`.

**No live divergence exists, and none is reachable.** The apply gate refuses a
`<specs_dir>` argument that does not resolve to the configured specs dir, so the
two are forced equal on the only path that reaches this gate. The change is
defense in depth: the gate should not depend on a refusal held elsewhere for its
own reasons. Not separately fixtured, because no CLI input can make the two
differ.
