---
id: 20260826-is-filter-token-is-dead-code
num: P-20260826-is-filter-token-is-dead-code
title: "is_filter_token is dead code"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, cleanup]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:19Z
updated: 2026-08-26T02:34:19Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

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
