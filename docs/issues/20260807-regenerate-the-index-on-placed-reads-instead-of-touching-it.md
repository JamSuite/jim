---
id: 20260807-regenerate-the-index-on-placed-reads-instead-of-touching-it
num: P-20260807-regenerate-the-index-on-placed-reads-instead-of-touching-it
title: "Regenerate the index on placed reads instead of touching it"
status: open
priority: high
labels: [issue, placement, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:26Z
updated: 2026-08-07T11:43:26Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`place_materialize` ends by `touch`ing `INDEX.md` so it is the newest entry in
the materialized directory, which makes `render.sh`'s mtime staleness gate
always report fresh.

That is sound only while the premise holds — "every write publishes a current
index" — which is true for anything routed through `place_reindex` and false for
content that reaches the destination branch any other way: a teammate committing
an issue file without regenerating, a merge of two branches, a bulk import.
After any of those, every clone materializes the branch, touches the stale
index, and serves a view that omits the issue — permanently, until some write
happens to trigger a regen.

Before placement the same drift bumped the directory mtime and forced a rescan.
The `touch` trades that signal for a saved rescan.

This is the in-change violation of the group blueprint's `staleness-gated-reads`
invariant, resolved fix-code at the blueprint fork — the invariant's wording
stands and the code is what should change.

## Proposed action

Regenerate the index unconditionally inside the read-only materialized directory
instead of asserting freshness by `touch`. The directory is discarded, so a read
still commits nothing — the property that matters is preserved, and the mtime
signal stops being falsified.

Cost is one index regeneration per placed read, which is the same work the
staleness gate would have done had the mtimes been meaningful.
