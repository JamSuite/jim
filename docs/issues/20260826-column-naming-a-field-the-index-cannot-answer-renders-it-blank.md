---
id: 20260826-column-naming-a-field-the-index-cannot-answer-renders-it-blank
num: 388
title: "Column naming a field the index cannot answer renders it blank"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, disclosure]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:55Z
updated: 2026-08-26T08:53:47Z
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

## Resolution

Fixed in `9f292f0`, in the same diff as
[[20260826-blueprint-divergence-staleness-gated-reads]] — the two were one
enumeration short of one rule, and fixing either alone would have left the
other looking deliberate.

`schema_gate` takes the query's column selection alongside its axes and applies
the same membership test: a column names its row field directly, so a selection
naming a gated field refuses exactly as a filter naming one does. One rule for
both surfaces, and the operator gets the same one-command repair either way.

The refusal covers this run's explicit `--cols` ask only. A configured
`issue_list_cols` still degrades and serves the view, which is the split the
column vocabulary already makes between a flag that refuses and a standing
setting that falls back — a setting that could make the collection unreadable
is a setting no view could get past.

Pinned by `case_issues_render_unanswerable_column_refuses`, which loops
`COL_TOKENS` from the code's own declaration and separately pins the configured
default's degradation.
