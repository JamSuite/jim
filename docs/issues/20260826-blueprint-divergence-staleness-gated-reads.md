---
id: 20260826-blueprint-divergence-staleness-gated-reads
num: 387
title: "Blueprint divergence: staleness-gated-reads"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:44:33Z
updated: 2026-08-26T02:44:33Z
origin: "docs/specs/issue/014-read-view-filter-composition"
---

## Description

resolved: fix the code

## The invariant

> A read builds a current index where it can — gated on staleness in the working
> tree, unconditionally on a materialized copy, whose mtimes encode extraction
> order rather than edit history. A view served from an index that could not be
> rebuilt is disclosed on stderr and carries a non-zero status; a write refuses
> instead, so a stale index never reaches the destination.

## What diverges

The read-view filter work introduced a second class of staleness: an index whose
mtime is perfectly current but whose *schema* predates the widened row. It also
introduced the disclosure that catches it — rows present, none carrying a kind,
and a filter naming one of the blanked fields. That disclosure covers three axes
and one verb. The invariant's promise covers neither boundary.

## Reproduced

Against a collection whose index predates the widening and is newer than every
issue file, holding one issue with `claimed-by: "holder@example.test"`:

```
$ render.sh list --claimed-by holder@example.test <dir>
rc=1   refuses, names the repair          <- covered

$ render.sh list unclaimed <dir>
rc=0   lists the held record as unclaimed <- wrong answer

$ render.sh list claimed <dir>
rc=0   _No matching issues._              <- wrong answer

$ render.sh stats --filed-by dev@example.test <dir>
rc=0   Open: 0 · Closed: 0                <- wrong answer
```

The `unclaimed` case is the worst of the three: not an empty result that a
reader might question, but a populated one that positively misreports a record's
state.

## Why the two gaps exist

They are the same gap seen twice.

- The bare words `claimed` / `unclaimed` bind an axis named `held`, while the
  guard enumerates the axis keys `type`, `filed-by`, `claimed-by`. `held` reads
  the very `claimed-by` field the guard exists to protect, under a different
  key, so the enumeration misses it.
- The guard lives inside the list view's row loop. The census view shares the
  parser, the matcher and the row reader with it, but not this.

## Where

- `skills/issue/scripts/render.sh:1048-1061` — the guard and its axis
  enumeration
- `skills/issue/scripts/render.sh:778-787` — `held_matches`, reading the same
  blanked field
- `skills/issue/scripts/render.sh:501-633` — the census view, with no
  equivalent

## Fix shape

Both gaps close together. The condition is already computed from state the row
loop keeps (`seen_rows`, `saw_type`); lifting the check into a helper that both
verbs call, and adding `held` to the enumeration, covers every axis that reads a
row scalar on both surfaces.

Worth deciding at the same time: whether an ad-hoc column naming one of those
fields should disclose too. It currently renders a blank column at status 0,
which is the same indistinguishable emptiness one surface further out — tracked
separately.

No test exercises either gap; the staleness fixture the guard's own case builds
drives only the list view and only two of the covered axes.
