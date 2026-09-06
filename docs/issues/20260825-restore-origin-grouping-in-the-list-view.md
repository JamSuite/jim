---
id: 20260825-restore-origin-grouping-in-the-list-view
num: 383
title: "Restore origin grouping in the list view"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, read-views]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T10:50:58Z
updated: 2026-08-25T10:50:58Z
origin: "docs/specs/issue/014-read-view-filter-composition/spec.md"
---

## What

`issue_list_group=origin` silently degrades to a flat, ungrouped list.

## Why it happens

`read_issue_rows` in `skills/issue/scripts/render.sh` emits `origin` as the
eighth field of every row it produces. `cmd_list` reads that field into a
variable and then drops it when packing the row it keeps:

```
rows+=("$slug"$'\t'"$num"$'\t'"$status"$'\t'"$prio"$'\t'"$created"$'\t'"$labels"$'\t'"$title")
```

The group-order switch then treats `origin` as equivalent to `none`, under a
comment stating that "the list rows carry no origin column (origin lives in
stats clustering)". The rows do carry one — it is discarded one line earlier.

## Effect

A developer who sets `issue_list_group=origin` gets a flat list with no error,
no warning, and no indication the setting had no effect. `stats` groups by
origin correctly, which makes the `list` behavior read as intentional.

## Fix shape

Carry `origin` into the packed row and add the group-order case. The value is
already parsed, so no new parsing is involved.

## Scope note

Deliberately left out of the read-view filter composition spec, whose Out of
Scope keeps sorting and grouping unchanged.
