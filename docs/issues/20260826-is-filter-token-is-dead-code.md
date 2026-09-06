---
id: 20260826-is-filter-token-is-dead-code
num: 391
title: "is_filter_token is dead code"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, cleanup]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:19Z
updated: 2026-08-26T10:25:41Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## What

`is_filter_token` in `skills/issue/scripts/render.sh` has no callers. It had
three before the read-view filter work: the stray-token guard in `cmd_list`, a
comment reference, and the single-argument branch of `dir_given`.

## How it got here

The filter work widened it (adding the kind and derived-predicate vocabularies
to its membership test) in the task that built the grammar, then removed its
last caller in the task that put routing and binding on one grammar. The
widening and the orphaning happened in different commits, so neither one looked
like a deletion.

## Why it is worth removing rather than leaving

It is the *old* guard — the narrow membership test whose use in `dir_given` is
exactly what produced the routing defect that work fixed. Leaving a widened,
callerless copy of it in the file gives a future reader something that looks
like the live vocabulary gate and is not. The real gate is `parse_filters`,
reached through `named_collection`.

## Fix shape

Delete the function. Confirm with a repository-wide grep first — the only
remaining mentions are in this spec's own artifacts and one filed issue, all
describing the historical bug rather than calling the code.

## Resolution

Fixed in `da7bd34`. The function is deleted.

The repository-wide grep the fix shape asked for was run first and confirmed
the reading: one occurrence in code — its own definition — and every other
mention in this spec's artifacts or a filed issue, all describing the
historical routing bug rather than calling the code.

`in_list` and the five token arrays it wrapped are untouched and still live:
`parse_filters` reads all five through `in_list` directly, and `cmd_list`
reads `COL_TOKENS` and `RENDER_OPTIONS` the same way. The deletion removed the
wrapper, not the vocabulary.

Nothing mechanically pins this. A callerless function is not a behaviour a
test can assert about, and the suite was green with it present — 1617 before
and after. What made it findable was a reviewer reading the file rather than
running it, which is the same lesson the increment's retrospective records.
