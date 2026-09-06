---
id: 20260826-person-query-is-whitespace-trimmed-before-it-is-compared
num: 392
title: "Person query is whitespace-trimmed before it is compared"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, identity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:44Z
updated: 2026-08-26T20:47:54Z
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

## Resolution

Fixed in `d63357d` (the query side) and `2a22a21` (the row reader). Two seams
trimmed, not one, and the half this record describes was the reachable half.

**The reproduce above does not reproduce.** `filed-by: " alice"` was already
reachable before either commit — by `alice` *and* by `" alice"`.
`read_issue_rows` consumed `key:` plus any run of whitespace, so the record
read back as `alice`, and the query's own trim landed on the same string.
Two trims cancelling is why the leading-whitespace case looked broken by
reading and was not.

**The unreachable class is trailing whitespace, and it was worse than filed.**
The row preserves it and only the query trimmed it, so `filed-by: "bob "`
matched *no* spelling:

```
--filed-by 'bob '   → _No matching issues._
--filed-by 'bob'    → _No matching issues._
```

Not "reachable only by naming it exactly" — unfilterable, which is the outcome
the criterion forbids in as many words.

**The rule adopted.** The comma is the operator's own separator, so it is also
the only place whitespace is formatting: beside a comma it spaces the list out,
at the operand's own edge it is part of the value that was typed. An
alternative that is nothing but whitespace names no value and is dropped.

That last clause is load-bearing, not tidiness. The edge trim is what let an
operand of separators and spaces reach zero alternatives and be refused, which
is the whole of the `#390` guard. Removing the trim without replacing the way
an alternative reaches zero would have made `'   '` a recordable alternative
matching nothing at status 0 —
`case_issues_render_operand_naming_no_alternative_refuses` fails on exactly
that, and the two fixes are not independent the way the remediation assumed.

**The second seam was fixed here because it is the same disagreement one
surface further in, and wider than identity.** With `type: " issue"`, `index.sh`
judges the sanitized scalar, finds no member, and records

```
- `20260101-alpha` unrecognized type:  issue.
```

in its Integrity Warnings — while `list --type issue` trimmed the row's value
into a member and handed that record back as one of the recognized ones.
`--priority high` did the same. The writer already holds that the value
classified and the value displayed are one; the reader did not. Consuming
exactly the one space the emitter writes is the inverse of the row format, so a
value's own edges belong to the value.

**Pinned by two cases.**
`case_issues_render_list_person_axis_edge_whitespace_named_exactly` asserts the
exact spelling reaches the record, the trimmed one does not, the whitespace-only
operand still refuses, and — both directions — that a value's edge survives a
list while the whitespace beside a comma does not.
`case_issues_render_row_scalars_read_back_as_written` asserts the index's own
warning and the view's answer agree about `type` and `priority`, and that the
two identity spellings reach one record each.

**Blast radius, measured:** no row in this repository's 402-record collection
carries a leading-space scalar, so neither commit moves anything here.

**Not closed by this.** An identity recorded as nothing but whitespace stays
unreachable — a whitespace-only operand refuses, and keeping `#390`'s guard was
worth more than that case. And a value carrying edge whitespace is namable at a
list's own edges, not beside its commas: `--filed-by 'carol, bob '` reaches
both records, `--filed-by 'bob , carol'` reaches only `carol`.
