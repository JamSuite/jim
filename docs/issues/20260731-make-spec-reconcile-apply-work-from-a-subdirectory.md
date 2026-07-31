---
id: 20260731-make-spec-reconcile-apply-work-from-a-subdirectory
num: 172
title: "Make spec reconcile apply work from a subdirectory"
status: open
priority: high
labels: [spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:18Z
updated: 2026-07-31T12:38:18Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

The `--apply` guard in `skills/spec/scripts/reconcile.sh:550-570` derives `$dir`
relative to the git worktree top, but every downstream consumer resolves paths
relative to the process CWD, and nothing establishes that the two are the same.

Run `--apply` from `$top/sub`: containment passes, `:568` rewrites `dir` to
`sub/docs/specs`, and `[[ -d "$dir" ]]` at `:572` then resolves to
`$top/sub/sub/docs/specs`, fails, and the run prints *"reconcile: no pending
provisional specs — nothing to realize."* and exits **0**.

The preview path does not rewrite (`:550` gates on `apply`), so from that same
directory the preview lists N pending identities and `--apply` immediately claims
there are none.

## Why it matters

The wrong failure direction for a step whose entire contract is
preview-then-apply: the developer approves a plan that the apply silently
discards at exit 0.

## Fix

Derive the relative form against `$PWD` rather than the worktree top, or refuse
outright when `$PWD` is not the worktree top. Note `realpath --relative-to` is
GNU-only and unavailable to this layer.

Finding 2 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
