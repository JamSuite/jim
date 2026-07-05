---
id: 20260705-guard-the-contracts-check-edge-loop-against-self-edges
num: 61
title: "Guard the contracts-check edge loop against self-edges"
status: closed
priority: low
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:13Z
updated: 2026-07-05T22:55:35Z
origin: docs/specs/jim/037-verify-contracts/review.md
---

## Description

`cmd_contracts_check` (`skills/verify/scripts/jimverify.sh`) skips self-pairs
(`C==P`) in its `CROSS-REF` scan loop, but the graph-edge outcome loop has no
equivalent guard. A self-edge persisted in the `## Contract Graph` (consumer ==
provider) would run the provider-ref/consumer-ref pattern checks over the same
group's own territory.

Not a security issue — it relies on the reconcile writer never emitting a
self-edge, which today holds — but a cheap robustness guard against a malformed
or hand-edited graph.

**Proposed action:** add `[[ "$C" == "$P" ]] && continue` to the edge loop,
mirroring the existing CROSS-REF self-pair skip.

Surfaced by the spec 037 post-build review (`docs/specs/jim/037-verify-contracts/review.md`, Finding 5).

---

**Folded into [[20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin]] (#62)** — closed 2026-07-05; the fix lands there as a checklist item.
