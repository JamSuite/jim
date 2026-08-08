---
id: 20260808-commit-direct-publishes-uncommitted-work-with-no-dirty-guard
num: 281
title: "commit direct publishes uncommitted work with no dirty guard"
status: open
priority: medium
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:49Z
updated: 2026-08-08T18:39:49Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`place.sh commit direct` is callable with no preceding `begin`, and nothing on
that path runs the dirty guard — so it commits and pushes whatever uncommitted
work happens to be sitting in the collection. This is security Finding 9's harm
on the one arm where nothing proves the guard ran.

## Mechanism

`direct` is a fixed literal, not an unguessable handle
(`skills/issue/scripts/place.sh:513`). The arm's own comment concedes the point
(`:696-699`): "there is no evidence in the token that a `begin` ever happened at
all."

The re-verification added for the branch-switch defect closes that specific harm
— it refuses the `branch` sentinel (`:702-706`) and re-asserts HEAD (`:708-714`)
— but no dirty guard runs anywhere on the path. `place_dirty_guard` runs at
`begin` (`:615`) and in `cmd_run`'s direct arm (`:459`), neither of which is
involved.

So:

```
$ place.sh commit direct --verb close --id 20260101-a
```

reaches `place_direct_publish` (`:715`) and stages, commits and pushes the
developer's half-finished edits.

## Why it cannot simply be fixed by adding the guard

At commit time the mutation's own edits **are** the dirty state, so re-running
`place_dirty_guard` would refuse every legitimate two-phase commit. The guard's
placement at `begin` is correct and deliberate.

## Proposed action

Give the direct handle something that proves `begin` ran and what it saw — a
`begin`-issued marker under the git dir recording the pre-mutation status of the
collection, which `commit` consumes and removes. That restores the property the
plumbing handle gets for free from its recorded state, without making the guard
unusable.

Note the caller already needs shell access to invoke this, so it is not a
privilege escalation over the calling context. The exposure is a mistaken or
injected `commit direct` publishing work the developer never approved.

## Related

The read half of this was fixed by the `direct-read` token; this is the
remaining write half.
