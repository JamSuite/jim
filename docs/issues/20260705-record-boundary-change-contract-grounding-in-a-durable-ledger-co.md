---
id: 20260705-record-boundary-change-contract-grounding-in-a-durable-ledger-co
num: 57
title: "Record boundary-change contract grounding in a durable ledger counter"
status: open
priority: medium
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:10Z
updated: 2026-07-05T22:44:10Z
origin: docs/specs/jim/037-verify-contracts/review.md
---

## Description

Spec 037 AC #9 (and the revised 2026-07-05 decision) require unattended
boundary-change grounding findings to "land in … the run's durable record." The
grounding runs and never gates the write (correct), but its outcome is not
durably counted:

- The boundary-change trigger `--contracts <group> --entries` records nothing
  itself — the caller owns durability (`skills/verify/SKILL.md`, the suppression
  rule).
- The blueprint `finished` ledger event carries only `violations=/folded=/fixed=`
  (`skills/blueprint/SKILL.md`) — no edge counter.
- Only the *review-sensor* path records `edges_checked=/edge_violations=`
  (`skills/verify/SKILL.md`, the scoped-adapter finished event).

So the boundary-change trigger's engine grounding is surfaced in the prompt/summary
but not attributable in any durable ledger record.

**Proposed action:** append `contract_edges=`/`contract_violations=` (or reuse
`edges_checked=`/`edge_violations=`) to the `blueprint finished` event when the
boundary-change trigger ran, mirroring the review-sensor path.

Surfaced by the spec 037 post-build review (`docs/specs/jim/037-verify-contracts/review.md`, Finding 1).
