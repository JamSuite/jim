---
id: 20260805-pin-verify-s-finished-event-key-set-by-rule-so-a-dropped-counter
num: 242
title: "Pin verify's finished-event key set by rule so a dropped counter cannot pass"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [verify, ledger, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:24Z
updated: 2026-08-05T22:20:24Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

The `verify finished` event recorded by `caf741d` carries no `edges_checked=` or
`edge_violations=`:

```
docs/specs/platform/000-blueprint/ledger.md
  verify finished checked=11;holds=7;violated=3;failed=1;unconfigured=0;skipped=0;undelegated=0
```

Every existence condition for the contract-edge phase held: the contract graph at
that commit names `platform` as provider on 12 edges, and the change set included
`jimalloc.sh`, `jimledger.sh` and the meta-test framework — all `platform`
**Provides** entries. `skills/verify/SKILL.md:89,289` require the counters when
the phase runs, and the immediately preceding run recorded
`edges_checked=4;edge_violations=3`.

So the record cannot distinguish "the contract-edge phase did not run" — an
undisclosed degradation — from "it ran and its counters were dropped". That is
the exact failure mode `undelegated=` was added to foreclose one rung over.

Nothing holds the event to these keys. `tests/fanoutdisclosure.sh:76` sweeps only
doc-surface *recitations of the command* (its corpus globs `skills/*/SKILL.md`,
`references/`, `assets/`, `agents/`), never a `ledger.md` line, and nothing at all
guards the edge counters — which is why this landed silently.

Two adjacent gaps in the same record, worth deciding alongside:

- `failed=1` has no recoverable reason. The reason lives only in the non-durable
  VERIFY-OUTCOME block; the ledger grammar has no reason field. With
  `undelegated=0` ruling out a suppressed fan-out, `registry-tree-consistency` is
  the coherent candidate by the `--since` adapter's own rule, but that is
  inference, not record — and both notes describe the run as "found three real
  defects", silent on the invariant that could not be checked.
- The judge count is not recorded anywhere. Nine is inferable from the blueprint's
  rung split with `skipped=0`, not read.

## Proposed action

Pin the finished event's key set by rule rather than by site — a recitation or a
real event missing a required counter fails — extending the mechanism
`tests/fanoutdisclosure.sh` already uses for `undelegated=`, so a new counter
cannot be dropped silently.

Decide whether `failed=` should carry a reason in the durable record. A
could-not-check outcome that leaves no trace of *what* could not be checked is the
degradation the outcome vocabulary exists to make legible.
