---
id: 20260731-make-spec-reconcile-apply-work-from-a-subdirectory
num: 172
title: "Make spec reconcile apply work from a subdirectory"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:38:18Z
updated: 2026-07-31T20:21:09Z
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

## Resolution (2026-07-31) — refused, not relocated

Closed by the C′-fix build
(`docs/notes/20260731-c-prime-fix-build-notes.md`) as a **refusal**: `--apply`
now requires the worktree top and names it when it does not have it.

**The fix this issue proposed is foreclosed.** Deriving the relative form against
`$PWD` yields `../docs/specs`, and `jimfile.sh valid-relpath` rejects any `..`
segment — that is the boundary the citation sweep runs every one of its targets
through, so the relativized spelling could not survive its own downstream use.
The suggestion to "refuse outright" is the one that holds.

**Why refusing is the right direction and not a retreat.** `jimconf.sh` reads
`./jimconf.toml` from the current directory with **no walk-up**, and every
consumer resolves paths against the current directory. The worktree top is
therefore the only place where the configured spelling and its consumers agree —
the toolchain is already root-anchored by construction, and this step was the
one place that pretended otherwise.

**Scope note.** The preview is deliberately left ungated: it mutates nothing, and
a preview followed by a named refusal restores the preview-then-apply contract
rather than breaking it. What is closed is the *silent* discard.

Two fixtures, both red beforehand: a plain subdirectory run, and the sharper
shape this issue describes — an absolute configured specs dir, where the preview
genuinely lists pending identities from a subdirectory and the apply used to
answer "nothing to realize" at exit 0. The second fixture asserts both halves in
sequence, so the contradiction itself is what regresses if this reopens. Suite
958 → 960.
