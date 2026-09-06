---
id: 20260807-regenerate-the-index-on-placed-reads-instead-of-touching-it
num: 276
title: "Regenerate the index on placed reads instead of touching it"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:26Z
updated: 2026-08-12T09:15:00Z
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

## Resolution (backfilled 2026-08-12)

*Closed by the fix pass in `5de0c70`; this note is reconstructed from that pass's
commits, which recorded the resolution in trailers alone.*

Fixed in `2aa2e1d`. The materialized collection's index is regenerated rather
than touched, so a destination whose index arrived stale — by a hand commit, or a
merge the emitter never saw — is not served as current. Content reaches the
destination by routes the emitter never sees, and before this every clone served
a view with such an issue missing until some later write happened to trigger a
regen.

The regeneration runs inside the discarded temp copy, so a read still commits
nothing, and it runs after the base snapshot is taken, so a write publishes the
correction rather than measuring its changed set against it.

Pinned by `case_place_read_serves_a_current_index` and
`case_place_write_publishes_a_corrected_index` in `tests/place.sh`.

**Failure handling settled later.** What a read should do when that regeneration
*fails* was not decided here; the group carried two postures until this
remediation chose one — see
[[20260808-placed-reads-hard-fail-where-the-group-read-path-is-tolerant]].
