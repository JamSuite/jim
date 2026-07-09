---
id: 20260705-record-boundary-change-contract-grounding-in-a-durable-ledger-co
num: 57
title: "Record boundary-change contract grounding in a durable ledger counter"
status: closed
priority: medium
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:10Z
updated: 2026-07-09T09:46:35Z
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

## Resolution (2026-07-09)

**Reused `edges_checked=/edge_violations=`, did not mint `contract_*`.** The
`blueprint finished` event is a `jimledger.sh event` record — the same grammar
family as the scoped `verify finished` event, which already carries
`edges_checked=/edge_violations=` for this exact concept. One concept keeps one
name across the ledger's `finished` events. (`contract_violations` is a *review.md
frontmatter* field — a different layer, the mined artifact — not a ledger-event
key, so it was the wrong precedent to copy.)

Grounding pinned the site: the boundary-change trigger `--contracts <group>
--entries` fires only in **update mode**, grading a Provides weakening in Step 4a
(consume-first), and that stage closes at the **U4** `blueprint finished` event.
The fresh-generate finished (zeros) can't weaken anything, and a plain regenerate
has no such event — so the single conditional append site is U4.

Skill-authoring only — no script or test change: `jimledger.sh event` already
takes free-form trailing `k=v` (the verify path appends
`edges_checked=/inchange=/…` the same way).

Changes:

1. **`blueprint/SKILL.md`** — the U4 `finished` event now conditionally appends
   `edges_checked=/edge_violations=` when the Step-4a trigger ran; validation
   checklist updated. Kept SKILL.md at exactly 500 lines (the `skill-budget`
   invariant ceiling) by folding the mention tightly and moving the rationale to
   the reference — progressive disclosure, not budget breach.
2. **`blueprint/references/fork-grounding.md`** — new *Recording the
   boundary-change grounding (AC #9)* section carrying the counter definitions,
   the reuse-not-mint rationale, and why it mirrors the review-sensor path.
