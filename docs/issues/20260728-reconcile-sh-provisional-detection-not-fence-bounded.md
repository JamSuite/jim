---
id: 20260728-reconcile-sh-provisional-detection-not-fence-bounded
num: 133
title: "reconcile.sh provisional detection not fence-bounded"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-28T21:39:43Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/issue/010-ordinal-coordination/review.md
---

## Description

In `reconcile.sh`, the `num:` rewrite (`rewrite_num`) is anchored to the leading
frontmatter block, but the pending-detection scan (`scan_pending`) matches the
first `^num:` **anywhere in the file**. The two are not bounded to the same
region.

A crafted issue file — frontmatter `id:` present, **no** frontmatter `num:`, and
a body line `num: P-<id>` — makes `scan_pending` treat the file as a pending
provisional and trigger a **spurious real-ordinal allocation**. No wrong-line
rewrite happens (the rewrite is still fence-anchored) and no unvalidated value is
consumed (the id remains `valid-id`-gated), so the blast radius is a wasted
ordinal / spurious reconcile, not a write-primitive — hence low severity — but
the detection/rewrite mismatch is a latent inconsistency.

## Fix

Fence-bound `scan_pending` to the leading frontmatter block so detection matches
`rewrite_num`'s region exactly.
