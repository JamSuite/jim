---
id: 20260807-offline-placed-read-serves-an-empty-collection
num: 267
title: "Offline placed read serves an empty collection"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:22Z
updated: 2026-08-12T09:15:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Under a branch placement, a clone that has only ever *read* the collection
serves an **empty** collection when the remote is unreachable, while announcing
that it is serving the last-seen state.

Reproduced: clone B reads the shared collection online and sees the issue, goes
offline, reads again:

```
place.sh: remote 'origin' is unreachable; serving the last-seen state of 'jim/issues'
(no issues, no counts)
```

`place_local_tip` reads `refs/heads/<dest>`, which only a successful
`place_land` ever creates. `git clone` does not create it, and
`place_remote_tip`'s fetch writes FETCH_HEAD and the remote-tracking ref, never
the local head. So `tip` is empty, materialization returns immediately, and the
collection is empty.

The information needed is already recorded: the bookmark ref
`refs/jim/issue-placement/<branch>` holds exactly the right sha and its objects
are local. `place_local_tip` simply never consults it.

## Why the suite misses it

`place_seed_collection` ends in `git update-ref "refs/heads/$branch"` in the
*same* repo, so the degrade case always has a local branch a real clone would
not. The fixture makes the bug unrepresentable.

## Proposed action

Fall back to the bookmark ref when `refs/heads/<dest>` is absent — it is the
recorded last-seen tip, which is precisely what the message claims to be
serving. Add a fixture that reads from a clone which has never published.

## Resolution (backfilled 2026-08-12)

*Closed by the fix pass in `5de0c70`; this note is reconstructed from that pass's
commits, which recorded the resolution in trailers alone.*

Fixed in `a039a08`. A read that cannot reach the remote serves the last-seen tip
recorded for the destination instead of an empty collection, and says on stderr
that it is doing so — an unreachable network degrades the view's freshness, not
its existence.

Pinned by `case_place_offline_read_serves_the_last_seen_collection` and
`case_place_read_degrades_when_remote_unreachable` in `tests/place.sh`.

**Related consequence.** Making this path reachable more often is what turned the
bookmark's honesty into a live concern, argued in as its own package under this
remediation rather than left as a latent one.
