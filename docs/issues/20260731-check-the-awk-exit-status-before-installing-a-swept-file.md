---
id: 20260731-check-the-awk-exit-status-before-installing-a-swept-file
num: 177
title: "Check the awk exit status before installing a swept file"
status: closed
priority: medium
labels: [spec, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:54Z
updated: 2026-07-31T20:28:56Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`sweep_citations` does not check awk's exit status (`skills/spec/scripts/reconcile.sh:463`)
before installing its output:

    cat -- "$tmp_out" > "$f"

A mid-stream awk failure that occurs after at least one `REWROTE` record has been
written to `$rec` leaves `$rec` non-empty, so the `[[ -s "$rec" ]]` guard passes
and a truncated `tmp_out` is installed over a real tracked file.

## Fix

Capture awk's status and skip the install (reporting the failure) when it is
non-zero.

Finding 7 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

Closed by the C′-fix build. awk's status is captured and the install is skipped
when it is non-zero, with the file named. The reasoning is now stated where the
check sits: a non-empty record file is **not** evidence the output is whole,
because a rewrite that died partway has already written whatever records it got
to — which is exactly what made the `[[ -s "$rec" ]]` guard insufficient.

The failure does not abort the sweep. Other files still sweep and the run returns
non-zero, matching the per-item accumulate-and-continue semantics the realizers
use: one unwritable file must not strand the rest of a batch whose ordinals are
already published.

Fixtured by shimming `awk` on `PATH` for the sweep's own invocation only —
identified by its `recfile=` binding, with everything else `exec`ing the real
awk — so the shim reproduces the exact shape (a record written, then a
mid-stream failure) without disturbing the twenty other awk calls in the run.
