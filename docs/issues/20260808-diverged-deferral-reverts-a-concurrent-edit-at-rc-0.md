---
id: 20260808-diverged-deferral-reverts-a-concurrent-edit-at-rc-0
num: 285
title: "Diverged deferral reverts a concurrent edit at rc 0"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, data-loss]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:39:29Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

In the `diverged` deferral case, a teammate's already-published edit to the same
file is **silently reverted at rc 0**, with no path named.

## Mechanism

`place_regraft`'s conflict rule — refuse at rc 3 rather than erase a concurrent
edit — runs only on attempt 2 and later
(`skills/issue/scripts/place.sh:1255`). Attempt 1 goes straight to
`place_build_commit` (`:1253`).

In an ordinary race that is sufficient: the concurrent edit arrives *after* this
run read the tip, so the push is rejected and the retry regrafts. In the
`diverged` case the teammate's edit is **already at the remote tip** when the run
reads it:

- `before` = merge-base blob (`open`)
- `after`  = our deferred blob (`closed`)
- remote tip blob = `theirs`

`place_build_commit:949-951` sees `before != after` and writes **our** blob over
the tree read from the remote tip. The parent is the current remote tip, so the
push is a fast-forward and **succeeds**.

The only output is `place_disclose_unpublished`'s generic line (`:391-393`),
which names no file.

## Contrast

`tests/place.sh:892` covers the symmetric case (both sides edit the same file
during an ordinary race) and correctly gets rc 3 with the path named. The
asymmetry is unguarded and untested.

## Proposed action

Run the graft path whenever the base and the onto-tip are different commits, not
only on a retry. The condition is `PLACE_BASE_TIP != <current onto tip>`, which
is true exactly in the diverged case on attempt 1 and false in the ordinary case.

That also means `place_regraft` becomes the single place the conflict rule
lives, rather than the retry-only path.

## Test

A case where the clone holds a deferred edit to a file the teammate has already
edited and published. Expect rc 3 with the path named, and the teammate's content
intact at the destination.

## Resolution (2026-08-11)

Fixed in `867ec04`. The conflict rule no longer lives on the retry path: every
attempt grafts whenever the base and the tip being landed onto are different
commits, which is true of the diverged case on its first attempt. Covered by
`case_place_deferred_edit_refuses_a_concurrent_edit`, which expects rc 3 with the
path named and the teammate's content intact.
