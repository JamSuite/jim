---
id: 20260826-column-naming-a-field-the-index-cannot-answer-renders-it-blank
num: 388
title: "Column naming a field the index cannot answer renders it blank"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, disclosure]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:55Z
updated: 2026-08-26T01:36:55Z
origin: "docs/specs/issue/014-read-view-filter-composition/plan.md"
---

## Description

## What

A read view refuses when a *filter* names an axis the index cannot answer, and
says nothing when a *column* names the same field. The two surfaces read the
same four fields off the same row and disagree about what to do when the row
does not carry them.

## Reproduce

Against a collection whose `INDEX.md` predates the widened Issues row — an index
newer than every issue file, so the staleness gate reuses it:

```
$ render.sh list --filed-by dev@example.test <dir>
error: the index for '<dir>' does not describe: filed-by
       it was written before those fields were recorded
       regenerate it with: bash .../index.sh '<dir>'
       if the records themselves predate the schema, convert them first
rc=1

$ render.sh list --cols num,filed-by,title <dir>
open (1)
  #1     -                      A
rc=0
```

The second is the failure the first exists to prevent, one surface over. A
column of `-` where every record carries a filer is indistinguishable from a
collection where nobody filed anything, and the view reports it as success.

## Why it is out of scope for the work that surfaced it

The disclosure was specified against axes: *"When a filter names an axis the
collection's index does not describe, the view says so and fails."* A column is
not a filter, so the guard was built to the letter of that and stops at the
axis list.

## Fix shape

The condition is already computed — `seen_rows > 0 && saw_type == 0` — and the
column selection is already validated against a token set. Extend the same check
to cover `FILTER_COLS` naming `type`, `filed-by`, `claimed-by`, or `outcome`.

Worth deciding deliberately: a *filter* that cannot be answered makes the whole
result wrong, while a *column* that cannot be filled makes one column blank and
leaves the rows correct. Refusing may be too strong — a disclosure line beside
the view, like the closed-hidden one, may fit the severity better. Either beats
silence.
