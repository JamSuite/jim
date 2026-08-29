---
id: 20260828-reconcile-the-census-container-headline-with-its-rollup
num: 414
title: "Reconcile the census container headline with its rollup"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [render, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:34Z
updated: 2026-08-28T20:26:31Z
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

## Resolution

Fixed in `b686454a`. The decision this record asked for was made the third way
it offered — scope the rollup's *roster*, leave its *numbers* alone.

**The file already answered the question twenty lines below.** The `== Blocking
==` rollup gates which sources appear on the filtered `matching` set and then
reports each one's complete outbound count. The umbrella rollup now does the
same: an umbrella whose own row the filter excluded is not named, and one it
admits carries its whole roster's progress rather than the filter's share of
it. That keeps the code comment above the block true — progress stays a
property of the umbrella, not of the query — while removing the population
mismatch with the headline.

The heading moved below the rows it introduces, because whether there is a
section at all is the *filtered* roster's answer. Rows accumulate through
`printf -v` rather than a command substitution per row, for the reason
`format_row` states about subshell cost.

**Pinned by** `case_issues_render_stats_rollup_is_scoped_like_its_headline`,
which carries its own negative control: the same collection under a query the
umbrella passes, asserting progress reads `1/2` and not the `0/0` a
member-scoped count would give when neither member matches. Mutation-verified —
deleting the one guard line turns it red on exactly the rollup assertion, with
the headline assertion still passing.

**Exercised against the real collection, not only the fixture.** On a copy with
one record marked `epic` and one member joined: unfiltered and under a query
the umbrella passes, headline and rollup both appear and progress reads whole;
under one it fails, both disappear together.

**Provenance unchanged from what was filed.** This was the build's, not the
remediation pass's — the headline was filter-scoped and the rollup unfiltered
from the start. The fix that made the rollup enumerate umbrella rows widened
the population that could hit it, and that fix stays.
