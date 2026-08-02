---
id: 20260802-fix-the-lift-s-cross-run-idempotency-hole-and-one-sided-batch-gu
num: P-20260802-fix-the-lift-s-cross-run-idempotency-hole-and-one-sided-batch-gu
title: "Fix the lift's cross-run idempotency hole and one-sided batch guard"
status: open
priority: critical
labels: [id-coordination, registry, lift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:10Z
updated: 2026-08-02T21:35:10Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

Two defects in `jimalloc.sh`'s `lift`, both in the batch guard. Reproduced.

**1. The guard leaves no trace, so a second run writes what the first refused.**
`alloc_lift_publish_builder:3591-3596` tracks emitted destinations in an
in-memory `batch_dst` array. Given two ledger pairs landing on one destination,
each corroborating on its own:

- Run 1 emits the first, reports `refused:duplicate-in-batch` for the second,
  exits 1.
- Run 2 reports the first as `have` — and **emits the second**, exiting 0.

The registry ends up holding both `spec rename aa/001 core/001` and
`spec rename bb/002 core/001`: exactly the contradiction the guard exists to
prevent, reached by re-running an operation whose stated contract is that
re-running is safe (AC 12: "The lift is idempotent"). The `have` keys are
anchored on record presence, which is correct; the refusal is anchored on
nothing.

**2. The guard is destination-only.** `batch_dst` keys on `kind + dst`, so two
rows sharing a *source* both emit:

- `a→X` and `a→Y` writes two rename records from one source, after which
  `alloc_resolve_spec:578-582` refuses `a` permanently ("vacated by more than
  one rename record and allocated by none"). On an append-only branch that is
  unrecoverable — one extra crafted pair beside a genuine one makes a legacy
  citation unresolvable forever.
- `P→X` and `P→Y` writes two `spec realize` records for one provisional.

The sibling emitter guards both sides — `alloc_partition_spec_publish_builder:3242`
checks `seen_old` **and** `seen_new`. The asymmetry reads as an oversight.

## Why this is first

The host-side backfill is a `lift` run over `docs/specs/ledger.md`. Both defects
are in the path that backfill takes. Neither is reachable from the current
ledger's contents (all 54 pairs have distinct sources and destinations), so the
backfill is safe to run today — but the guard should hold before the verb is
used a second time or against a ledger anyone else can write.

## Proposed action

Anchor the batch decision in the log rather than in memory: recompute the emit
set so that a destination (or source) already claimed *by an earlier record in
this same batch* is refused on every run, not just the first. Key `batch_dst` on
source as well as destination, matching the partition builder. A second run must
report `refused:` for the same rows the first refused.

Also: when two rows are byte-identical, the awk relabel at `:3592-3593` marks
the **already-emitted** row as refused, so the payload reports a pair as refused
that the same commit published, and `cmd_lift` returns 1 on a run that wrote it.

Neither shape has a test; `refused:duplicate-in-batch` is untested entirely.

Surfaced by the post-build review of blueprint/025 (findings 1 and 2).
