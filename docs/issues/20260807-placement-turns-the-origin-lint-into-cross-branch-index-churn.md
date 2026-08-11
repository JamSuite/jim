---
id: 20260807-placement-turns-the-origin-lint-into-cross-branch-index-churn
num: 273
title: "Placement turns the origin lint into cross-branch index churn"
status: closed
priority: medium
labels: [issue, placement, index]
relations:
  blocks: []
  depends-on: []
  related-to: [20260811-compute-checkout-dependent-index-warnings-at-read-time]
  duplicates: []
created: 2026-08-07T11:43:57Z
updated: 2026-08-11T01:32:24Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`index.sh`'s origin lint resolves `origin:` paths against the *invoking* CWD,
and `place.sh` deliberately never `cd`s (so the wrapped command keeps the
primary checkout as its working directory). Under placement those two facts
combine: the lint runs against whichever developer's checkout triggered the
reindex, while writing into the **destination's** `INDEX.md`.

Developer A on `feat/x` files an issue with `origin: docs/brainstorms/x.md`, a
file that exists only on `feat/x`. Developer B, sitting on `main`, closes any
issue. B's mutation triggers `place_reindex`; the lint cannot resolve A's path
in B's tree and appends

```
- `<slug>` origin path does not resolve: docs/brainstorms/x.md (created ...)
```

to the published index, which `render.sh stats` then shows every reader.

Nothing is blocked and rc stays 0, so the AC's letter ("the reference is
informational and its absence is not an error") holds. The mechanical fact is
that centralization converts a per-branch lint into cross-branch churn: the
warning set is a function of which branch the last mutator stood on, so it flips
on and off, and each flip is a real `INDEX.md` diff — meaning a bare `index.sh`
run from a different branch now produces a non-empty reindex commit.

## Why the existing test does not catch it

`case_issues_placement_tolerates_a_branch_only_origin` creates the origin file
in the working tree before filing, so the path resolves and no warning fires.
The AC's actual scenario — an origin that exists only on the filing branch — is
untested.

## Proposed action

Decide what the lint means under placement. Either gate it off when the
collection is materialized (the invoking CWD is not the collection's branch, so
the check has no ground truth), or resolve origins against the destination
branch's tree rather than the caller's checkout. Then fix the test to use a
genuinely dangling origin.
