---
id: 20260825-sort-and-group-read-views-by-the-newly-indexed-fields
num: 385
title: "Sort and group read views by the newly indexed fields"
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
created: 2026-08-25T10:51:05Z
updated: 2026-08-25T10:51:05Z
origin: "docs/specs/issue/014-read-view-filter-composition/spec.md"
---

## What

The read-view filter composition spec widens the collection's index to carry
every record's kind, filer, holder, outcome, and umbrella membership, and makes
each of them filterable and displayable. It deliberately leaves sorting and
grouping alone.

## The follow-on

Once those fields are in the index rows, sorting and grouping by them costs
almost nothing:

- group by filer or holder — "whose backlog looks like what"
- group by outcome — the finished work split by how it finished
- group by kind — issues and epics separated once epics exist
- sort by holder or filer for a stable per-person read

## Why it was held back

Filtering and grouping are independent surfaces, and bundling them would have
widened a spec that already spans composition, the axes, columns, statistics,
and the index substrate. The substrate change is the expensive half and it
lands first; this is the cheap half that rides on it.

## Dependency

Blocked on the read-view filter composition spec landing the widened index
rows. Nothing to do before then.
