---
id: 20260812-an-empty-commit-is-reachable-after-a-retry-base-recomputation
num: 300
title: "An empty commit is reachable after a retry base recomputation"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:53Z
updated: 2026-08-12T03:41:53Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

An empty commit can reach the destination on the plain-build arm of the publish
retry loop, because the "nothing changed" guard is not re-evaluated after a
retry recomputes the base.

## Mechanism

`skills/issue/scripts/place.sh:1580-1592`. The changed-set guard runs once before
the loop (`place_changed "$3" "$4" || return 0`) and again on the graft arm
(`:1592`, `place_changed upstream merged || return 0`). The plain-build arm at
`:1586-1587` has no such re-check.

When a retry's merge base moves, `:1643-1647` refreshes the caller's `before`
array in place. The next iteration may then take the straight-build branch with a
`before` that already matches `after` — `place_build_commit` writes a tree
identical to the tip's, and `place_land` publishes a commit with no diff.

Reaching it requires `merge_base(work_tip, new_tip) == new_tip` after a
rejection — a branch rewind between attempts, or the `ahead` deferred state where
attempt 1's tip is the local head and a rejection re-reads a remote tip that
becomes the new base — combined with a teammate having landed identical content.

Narrow, and not a mutation loss. But it is the one path where an empty commit can
reach the destination, and no test asserts a commit count *after* a retry.

## Proposed action

Re-run `place_changed` on the plain-build arm after a base recomputation, or move
the guard inside the loop so both arms share it. Add a case asserting the commit
count after a retry.

## Origin

Post-build review of `issue/011`; found independently by the AC 4 and AC 7
investigators.
