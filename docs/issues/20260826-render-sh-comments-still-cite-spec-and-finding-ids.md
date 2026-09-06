---
id: 20260826-render-sh-comments-still-cite-spec-and-finding-ids
num: 393
title: "render.sh comments still cite spec and finding ids"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:57Z
updated: 2026-08-26T10:26:25Z
origin: "docs/specs/issue/014-read-view-filter-composition/plan.md"
---

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

## Resolution

Fixed in `0d7c820`, swept across the whole group rather than `render.sh`
alone — the fix shape's own warning about a half-done sweep turned out to
describe the majority of the work.

The distribution was not where the report looked. `render.sh` held 6 of the
34; `index.sh` held 10, `new.sh` 7, `migrate.sh` 6, `backfill.sh` 5 and
`reconcile.sh` 3. `place.sh`, `transition.sh` and `identity.sh` carried none.
Two of the `render.sh` lines this issue cited by line number were already
gone, rewritten by the three fixes that preceded this one — so the count here
was stale by two before the sweep started.

One id resisted a single pattern: `new.sh` spelled it `spec-017` with a
hyphen rather than a space, and the first sweep missed it. The pattern that
found everything admits both forms. Two shapes had to be excluded as false
positives — `cut -f1` matches a bare `F<n>`, and a bare `#<n>` matches both
the prose example `"close issue #5"` in `place.sh` and the legitimate
`settled #N` in `render.sh`.

Each edit deletes the attribution and keeps the sentence. Four comment
paragraphs are rewrapped where the deletion left a short line mid-block.

**Not closed by this:** the convention is project-wide, and three scripts in
two other groups still carry ~58 citations — `jimverify.sh` (46, mostly its
usage header), `jimconf.sh` (11) and `jimalloc.sh` (1). Nothing checks any of
this, which is how they accumulated. The sweep and the missing check are
filed together as
[[20260826-spec-and-finding-ids-in-comments-outside-the-issue-group]] (#401).
