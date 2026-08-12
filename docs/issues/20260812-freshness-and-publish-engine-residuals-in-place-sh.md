---
id: 20260812-freshness-and-publish-engine-residuals-in-place-sh
num: P-20260812-freshness-and-publish-engine-residuals-in-place-sh
title: "Freshness and publish engine residuals in place.sh"
status: open
priority: medium
labels: [issue, placement, disclosure]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:58Z
updated: 2026-08-12T21:53:58Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Six residuals in `place.sh`'s freshness and publish machinery, found by the fourth
review. None loses a mutation; each is a disclosure or hygiene gap. Grouped
because they share a file and a review pass.

## 1. The partial-view disclosure is origin-tier only

`place_resolve_tips` returns at `place.sh:499` unless `tier == origin`, so on an
unreachable-remote read the state stays `current` and
`place_disclose_partial_view` is silent — while `cmd_run:1701-1704` prints
"serving the last-seen state of '<dest>'".

Concretely: offline write lands `L` locally without advancing the bookmark
(`:1864` gates the advance on `tier == origin || -z remote`); remote returns, a
read advances the bookmark to the teammate's `B` and correctly discloses; remote
drops again, and `place_local_tip` returns `L` (since `L` is not an ancestor of
`B`). The view now omits everything in `B` that is not in `L`, under a message
asserting it *is* the last-seen state.

The ref choice is deliberate and documented (`:420-422`); the defect is that the
origin tier's honesty note has no local-tier twin.

**Action:** compute the head-vs-bookmark relation on the local tier too and emit
the partial-view note, or soften the degrade wording when the served tip is not
the bookmark.

## 2. A pure rewind of a remote-less destination is undisclosed

`place.sh:1698` hands `place_check_rewrite` the output of `place_local_tip`, which
returns the *bookmark* whenever `refs/heads/<dest>` is an ancestor of it. In a
repo with no remote — where that ref **is** the destination, so the run is
authoritative — a rewind (`git reset --hard`, a bad rebase) makes `seen == tip` and
the run goes silent; the read serves the pre-rewind collection and the next write
fast-forwards the branch back over the rewind. The checked-out arm catches the same
rewind (`:704`, pinned at `tests/place.sh:2087`); the gap is remote-less **and**
destination-not-checked-out.

**Action:** on the remote-less path pass `place_head_tip "$dest"` — the ref that
actually is the destination — to `place_check_rewrite`, leaving the materialization
tip unchanged.

## 3. The diverged deferral collapses N mutations into one commit

`place_resolve_tips:513-516` sets `diverged`; `place_commit_changes:1852-1856` then
builds a **single** commit carrying both the deferred mutation's content and this
run's, with the subject composed only from *this* run's verb and id, and
`place_land:1476` orphans the deferred local commit. So a deferred `file` can land
inside `docs(issues): edit <id>`. Content is preserved; AC 4's "each mutation as
exactly one commit with a fixed message" is not.

**Action:** say in `place_disclose_unpublished`'s diverged branch that the deferred
mutations are being folded into this commit rather than kept as their own, and add
a case asserting the destination gains exactly one commit there.

## 4. `ref_old` is not re-read on the origin-stays-origin retry

`place.sh:1873-1878`'s comment says "On either tier the ref's own value is read
*before* the tip it is paired with". The origin-stays-origin path (`:1879-1884`)
re-reads only `tip`. It fails closed — the swallowed `update-ref … || true` at
`:1476` can only mismatch — but `refs/heads/<dest>` then silently stops tracking
after a retried origin publish. Unchanged from the third review.

**Action:** re-read `ref_old` before `tip` on that branch, or narrow the comment to
the two paths that do.

## 5. `place_snapshot` reads a `find` failure as an empty collection

`place.sh:1388` discards `find`'s status. An empty `after` makes
`place_build_commit:1433-1436` force-remove every path in `before` — a
whole-collection deletion at rc 0. Currently unreachable because `place_reindex`
runs against the same directory immediately before both `after` snapshots and fails
first, so this is defence-in-depth against a reordering. It contradicts the
discipline `place_dirty_guard:601-611` states explicitly: a guard that could not run
has not passed.

**Action:** return 1 when the enumeration itself fails.

## 6. Two smaller ones in `place_build_commit`

- `:1431` hardcodes mode `100644` while `place_materialize:1308` accepts `100755`,
  so an executable collection entry the mutation touches is silently demoted on
  republish. Harmless for markdown; an asymmetry in a round trip the group
  otherwise enforces at both ends.
- `:1438` discards git's stderr (`2>/dev/null` on the subshell), yielding a bare
  "could not build the destination tree" with no cause — the exact class fixed one
  function over in `place_land`.

## Untested compositions

`ahead`/`diverged` with an empty changed set (`:1837`); the `merged == upstream`
rc-0 arm (`:1855`); the origin-tier `git reported:` relay (asserted only on the
local tier); a two-phase `commit` exhausting all five attempts; `place_snapshot`'s
directory/fifo half; `place_materialize`'s gitlink rejection.
