---
id: 20260828-membership-doubles-the-index-graph-section
num: 408
title: "Membership doubles the index graph section"
status: open
priority: medium
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
created: 2026-08-28T05:17:23Z
updated: 2026-08-28T05:17:23Z
origin: "docs/specs/issue/015-epic-authoring-and-views/plan.md"
---

## Description

## Description

## What

Every umbrella membership renders twice in `INDEX.md`: once as a `part-of` edge
in `## Graph`, and once as a roster line in the `## Epics` section the epic
increment adds. The two cannot disagree — both derive from frontmatter in one
pass — so this is a size question, not a correctness one. But the sizes are not
close, and the larger half is the one nobody chose.

## The measurement

Taken against the real collection while planning the epic increment. Modelling
full adoption — each of the 46 originating spec directories becomes an umbrella
and all 311 spec-derived issues join one:

| | |
| :--- | :--- |
| `INDEX.md` today | 167,041 bytes |
| `## Graph` today | 21,783 bytes across 145 edges (**150.2 bytes/edge**, measured) |
| `part-of` edges added | **+46,703 bytes — +28.0%** |
| `## Epics` section, whole | 13,313 bytes uncapped (+8.0%); 12,641 capped (+7.6%) |

Membership costs roughly **four times** in raw edges what it costs in the
section built to make it legible. The roster cap the increment adds bounds the
smaller half.

## The question

`## Graph` is the complete membership record, and the epic increment leaned on
that deliberately: the roster is capped precisely because the full list is
permanently one section down. So the two are not redundant today — the cap
depends on the duplication.

What is worth deciding is whether that remains the right trade once the section
exists. Three shapes, none obviously correct:

- Leave it. The Graph stays the complete record and the section stays a
  convenience. Costs +28% of a committed artifact that regenerates on every
  write and is read by everyone who opens the repository.
- Drop `part-of` from `## Graph` and make the section the complete record,
  removing the cap. Cheaper, but re-opens the unbounded-entry problem the cap
  exists to close, and `read_graph_edges` currently serves `part-of` to
  `build_derived_axes`, so the `--epic` filter would need a second source.
- Keep both and bound the Graph instead, which nothing currently does.

## Why it was not in the epic increment

The increment's spec settled what the new section renders and explicitly did
not re-open what the Graph renders. Changing the Graph would alter an existing
read seam with five call sites, for a benefit that only materializes under
adoption that has not happened yet. Filed rather than folded in.
