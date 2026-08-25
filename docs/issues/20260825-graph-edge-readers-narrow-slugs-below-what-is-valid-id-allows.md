---
id: 20260825-graph-edge-readers-narrow-slugs-below-what-is-valid-id-allows
num: 381
title: "Graph-edge readers narrow slugs below what is_valid_id allows"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, read-views, latent]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T11:06:36Z
updated: 2026-08-25T11:06:36Z
origin: "docs/specs/issue/014-read-view-filter-composition/research.md"
---

## Description

## What

Two readers of the index's Graph section match issue slugs with `[a-z0-9-]+`,
which is narrower than the ids the collection actually accepts. Every edge
touching an id outside that set is silently dropped — no warning, no count, no
indication the surface is incomplete.

## Where

- `skills/issue/scripts/render.sh:324` — the `stats` blocking rollup
- `skills/issue/scripts/render.sh:703` — `cmd_insights_graph`

Both regexes bracket the source and target slug of a rendered edge line.

## The mismatch

`is_valid_id` (`skills/issue/scripts/render.sh:560`, byte-identical to the
copies in `index.sh` and `jimfile.sh`) allows:

```
^[A-Za-z0-9][A-Za-z0-9._-]*$
```

Uppercase letters and dots are legal in an id and illegal in the edge readers.

## When it bites

`issue_id_prefix=project` is a supported prefix scheme, and `ARCHITECTURE.md`
cites `JIM-` as an example of it alongside `0042-` and sub-day timestamps. A
project configured that way gets a blocking rollup and an insights graph that
quietly omit every edge involving a prefixed id.

This collection is entirely lowercase date-prefixed ids, so the defect is
latent rather than live here. It is live for any project using an uppercase
project prefix.

## Why it is worth fixing rather than noting

The read-view filter composition spec adds `blocked` / `unblocked` and
`--epic`, both of which read the same Graph section. Left alone, the pattern
becomes a third and fourth copy rather than two.

The group already carries a `cross-copy-lockstep` invariant for exactly this
class of problem — a guard duplicated across files, with a marker naming its
siblings and a test asserting they agree. This pattern has neither.

## Fix shape

Widen both regexes to the id charset, or extract the edge-line parse into one
helper both callers use. If the copies stay separate, they want a sync marker
so the next divergence fails a test rather than reaching production.
