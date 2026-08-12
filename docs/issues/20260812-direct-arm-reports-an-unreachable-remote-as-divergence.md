---
id: 20260812-direct-arm-reports-an-unreachable-remote-as-divergence
num: 307
title: "Direct arm reports an unreachable remote as divergence"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:54Z
updated: 2026-08-12T06:30:53Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

On the checked-out arm every push failure is reported as divergence, including an
unreachable remote — the exact case the spec's network criterion names.

## Mechanism

`skills/issue/scripts/place.sh:638-645`. `place_direct_publish` runs a single
`git push` and, on *any* failure, prints:

> '<dest>' has diverged from '<remote>', so the mutation is committed here but
> not published. Pull and push again to share it — your checkout is left exactly
> as it is.

That message is emitted verbatim for no-push-rights, a protected branch, and an
unreachable remote alike. For the unreachable case the local commit does stand
and nothing is lost, but the reported degradation is the wrong one and the word
"deferred" never appears — so the developer is told to pull and push when the
truth is that publication will resume on the next reachable run.

Related, on the plumbing arm: the non-contention diagnosis at `:1636` is gated on
`tier == "origin"`. A local-tier `update-ref` failure that is not contention
(locked ref, D/F conflict, read-only object store) burns all five attempts with
backoff and then reports "'<dest>' kept moving" — a false cause, loud and
lossless but pointing at the wrong thing.

Neither path is tested: no case drives the direct arm with an unreachable remote,
and none drives a non-contention local-tier failure.

## Proposed action

Distinguish unreachable from rejected on the direct arm and reuse the deferral
wording the plumbing arm already has. Extend the non-contention check to the
local tier. Both would be easier with git's stderr captured rather than
discarded.

## Origin

Post-build review of `issue/011`, AC 7.

## Progress (2026-08-12)

**The plumbing arm's half is closed** in `57489aa`. The non-contention diagnosis
was gated to the origin tier; it now applies on either, so a local `update-ref`
refused for a locked ref, a directory/file conflict at the ref path or a
read-only object store is named as such instead of burning five attempts and
reporting that the branch "kept moving". It stays within one tier: a run that
lost its remote mid-publish has degraded to a different operation against a
different ref, and an unmoved tip across that transition says nothing about the
next attempt. `place_land` now captures git's stderr, so the diagnosis relays the
actual cause. Pinned by
`case_place_local_tier_non_contention_is_named_as_such`.

**The direct arm's half is open**, and is held behind a decision rather than
unwritten: whether the checked-out arm owes AC 6's freshness guarantee at all.
Distinguishing unreachable from rejected there means consulting the remote, which
is the same question `20260812-direct-arm-never-consults-the-remote-before-serving-a-read`
asks — so the two want answering together rather than separately.
