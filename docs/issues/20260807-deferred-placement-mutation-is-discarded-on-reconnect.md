---
id: 20260807-deferred-placement-mutation-is-discarded-on-reconnect
num: 265
title: "Deferred placement mutation is discarded on reconnect"
status: closed
priority: critical
labels: [issue, placement, data-loss]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:21Z
updated: 2026-08-12T09:15:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The message says publication is deferred until the next reachable run. Nothing
implements that, and the next reachable run destroys the deferred commit.

Reproduced end to end:

```
offline:   place.sh commit <tok> --verb close --id 20260101-a
           -> rc 0, local commit made, no stderr disclosure at all
           -> local head: "closed"
reconnect, one read, then any write:
           -> 20260101-a.md on remote is: [open]
           -> 20260101-a.md locally is:   [open]
```

The close is gone from both. AC #7 states "No mutation is ever silently
dropped."

## Three mechanisms compound

1. **Nothing ever pushes the deferred commit.** The only pushes send a commit
   built *this run* on the *remote* tip. The local branch's accumulated history
   is never propagated.
2. **`place_land` force-resets the local ref.** After a successful push it runs
   `git update-ref "refs/heads/$branch" "$commit"` with no old-value, so the
   deferred commit is overwritten rather than merged.
3. **The one warning is consumed by any intervening read.** `place_check_rewrite`
   would fire, but a read advances the bookmark first, so the subsequent write is
   silent.

`cmd_run` at least prints a deferral notice. `cmd_commit` prints nothing, so the
two-phase edit flow is silent from start to finish.

Note the filing path is safe: the allocator hard-fails offline before anything is
written. The exposure is exactly the `begin`/`commit` flow, the one with no
allocator gate.

## Proposed action

Either implement resumption — on a reachable run, detect that the local
destination ref is ahead of the remote and push it before (or instead of)
building a fresh commit — or stop promising it and refuse the write offline,
which is the allocator's posture for the same condition.

Whichever is chosen, `place_land`'s unconditional local `update-ref` needs an
old-value, and `cmd_commit` needs the deferral disclosure `cmd_run` already has.

## Resolution (backfilled 2026-08-12)

*Closed by the fix pass in `5de0c70`; this note is reconstructed from that pass's
commits, which recorded the resolution in trailers alone.*

Fixed in `8f30b75`. A run that reconnects publishes the mutations an earlier
unreachable run left committed locally, rather than discarding them. Where the
destination had moved too, the changed set is measured from the two sides' common
ancestor and reapplied on top of it — measuring from the remote's tip instead
would read a teammate's commit as a deletion.

Pinned by `case_place_deferred_mutation_publishes_on_reconnect` in
`tests/place.sh`.

**Extended by this remediation.** The fix handled reconnect and diverged but not
a reconnect that then loses a push race, which was filed separately as
[[20260808-deferred-mutation-lost-when-the-resuming-push-loses-a-race]]
and closed by collapsing attempt 1 and attempt N onto one path. That the two
compose is the reason this class recurred.
