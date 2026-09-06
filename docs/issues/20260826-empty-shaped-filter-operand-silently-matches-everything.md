---
id: 20260826-empty-shaped-filter-operand-silently-matches-everything
num: 390
title: "Empty-shaped filter operand silently matches everything"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, filters]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:18Z
updated: 2026-08-26T08:54:30Z
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

## Resolution

Fixed in `95d56cc`, together with the flag-shaped half
([[20260826-unrecognized-flag-is-accepted-as-a-flag-s-value]]).

`filter_axis_add` now reports when an operand yielded no alternative at all,
and the parser refuses rather than leaving the axis key unassigned. That was
the whole mechanism: every matcher reads an unassigned axis as one nobody
named, so the narrowing flag the operator typed arrived as a widening query at
status 0 — and on a read surface a wide answer and a large one look the same.

`--label ,,,` and `--label '   '` refused; the refusal quotes the operand, so
an operand that is invisible on the terminal is still legible in the message.

A third case in the same family closed with it: an operand carrying a newline
was silently cut at the first line, because an axis stores its alternatives
newline-separated and the break cannot be told from the separator. It now
refuses.

Pinned by `case_issues_render_operand_naming_no_alternative_refuses`, which
loops `RENDER_OPTIONS` from the code's own declaration and drives every axis
flag on both read verbs, rather than the one flag the defect was found on.
