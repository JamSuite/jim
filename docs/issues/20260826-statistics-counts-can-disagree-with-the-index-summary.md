---
id: 20260826-statistics-counts-can-disagree-with-the-index-summary
num: 395
title: "Statistics counts can disagree with the index summary"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:45Z
updated: 2026-08-26T02:34:45Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`index.sh` and `render.sh` now classify a record's lifecycle state at different
points in the sanitizing pipeline, so the two can report different counts for
the same collection.

- `index.sh` compares the **raw** frontmatter value when it builds the
  `## Summary` block's Open/Closed counts.
- `render.sh stats` compares the **sanitized** value it reads back out of the
  Issues row.

`row_safe` strips control characters between those two points.

## Reproduce

An issue whose frontmatter carries `status: "closed<0x01>"` — a `closed`
followed by a control byte, which is not whitespace and so is not trimmed:

```
$ grep -E '^- (Open|Closed):' <dir>/INDEX.md
- Open: 1
- Closed: 0

$ render.sh stats <dir>
  Open: 0 · Closed: 1
```

Two numbers for one collection, in and beside one file.

## How it arrived

The read-view filter work moved `stats`'s counts off the index's Summary lines
and onto the rows, so that a filtered and an unfiltered census would be one code
path rather than two. That is the right shape — but the previous code echoed the
Summary verbatim and therefore could not disagree with it, and the new code can.

## Which one is right

Arguably `render.sh`'s: the sanitized value is what every reader of the index
sees, and it is what every other view already acts on. The divergence is the
problem rather than either number.

## Fix shape

Compare the sanitized value on both sides — `index.sh` would classify from
`row_safe`'s output rather than the raw scalar. That is a one-line change with a
wide blast radius (it moves the Summary numbers for any collection holding such
a value), so it wants its own test.

Requires an embedded C0 control byte in a frontmatter scalar to observe, so this
is adversarial or corruption-shaped input rather than an ordinary typo.
