---
id: 20260728-reconcile-sh-swallows-the-index-regen-exit-code
num: 134
title: "reconcile.sh swallows the index-regen exit code"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-28T21:39:49Z
updated: 2026-07-31T20:41:26Z
origin: docs/specs/issue/010-ordinal-coordination/review.md
---

## Description

In `reconcile.sh`, the `--apply` path runs the final index regeneration as
`index.sh … >/dev/null 2>&1` (~:202) with no exit-status check. A failed final
index regen is therefore silent: reconcile still reports success while
`INDEX.md` is left stale.

## Fix

Capture and check the `index.sh` exit status; surface a non-zero regen as a
reconcile failure (or at least a clear warning) rather than swallowing it.

## Resolution (2026-07-31)

`sdlc/018` added the status check and the failure message. Its own
verified-rewrite change then made the regeneration *skippable* — the realizer
returned on a failed rewrite before ever reaching `index.sh` — so the swallowed
exit code was replaced by no exit code at all, and this issue was held open
rather than closed on a check that could be bypassed.

Closed now that the C′-fix build made the regeneration unconditional
([[20260731-regenerate-the-issue-index-before-aborting-on-a-rewrite-failure]]):
both realizers accumulate per-file failure and continue, so the terminal
regeneration always runs and its status is always carried.

The spec-side twin this issue's filing anticipated was fixed in the same pass —
which was the point of absorbing the two together rather than fixing one file
and leaving its copy.
