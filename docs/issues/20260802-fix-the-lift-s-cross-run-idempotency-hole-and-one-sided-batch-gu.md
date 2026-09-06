---
id: 20260802-fix-the-lift-s-cross-run-idempotency-hole-and-one-sided-batch-gu
num: 207
title: "Fix the lift's cross-run idempotency hole and one-sided batch guard"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, lift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T21:35:10Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

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

## Resolution (2026-08-05)

The batch decision moved into `alloc_lift_states`, where the whole row set is
visible. Both sides are claims, recorded renames index both their sides, and the
decision is anchored in the log rather than in the publish builder's memory.
`alloc_lift_publish_builder` now appends `emit` rows as-is, so preview, payload
and published records are one computation.

Verified by execution against a real registry on both revisions. The cross-run
hole reproduces on `a000a70^` (second `--apply` writes the record the first
refused, two renames on one destination, exit 0) and is closed at HEAD (second
and third runs both refuse; one record ever; the orphaned source resolves to "not
allocated"). A reorder attack — ledger rows swapped between runs — is also
refused, because the decision is log-anchored rather than order-dependent. The
awk relabel is gone: the published row now reports `emit`. Preview and `--apply`
payloads are byte-identical across six ledger shapes.

The three shapes this issue named as untested are now pinned, including
`refused:duplicate-in-batch` (asserted at three sites). Residual fixture
coverage — five guards that survive deletion with the suite green, including the
cross-run *source* closure this issue's wording covers — is tracked separately.
