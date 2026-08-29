---
id: 20260801-design-the-repair-path-for-registry-internal-contradictions
num: 200
title: "Design the repair path for registry-internal contradictions"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [stride-tampering, id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T22:36:01Z
updated: 2026-08-02T01:07:27Z
origin: docs/specs/platform/012-registry-integrity-and-drift/spec.md
---

## Description

## Description

The registry-integrity sweep (platform/012) reports mismatch-class drift
(tree and registry disagreeing about an identity) and registry-internal
contradictions (duplicate ordinals, duplicate durable ids) — and correctly
scopes their repair out: choosing a winner is an operator decision, and the
catch-up verb appends only.

What remains: the operator's only concrete recourse for a reported
contradiction is hand-editing the push-writable coordination branch — the
same unsanctioned surgery the catch-up verb exists to eliminate for the
append case, with the added hazards that the erosion baseline must be
re-armed and append-only history must not be rewritten.

## Proposed action

Design the sanctioned repair path for registry-internal contradictions.
Candidate shapes, to be decided wherever this lands:

- a precedence or tombstone record kind (a grammar extension — coordinate
  with the rename-record emission work, Spec B),
- a documented manual procedure (a destructive-repair checklist covering the
  CAS push, the erosion-baseline re-arm, and a post-repair sweep),
- or a guarded repair verb behind preview/apply.

Surfaced by the plan-phase security review of platform/012 (security.md
finding 9): detection without a repair story invites exactly the ad-hoc
edits the registry's guarantees depend on avoiding.

## Addendum — 2026-08-02: the detection half shipped, and the class list grew

`platform/012` shipped the detection this issue was scoped against, so the
condition it describes is now reportable rather than invisible. The sweep names
four registry-internal contradiction classes, one more than this issue
anticipated:

- `duplicate-ordinal` — one ordinal claimed twice,
- `duplicate-id` — one durable id claimed twice,
- `reserved-slot` — a record for the reserved blueprint slot,
- `unreadable-record` — a record that claims an identity but carries a field the
  id boundary rejects, so the claim can never be compared against the tree.

The fourth is new and belongs in this issue's scope: it is unrepairable by the
same argument as the others (the operator must decide what the record was meant
to say), and `catch-up` now names it and exits non-zero rather than reporting
success over it.

One class this issue does **not** yet cover, and should: a duplicated spec
realize key — two records sharing `(group, slug, date)`. The realize path halts
on it, no verb can clear it, and the sweep cannot even name it today. Tracked
separately as issue 203; whichever repair path is designed here should account
for it.
