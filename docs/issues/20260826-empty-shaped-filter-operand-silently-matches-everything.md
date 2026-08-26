---
id: 20260826-empty-shaped-filter-operand-silently-matches-everything
num: P-20260826-empty-shaped-filter-operand-silently-matches-everything
title: "Empty-shaped filter operand silently matches everything"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, filters]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:18Z
updated: 2026-08-26T02:34:18Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

A filter flag whose operand is present but yields no alternative — `,,,`,
`   `, or a value that is only separators — leaves its axis key unassigned.
Every matcher tests `[[ -n "${FILTER_AXIS[$axis]:-}" ]] || return 0`, so an
unassigned axis reads exactly like an axis nobody named: the filter silently
becomes a no-op that matches everything.

## Reproduce

Two issues, one labelled `auth`, one labelled `other`:

```
$ render.sh list --label auth <dir>      -> 1 match   (correct)
$ render.sh list --label ,,, <dir>       -> 2 matches, rc 0
$ render.sh list --label '   ' <dir>     -> 2 matches, rc 0
```

The operator typed a narrowing flag and received a widening one, with nothing
on stderr and a successful exit.

## Why it matters here specifically

This is the failure the file's own `need_operand` commentary argues against, in
its own words: *"the flag that was consumed goes unapplied, and the value it
became is one nobody typed — and on a read surface both halves are silent,
because a narrower query and a query that matched little look the same."*
`need_operand` catches the absent and flag-shaped cases; the present-but-empty
case slips past it and lands in `filter_axis_add`, which drops every empty
field and then assigns nothing.

A related shape: an operand containing a literal newline is truncated at the
first line, because `IFS=',' read -ra vals <<< "$csv"` reads one line. The
remainder is discarded without a word.

## Fix shape

`filter_axis_add` knows how many alternatives it added. Refuse when a flag was
given and the count is zero — the flag was typed, so its axis should never
vanish. The same check covers the newline case if it counts what it actually
stored rather than what it was handed.

Worth deciding deliberately: whether a bare word can reach this state too. It
cannot today (bare words are matched against fixed vocabularies before they
reach `filter_axis_add`), so the refusal belongs on the flag path.
