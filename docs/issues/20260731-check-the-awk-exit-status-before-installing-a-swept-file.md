---
id: 20260731-check-the-awk-exit-status-before-installing-a-swept-file
num: 177
title: "Check the awk exit status before installing a swept file"
status: open
priority: medium
labels: [spec, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:54Z
updated: 2026-07-31T12:38:54Z
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
