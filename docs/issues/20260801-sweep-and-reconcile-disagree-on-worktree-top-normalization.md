---
id: 20260801-sweep-and-reconcile-disagree-on-worktree-top-normalization
num: P-20260801-sweep-and-reconcile-disagree-on-worktree-top-normalization
title: "Sweep and reconcile disagree on worktree-top normalization"
status: open
priority: medium
labels: [scripts, spec, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T06:36:05Z
updated: 2026-08-01T06:36:05Z
origin: docs/notes/20260801-c-prime-fix-handoff.md
---

## Description

## Context

Two functions in `skills/spec/scripts/reconcile.sh` resolve the worktree top,
and they do not agree:

- `sweep_citations` at `:351` takes `git rev-parse --show-toplevel` **raw**
- `cmd_reconcile` at `:607` re-normalizes the same value through `realpath -m`

## Problem

On a symlinked worktree the two values differ. `sweep_citations` then compares
each configured content root — itself resolved through `realpath -m` at `:367` —
against an un-normalized `$top`. Every root reads as outside the worktree, every
root is dropped, and `(( ${#roots[@]} )) || return 0` at `:382` returns **0 with
nothing swept**.

The own-directory sweep is included in that, which is the part that matters:
its whole purpose is the uncommitted case, where the realized directory is
invisible to git and the sweep is the only thing that rewrites its citations.

Compounding with N1, the drop is silent on both counts — no root sets
`sweep_failed`, and the empty-roots early return is a success path.

## Proposed action

Normalize `$top` through `realpath -m` in `sweep_citations` as `cmd_reconcile`
already does, so both sides of the containment comparison are in the same form.
Consider hoisting the resolution to a single helper so the two cannot drift
again.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding N3). Anchors
re-confirmed 2026-08-01 — the asymmetry between `:351` and `:607` is visible in
the source. The symlinked-worktree failure was reasoned from the comparison, not
reproduced on a symlinked checkout.
