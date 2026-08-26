---
id: 20260826-render-sh-comments-still-cite-spec-and-finding-ids
num: P-20260826-render-sh-comments-still-cite-spec-and-finding-ids
title: "render.sh comments still cite spec and finding ids"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:57Z
updated: 2026-08-26T01:36:57Z
origin: "docs/specs/issue/014-read-view-filter-composition/plan.md"
---

## Description

## What

`skills/issue/scripts/render.sh` carries eight code comments citing spec, AC and
Finding numbers. The project's bash-script conventions forbid this, and give the
reason: these scripts' own `rename` and `split` verbs renumber the very specs an
ID points at, so the reference rots the moment the thing it names moves.

## Where

```
skills/issue/scripts/render.sh
  :29    against this closed set (security 019 Finding 3); anything else errors.
  :32    filesystem path from raw input (security 019 Finding 1).
  :334   to <default> (security 019 Finding 5). The caller resolves <value> from
  :1138  Bounded allowlist for a full issue id (spec 021 AC #7, AC #11).
  :1177  A provisional ordinal is never rendered as a settled #N (spec 010 AC 9).
  :1255  subagent (spec 020). Emits to stdout (LC_ALL=C stable ordering):
  :1283  related-to and duplicates are ordering-neutral and ignored (spec 020 AC5).
```

Line 12 also carries a bare `(AC-R3)`.

Every one of these predates the read-view filter work; the two that sat inside
functions that work re-authored were removed at the time.

## Why it is worth doing

Two of the ids are already at risk in the ordinary course: this collection's own
spec group has renumbered directories before, and the citation sweep that
follows a rename touches markdown artifacts, not code comments. Nothing checks
these, so they rot silently and a later reader trusts a number that now names
something else.

## Fix shape

Delete the parenthetical id from each, keeping the sentence. Every one of these
comments states a behavior and then attributes it; the behavior is the part that
earns its place, and the attribution is what the convention says does not.

Worth checking the sibling scripts in the same pass — `index.sh`, `new.sh`,
`transition.sh` and `migrate.sh` are likely to carry the same shape, and doing
one file at a time invites the sweep to be forgotten half-done.
