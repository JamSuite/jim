---
id: 20260826-test-coverage-gaps-around-the-new-read-view-surfaces
num: P-20260826-test-coverage-gaps-around-the-new-read-view-surfaces
title: "Test-coverage gaps around the new read-view surfaces"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, tests, read-views]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:35:25Z
updated: 2026-08-26T02:35:25Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

Six behaviors of the new read-view surfaces are correct by code trace but pinned
by no test case. Each was confirmed during the post-build review; none is a
defect. They are listed together because they are one class — the edges the
build's own cases did not reach.

## The gaps

1. **`stats` with a filter that matches nothing.** The list view's
   empty-match case is covered; the census view's is not. Its exit status
   depends on the trailing `if` with no `else`, which is correct but unasserted.
2. **`--cols` as the only argument.** The closed-hidden disclosure correctly
   does *not* fire, because `--cols` is a display option rather than a filter
   axis. Nothing asserts that it stays that way.
3. **`stats --filed-by me`.** The scope line reports the *resolved* identity
   rather than the literal `me`, because `resolve_person_axes` rewrites the axis
   before `scope_line` reads it. That is the more precise disclosure and almost
   certainly right — but no case exercises `stats` with a person filter at all.
4. **A `depends-on` target absent from the collection.** Reads as unblocked.
   Tracked separately as its own issue; noted here because the *test* gap is
   part of this class.
5. **`insights-graph` excluding a `depends-on`-only node from `BLOCKING`.** The
   existing case asserts the node is not isolated but never asserts it is absent
   from the blocking rollup, so the type gating is unpinned.
6. **`type: ""` and `filed-by: ""`.** The omission case exercises empty
   `claimed-by` and `outcome` only. The code path is shared across all four, so
   this is asymmetry rather than risk.

## Why file it rather than let it ride

Each is cheap to close and the fixtures already exist — most need one extra
assertion against a fixture the suite builds anyway. Left unlisted, they are the
gaps a later change walks into: items 1 and 3 sit exactly where the census view
would next be extended.

## Fix shape

Add them as the surrounding code is next touched, rather than as a batch. Item 5
is the one worth doing on its own, since it pins a type-gating property that a
future edge-reader refactor could silently drop.
