---
id: 20260825-graph-edge-readers-narrow-slugs-below-what-is-valid-id-allows
num: 381
title: "Graph-edge readers narrow slugs below what is_valid_id allows"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issues-system, read-views, latent]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T11:06:36Z
updated: 2026-08-27T21:17:27Z
origin: "docs/specs/issue/014-read-view-filter-composition/research.md"
---

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

## Resolution

Fixed in `4ab67dc`, during the increment that filed this record. The record
stayed open because nothing closed it, not because anything was left undone.

`read_graph_edges` (`skills/issue/scripts/render.sh:484-502`) replaced both
narrow readers with one that matches the validator's character class, and
carries at its definition the reason the laxer form is right there: an edge
slug is only ever compared against a row slug, never composed into a path and
never opened, so the emptiness check, length cap and `..` rejection that
`is_valid_id` adds are not what this path needs.

**Pinned by** `case_issues_render_graph_edges_match_id_charset`
(`tests/issues.sh:7505`), added in the same commit. Run at close: passes.

**Verified against the rule, not against the two sites this record named.**
A census of every slug character class under `skills/` finds two deliberate
families, and the boundary between them holds:

- The **id** class `^[A-Za-z0-9][A-Za-z0-9._-]*$` governs issue ids. Every
  reader of one now uses it — `index.sh:112`, `render.sh:492`, `render.sh:1316`
  and the platform copy at `jimfile.sh:207`.
- The **slug/group** class `^[a-z0-9][a-z0-9-]*$` governs spec slugs and group
  names, and is narrower on purpose. `jimfile.sh` carries both — `:176` for a
  slug, `:207` for an id — which is what shows the split is intentional rather
  than drift.

`render.sh` is also the only reader of the index's `## Graph` section; the
other matches for that heading are the writer in `index.sh` and a header
comment. So the five current graph reads share one seam, and this record's
defect class has no remaining instances.

**What this record got right and where it was narrow.** Its analysis was
accurate and its latent/live distinction held — the defect was inert for this
collection's lowercase date-prefixed ids and live for a project on an uppercase
prefix. What it could not know is that the fix would land inside the same
increment. Its `## Where` section named `render.sh:324` and `:703`; those line
numbers no longer point at graph readers, because the file grew by roughly 450
lines during the remediation. A reader checking this record against current
code by line number would find unrelated statements there, which is why the
census above is stated against the rule rather than the sites.
