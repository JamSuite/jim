---
id: 20260828-reconcile-the-census-container-headline-with-its-rollup
num: 414
title: "Reconcile the census container headline with its rollup"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [render, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:34Z
updated: 2026-08-28T11:37:34Z
origin: "docs/specs/issue/015-epic-authoring-and-views/review.md"
---

## Description

`render.sh`'s `cmd_stats` prints two things about umbrellas, and they describe
different populations.

- The `Epics: N open · M closed` headline is accumulated inside the row loop,
  **after** the filter gate — so it is scoped to the query.
- The `== Epics ==` rollup reads the shared derivation, which re-reads the
  index unfiltered — so it is not.

Under a filter an umbrella's own row fails, the headline vanishes while the
rollup still names that umbrella with its full progress.

## Reproduction, with a negative control

A collection holding `20260101-umbrella` (`type: epic`, `priority: high`) and
one member (`priority: low`):

    $ render.sh stats <dir>
      Epics: 1 open · 0 closed
      == Epics ==
        20260101-umbrella    0/1 closed

    $ render.sh stats --priority low <dir>
      (no Epics: line at all)
      == Epics ==
        20260101-umbrella    0/1 closed

## Provenance

Reproduced identically against pre-remediation `render.sh`, so this is the
build's, not the fix pass's. The rollup was unfiltered from the start and the
headline was filter-scoped from the start.

The fix that made the rollup enumerate umbrella rows rather than edge targets
did not cause this, but it widens the population that can hit it: before, only
an umbrella with members could appear in the rollup at all.

## The decision to make

Which population does the block describe? The code comment above the rollup
already asserts one answer — "progress is a property of the umbrella rather
than of the query, so it is not scoped by the filter" — and the headline does
not follow it. Either scope both to the query or scope neither, but a census
should not name an umbrella in its rollup that its own container line declines
to count.
