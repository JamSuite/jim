---
id: 20260730-close-the-coordinated-spec-identity-fixture-gaps
num: 145
title: "Close the coordinated spec identity fixture gaps"
status: closed
priority: medium
labels: [id-coordination, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:17Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`sdlc/017` shipped with a green 903-case suite, and the suite said nothing about
any of the review's three critical findings. The gaps are specific and
enumerable — this issue is the list.

## Missing fixtures

1. **Padding-variant ordinal** — a registry record carrying `18` against a tree
   holding `018-…`, asserting the realize path halts rather than creating a
   second directory on one ordinal.
2. **Bare `<NNN>` occupant** — a directory named `018` with no slug, asserting
   the occupancy check sees it.
3. **Mixed-batch partial failure** — one identity halts, the rest of the batch
   still lands, and the halted one is absent from both the sweep and the ledger.
4. **Partially-staged directory** — routing to the correct rename primitive.
5. **Group-rename halt** — the realized group differs from the issued group.
6. **Absolute-dir `--apply`** — the tracked/untracked split behaviour.
7. **Exhaustion**, in *either* allocator path — currently untested in both.
8. **`allocate spec --follow-redirect`** end to end — classification is covered,
   the redirect path is never exercised.
9. **A genuine two-spec residual case** — the fixture that claims to cover
   "residual same identity" pre-realizes *the same* directory, so it proves
   resume, not that two distinct specs sharing group/slug/date are surfaced
   rather than merged.

## Why this is worth its own issue

The review's own conclusion: every critical finding was either an omission, a
boundary the tests shared an assumption with, or a defect in reused code.
Test-passing and contract-satisfying diverged completely over this range. Items
1, 2 and 7 in particular are the fixtures that would have caught the shipped
defects rather than documenting them afterwards.

Several of these become moot only if the corresponding defect is fixed *with* a
fixture — so this list is best consumed alongside the defect issues rather than
as a standalone test-writing session.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
