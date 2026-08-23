---
id: 20260705-assert-edge-outcome-evidence-is-location-only-in-contracts-check
num: 59
title: "Assert edge-outcome evidence is location-only in contracts-check tests"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [verify, contract-graph, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-05T22:44:11Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/009-verify-contracts/review.md
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

Surfaced by the spec 037 post-build review (`docs/specs/blueprint/009-verify-contracts/review.md`, Finding 3).

---

**Folded into [[20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin]] (#62)** — closed 2026-07-05; the fix lands there as a checklist item.
