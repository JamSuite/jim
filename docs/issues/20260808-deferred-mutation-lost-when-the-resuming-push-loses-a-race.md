---
id: 20260808-deferred-mutation-lost-when-the-resuming-push-loses-a-race
num: 282
title: "Deferred mutation lost when the resuming push loses a race"
status: closed
priority: critical
labels: [issue, placement, data-loss]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:28Z
updated: 2026-08-10T23:00:55Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

A mutation deferred while the remote was unreachable is silently dropped, at
rc 0, if the next reachable run's **first push loses a race**. This is the same
silent-drop class as the defect the deferral fix was written to close, one state
deeper.

## Mechanism

`place_resolve_tips` runs once (`skills/issue/scripts/place.sh:1183`), but
`place_commit_changes` re-reads the tip on every retry (`:1280`) **without
re-resolving the triple**.

In the `ahead` state, `PLACE_BASE_TIP` is set to the local head (`:370-372`), so
the `before` snapshot **already contains** the deferred content. Attempt 1 is
correct only because the deferred commit is the commit's *parent*.

When that push is rejected:

```
attempt 2:  tip = R'   (the winner's tip, which lacks our deferred commit)
            touched  = { this run's own paths }     <- deferred paths absent,
                                                       because before == after
            merged   = R' content + this run's paths
            commit   = parent R', deferred content gone
```

`place_regraft`'s `touched` computation (`:1039-1044`) only marks paths where
`before` and `after` differ. The deferred paths are identical in both, so they
are never replayed. `place_land` then succeeds (the new commit fast-forwards
from `R'`) and `git update-ref` moves the local ref past the deferred commit.
`place_advance_bookmark` (`:1268`) records the result, so `place_check_rewrite`
will not flag it on any later run either.

Net: rc 0, no stderr, the mutation gone from both the remote and the local
branch. Recoverable only from the reflog, and nothing tells anyone to look.

Spec AC #7: "No mutation is ever silently dropped."

## Why the diverged arm is unaffected

`diverged` sets the base to the merge-base of the two sides, so every deferred
path lands in `touched` and is regrafted correctly. The bug is specific to
`ahead`, whose base is the local head.

## Proposed action

Re-resolve the base inside the retry loop: an `ahead` state that loses a race
**is** a `diverged` state on the next attempt. Concretely, after re-reading the
tip, recompute `PLACE_BASE_TIP` as `merge-base(PLACE_WORK_TIP, tip)` and
re-snapshot `before` from it before calling `place_regraft`.

The two-phase flow needs the same treatment: `cmd_begin` persists only `tip` and
the base snapshot (`:658-666`), not the tip state, so an `ahead` handle whose
commit loses a race drops the deferred content identically.

## Test

No case drives `ahead` + a lost push race. The existing deferral cases
(`tests/place.sh:765`, `:794`) cover reconnect and divergence but never a race
during the resuming push.
