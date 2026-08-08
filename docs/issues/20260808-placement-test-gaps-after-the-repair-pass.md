---
id: 20260808-placement-test-gaps-after-the-repair-pass
num: P-20260808-placement-test-gaps-after-the-repair-pass
title: "Placement test gaps after the repair pass"
status: open
priority: medium
labels: [testing, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:40:10Z
updated: 2026-08-08T18:40:10Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

An audit of the placement suite after the test-repair pass found two cases that
still cannot catch their named mutation, one that still tests nothing, and the
highest-value assertion in the set still missing.

## Cannot catch its named mutation

`tests/place.sh:1262-1272` — `case_place_direct_commit_refuses_the_branch_sentinel`
asserts only `rc == 2` and a non-empty message. Delete the sentinel guard at
`place.sh:702-706` and control falls to the very next guard: `dest` is now the
literal `branch`, `current` is `main`, so the HEAD check fires and returns **the
same rc 2 with a non-empty message**. Green either way, and indistinguishable
from its neighbouring case.

Fix: pin the distinguishing text, e.g.
`assert_match "names the sentinel refusal" 'no longer names a destination' "$ERR"`.

## Passes for the wrong reason

`tests/issues.sh:3086-3105` — the reconcile half of
`case_issues_placement_preview_publishes_nothing` asserts only `preview rc 0`.
Delete `route_placement` from `reconcile.sh` and the preview runs against a
non-existent working-tree collection, prints "no pending provisional issues", and
returns **0**. The migrate half *is* discriminating (`migrate.sh:262` returns 1
on a missing dir), so the case is partial rather than worthless.

Fix: assert the preview reports the destination's provisional, mirroring what the
sibling read case does.

## Still tests nothing

`tests/issues.sh:2845-2859` — `case_issues_placement_tolerates_a_branch_only_origin`.
The repair pass removed the working-tree origin file to make the origin genuinely
dangling, but the origin value `docs-only-here.md` contains **no `/`**, so
`index.sh:461-462`'s `*/*` path-shaped guard exempts it from the lint entirely.
The file's existence is never checked either way, so the change was a no-op.

Fix: use a path-shaped origin (e.g. `docs/brainstorms/x.md`). That also makes the
origin-lint churn case exercisable.

## Highest-value missing assertion

**No test in the suite asserts the bookmark ref's value at any point.** Neither
of the two bookmark conditions added by the deferral fix is pinned:

- `place.sh:1267` — `if [[ "$tier" == "origin" || -z "$remote" ]]` before
  `place_advance_bookmark`. Delete the condition and the **entire suite stays
  green**; the deferral cases would emit a spurious "was rewritten" on stderr,
  but neither asserts `ERR`.
- `place_check_rewrite`'s `authoritative` argument — no case distinguishes 0 from
  1; hardcoding `1` changes no observable outcome.

## Other untested production changes

- `cmd_begin`'s dirty guard for a direct-mode **write** handle
  (`place.sh:615`) — deleting it leaves the suite green and reopens security
  Finding 9 on the two-phase door. The existing dirty-guard case covers `run`,
  and the direct-read case takes the path that bypasses the guard.
- `begin` against a hostile tree — `place_seed_traversal` is driven only through
  `run`, which is why the rc-0 flattening on the `begin` path is uncaught.
- `place_disclose_unpublished`'s two messages — neither arm's content is
  asserted.
- The `--auto --dir` combination under a placement (the intended inertness).

## Fixture hygiene

`place_seed_traversal` (`tests/place.sh:89-107`) checks none of its own exit
statuses, unlike its `place_seed_collection` sibling. Two `rev-parse` baselines
in `tests/issues.sh` (`:3071`, `:3140`) still lack `--verify`.
`stale_dest_index` rebuilds the collection tree bottom-up and would silently drop
sibling paths at either level — harmless today because the destination is always
an orphan carrying the collection alone, wrong the moment a case points
`issue_placement` at a branch with other content.
