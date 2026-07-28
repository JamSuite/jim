---
id: 20260728-reconcile-sh-swallows-the-index-regen-exit-code
num: 134
title: "reconcile.sh swallows the index-regen exit code"
status: open
priority: low
labels: [id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T21:39:49Z
updated: 2026-07-28T21:39:49Z
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
