---
id: 20260827-group-the-read-views-by-umbrella-membership
num: 405
title: "Group the read views by umbrella membership"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, read-views]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-27T20:10:36Z
updated: 2026-08-27T20:10:36Z
origin: "docs/specs/issue/015-epic-authoring-and-views/spec.md"
---

## What

The read views can filter by umbrella membership but cannot group by it. A
developer holding several umbrellas reads their work as one flat list and has to
separate it by eye.

## How this differs from the existing sort-and-group follow-on

There is already a record covering sorting and grouping by the fields the index
row gained — kind, filer, holder, outcome. This is not that record, and the
distinction is mechanical rather than editorial:

- Those are **row scalars**. Each record carries exactly one value, so grouping
  is a partition and every record lands in exactly one bucket.
- Umbrella membership is **a multi-valued edge**, stored on the member side and
  rendered into the index's Graph section rather than into a row field. A record
  can belong to several umbrellas or to none.

So grouping by umbrella is not a partition. A record in two umbrellas appears
under both, and a record in none needs a bucket of its own. That is a different
grouping contract from every existing option, which is why it needs its own
decision rather than riding along with the row-scalar work.

## Why it was held back

The epic increment scoped grouping out to keep its own surface bounded — it
already spans the write path, the containment rule, derived roster and progress,
the census change, and a new index section. Grouping is additive on top and
depends on nothing the increment does not already establish.

## Dependency

Blocked on the epic increment landing. Until umbrellas can be created, there is
no membership to group by.
