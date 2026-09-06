---
id: 20260825-negation-in-read-view-filters
num: 382
title: "Negation in read-view filters"
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

The read views' filters are all inclusions. There is no way to express "every
open issue *except* the ones labelled flake", or "work I did not file".

## History

Deferred twice, both times deliberately:

- The originating brainstorm listed negation in its filtering design and marked
  it "deferred — not in the first cut".
- The read-view filter composition spec carried that forward into its Out of
  Scope, stating that its combining rules are defined for inclusions only.

## Why it is not free

The combining rules are the reason. Inclusions compose as "OR within an axis,
AND across axes", which is simple to state and simple to predict. Adding
exclusions raises questions that rule does not answer:

- Does an exclusion bind to its axis or to the whole query?
- What does naming both an inclusion and an exclusion on one axis mean —
  `--label auth --label !flake` is coherent, `--label auth --label !auth` is not.
- Does an exclusion widen the result when it is the only filter given?

None of these are hard, but they need deciding rather than falling out, which is
what kept it out of the first cut.

## Suggested shape

Whatever spelling is chosen, the rule that unrecognized bare words are refused
should extend to it, so a mistyped exclusion fails loudly rather than being read
as an inclusion of a strange-looking value.
