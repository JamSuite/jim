---
id: 20260828-a-relation-type-reaches-the-graph-unbounded-in-length
num: 407
title: "A relation type reaches the graph unbounded in length"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, index-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T05:17:25Z
updated: 2026-08-28T05:17:25Z
origin: "docs/specs/issue/015-epic-authoring-and-views/plan.md"
---

## What

`index.sh` `parse_relations` accepts any key under `relations:` as a relation
type, constrained by its own regex to `[a-z][a-z-]*` and by nothing else. The
Graph renderer then interpolates that token into a committed line without
passing it through the row sanitizer, so its length is bounded by nothing.

## What this is, and what it is not

It is **not** a containment escape, and the record should say so plainly rather
than leaving a reader to infer severity from the filing. The accepted class
admits no newline, no backtick, and not the row separator, so a relation type
cannot introduce a line, close a code span, or forge a field. Every structural
guarantee `INDEX.md` makes still holds.

What it is: an unbounded value from a hand-editable record reaching an artifact
that regenerates on every write and is committed. A record carrying a
thousand-character relation key produces a thousand-character edge line, once
per edge of that type, for every reader of the repository. Every other scalar
that reaches a row is capped at 512 characters by `row_safe`; this one is
capped nowhere.

## The narrower ask

Bound the type token. `row_safe` already exists and already runs on every other
value reaching the index; the edge renderer is the one path that skips it.

## The wider question, deliberately not the ask

`parse_relations` is type-agnostic on purpose — that is what let `part-of` be
added by the schema increment with no parser change, and the same property is
why the epic increment needed no work there. Whether an unrecognized relation
type should be *refused*, or warned about the way an unrecognized `type` and
`outcome` already are, is a separate design question with a real argument on
both sides. This issue asks only for the length bound, which has no such
argument against it.

## Where

`skills/issue/scripts/index.sh` — `parse_relations` (the awk program's
`^  [a-z][a-z-]*:` match) and the Graph render loop that composes
`` - `src` --type--> `tgt` ``. Line numbers deliberately omitted: the file grew
substantially during the preceding increment and coordinates in records filed
against it have already rotted once. Both sites are found by the symbol names.
