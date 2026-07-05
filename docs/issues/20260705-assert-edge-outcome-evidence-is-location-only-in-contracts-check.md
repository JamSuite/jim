---
id: 20260705-assert-edge-outcome-evidence-is-location-only-in-contracts-check
num: 59
title: "Assert edge-outcome evidence is location-only in contracts-check tests"
status: open
priority: medium
labels: [verify, contract-graph, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:11Z
updated: 2026-07-05T22:44:11Z
origin: docs/specs/jim/037-verify-contracts/review.md
---

## Description

The location-only guarantee (matched code content is never emitted, only
`file:line`) is asserted for `CROSS-REF` facts but **not** for the edge pattern
outcomes.

`case_jimverify_contracts_coverage_crossref_locationonly` greps the output for
`require` — a consumer-side token that appears only on the `CROSS-REF` match line
(`billing/invoice.js:1`). The provider/consumer *edge outcome* evidence comes
from different match lines (`getIdentity` on `accounts/session.js:1` and
`billing/invoice.js:2`), which that assertion does not cover. Dropping the
`cut -d: -f1,2` reduction in `contract_ref_check` would leak the full matched
line through the edge records, and every current test would still pass.

**Proposed action:** add a `grep -c 'function'` / `grep -c 'getIdentity'`
assertion (== 0) over the edge-outcome records so the edge evidence is locked to
`file:line`, closing the exfiltration-guard coverage gap for both record types.

Surfaced by the spec 037 post-build review (`docs/specs/jim/037-verify-contracts/review.md`, Finding 3).
