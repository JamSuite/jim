---
id: 20260827-report-an-honest-completion-rate-from-the-outcome-field
num: 406
title: "Report an honest completion rate from the outcome field"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, read-views, metrics]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-27T20:10:31Z
updated: 2026-08-27T20:10:31Z
origin: "docs/specs/issue/015-epic-authoring-and-views/spec.md"
---

## What

`stats` reports completion as closed over total. That counts abandoned and
superseded work identically to work that was finished, which is the exact
overstatement the `outcome` field was introduced to remove.

## Why it is now cheap

The two halves already exist:

- The schema increment added `outcome` (`done` / `wontfix` / `duplicate` /
  `obsolete`) and made it required at close, defaulting to `done`.
- The read-view increment records `outcome` on every index row, so the census
  can read it without a second parse surface.

Nothing consumes it. The field is populated on every closed record and no view
reports it.

## The follow-on

Report completion as `done / closed` rather than `closed / total`, and surface
the non-`done` buckets separately rather than folding them into a single
finished count. The brainstorm that produced this line of work stated the
rationale: a pile of `wontfix` says scoping is too generous, and a pile of
`obsolete` says the backlog rots faster than it drains. Both are health signals
in their own right, not noise to be hidden.

## Caveat carried from the conversion

The one-time conversion recorded every pre-existing closed record as `done`
without auditing its history, so the metric is honest prospectively and flat
across the converted past. Worth stating wherever the number is displayed, so a
reader does not mistake a backfilled `done` for an observed one.

## Why it was not in the epic increment

Epic progress counts members finished against members held, and deliberately
says nothing about *how* they finished. Reading outcome into a rate is a
separate question that applies to the whole collection rather than to umbrellas,
so bundling it would have widened a spec that already spans authoring, views,
counting and the index section.
