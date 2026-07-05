---
id: 20260705-test-the-consumer-ref-abstain-on-absent-path-in-contracts-check
num: 58
title: "Test the consumer-ref abstain-on-absent path in contracts-check"
status: closed
priority: medium
labels: [verify, contract-graph, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:11Z
updated: 2026-07-05T22:55:35Z
origin: docs/specs/jim/037-verify-contracts/review.md
---

## Description

`contract_ref_check` (`skills/verify/scripts/jimverify.sh`) abstains — emits no
record — when a `consumer-ref` pattern is absent from consumer territory. This is
the deliberate provider/consumer asymmetry: a `provider-ref` absence is
`violated` (code-level breaking), but a `consumer-ref` absence is not a violation
(a consumer not exercising a surface falls to the judge, not a breach).

No test exercises this abstain path. A regression that flipped consumer-ref
absence to `violated` (or `failed`) would pass the entire current suite —
`tests/jimverify.sh` only covers the consumer-ref *holds* case
(`case_jimverify_contracts_consumer_holds`).

**Proposed action:** add a `contracts_repo` variant whose consumer code lacks the
declared usage, and assert the consumer side emits **no** edge record for that
edge (not `violated`, not `failed`).

Surfaced by the spec 037 post-build review (`docs/specs/jim/037-verify-contracts/review.md`, Finding 2).

---

**Folded into [[20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin]] (#62)** — closed 2026-07-05; the fix lands there as a checklist item.
