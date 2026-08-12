---
id: 20260812-a-routed-read-s-view-goes-to-stderr-labelled-not-published
num: 299
title: "A routed read's view goes to stderr labelled not published"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:48Z
updated: 2026-08-12T03:41:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Under a branch placement, a read whose index could not be rebuilt sends its
rendered view to **stderr** labelled "not published", leaving stdout empty —
contradicting `render.sh`'s own documented contract.

## Mechanism

Two changes compose. `render.sh` now serves a stale view, discloses it on stderr,
and returns rc 1 (`render.sh:736`). `place.sh` holds a wrapped write's stdout and
releases it to stderr under a marker when the run exits non-zero
(`place.sh:1508-1513` → `:1354-1363`).

A routed read execs `place.sh run --read -- bash render.sh …`. When `index.sh`
fails inside the materialized copy, the inner `render.sh` serves the view and
returns 1 — and `cmd_run` treats that non-zero status as a failed run, so the
whole view is written to stderr under:

```
place.sh: not published — the wrapped command reported:
```

which is doubly wrong for a `--read` run: it publishes nothing by construction,
and the caller's stdout is empty. `render.sh`'s header promises "stdout still
carries it". The skill presents stdout verbatim, so the user sees nothing.

The direct arm does not have this behavior — `place_direct` passes stdout through
unheld.

## Proposed action

Release held stdout to stdout for a `--read` run regardless of the wrapped
command's status, or distinguish "the command failed" from "the command served a
degraded view" before choosing the stream. The held-stdout mechanism exists to
stop a *write* from naming a destination path that does not exist; a read has no
such contract to protect.

## Origin

Post-build review of `issue/011`. Both changes were made in the same remediation
and are correct in isolation; the defect is in their composition. Found
independently by the AC 5 investigator and the `staleness-gated-reads` judge.
