---
id: 20260712-add-partition-stage-metrics-to-the-review-ledger-allowlist
num: 73
title: "Add partition stage metrics to the review ledger allowlist"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [ledger, review, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-12T08:06:17Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/016-partition-health/plan.md
---

## Context

Surfaced while planning spec 044 (partition-health sensors). `/jim:partition`
records first-class stage events on the specs-root ledger — `partition
started`/`finished tier=project` since spec 038, `op=rename` since spec 043,
`op=health` since spec 044, `op=split` since spec 047, and `op=merge` since
spec 048 — but
`jimledger.sh`'s per-stage metrics
allowlist (`LEDGER_STAGES`, consumed by `cmd_metrics`) still reads `spec
research plan sec build review blueprint verify`. The events are durable and
parse fine via the generic `event` verb; they are simply invisible to the
metrics channel.

## What

Add `partition` to the fixed per-stage metrics allowlist so `/jim:review`'s
process metrics report partition stage runs, interruptions, and durations
like every other instrumented stage. Additive one-word change to the
allowlist (the fixed-key discipline is unchanged — key names stay literals,
never derived from ledger text) plus a `tests/jimledger.sh` case asserting
`partition_runs`/`partition_duration_seconds` emit over a fixture ledger.
