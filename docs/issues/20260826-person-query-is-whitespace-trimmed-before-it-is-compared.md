---
id: 20260826-person-query-is-whitespace-trimmed-before-it-is-compared
num: P-20260826-person-query-is-whitespace-trimmed-before-it-is-compared
title: "Person query is whitespace-trimmed before it is compared"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, identity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:44Z
updated: 2026-08-26T02:34:44Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`filter_axis_add` trims leading and trailing whitespace from every filter value,
with no exception for the person axes. A recorded identity that the configured
form cannot judge *because of* edge whitespace is therefore unreachable by the
one route the spec promises for it.

## The criterion at stake

> A contributor value the configured form cannot judge stays reachable by naming
> it exactly, so the records the re-normalization skips do not become
> unfilterable.

## Reproduce

A record holding `filed-by: " alice"` — reachable through hand-edited
frontmatter, or through a filer recovered from version-control history. The
leading space is outside `IDENTITY_CHARS`, so `normalize` refuses it and
`ident_form` falls back to the raw value, spaces included. The operator does the
one thing the criterion tells them to do:

```
$ render.sh list --filed-by " alice" <dir>
```

`filter_axis_add` strips the space before the value is ever stored, so the
comparison becomes `ident_form("alice")` — which normalizes cleanly to
`"alice"` — against the record's raw `" alice"`. No match.

## Why the trim exists

It is right for every other axis: `--priority high, critical` should not bind an
alternative named `" critical"`. The trim is about the comma-separated list's
own formatting, not about the values.

## Fix shape

Trim only around the delimiters rather than around the whole value — that keeps
`high, critical` working while leaving `" alice"` intact. Alternatively exempt
the two person axes, though that is the weaker fix: it leaves the same trap for
any future axis whose values are compared literally.

Narrow in reach: only records whose identity is unjudgeable *specifically*
because of edge whitespace are affected. Records unjudgeable for any other
reason are still reachable exactly as the criterion promises.
