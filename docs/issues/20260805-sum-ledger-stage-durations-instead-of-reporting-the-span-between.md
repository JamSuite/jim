---
id: 20260805-sum-ledger-stage-durations-instead-of-reporting-the-span-between
num: 252
title: "Sum ledger stage durations instead of reporting the span between first and last"
status: open
priority: medium
labels: [ledger, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:33Z
updated: 2026-08-05T22:20:33Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

`jimledger.sh metrics` reports `<stage>_duration_seconds` as the span from the
first `started` to the last `finished`, not the sum of the runs.

`skills/ledger/scripts/jimledger.sh:930-931`: `se` takes the first `started`
(`exit` after the first match), `fe` takes the last `finished`.

```
bash skills/ledger/scripts/jimledger.sh metrics docs/specs/platform/000-blueprint
  blueprint_runs=16   blueprint_duration_seconds=922440
  verify_runs=12      verify_duration_seconds=920816

true sum of the 12 verify runs: 6816 s   (135x overstated)
the run under review:            769 s
```

Isolated reproduction: two 100-second runs ten days apart report
`verify_duration_seconds=864100`.

This is correct on a spec ledger, where a stage runs once, and wrong on every
blueprint ledger — which is precisely the ledger `/jim:verify` and
`/jim:blueprint` write repeatedly, and the one whose numbers a reader would use to
reason about verification cost.

The value is also the only ledger number `metrics` surfaces for these stages: the
channel iterates a fixed code-literal stage list and never reads the payload
field, so `checked`, `holds`, `violated`, `failed`, `undelegated`, `violations`,
`folded` and `fixed` are all invisible there (visible through `events`). That part
is by design; this part is arithmetic.

## Proposed action

Sum the per-pair durations — accumulate `finished - started` across matched pairs
— rather than subtracting the first start from the last finish. Leave unmatched
events out of the sum and report the run count as it already does.

Fixture a two-run ledger with a long gap and assert the duration is the sum, not
the span.
