---
id: 20260725-give-retired-group-directories-a-sanctioned-end-of-life
num: 106
title: "give retired group directories a sanctioned end-of-life"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-25T08:22:51Z
updated: 2026-07-26T06:49:23Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

Under `spec_migration = rewrite` the split's covenant is that no cruft or stale reference survives a group move — yet retirement's terminal state leaves the retired group's directory in place forever: docs/specs/jim/ still holds the retired 000-blueprint (spec.md + ledger.md), and 30 deliberately-kept `jim/000` typed references across moved spec bodies pin it there. Deleting it by hand would dangle those references and discard the group's ledger history, so the archive home is currently load-bearing cruft with no sanctioned disposal path.

Design a retirement end-of-life story consistent with the rewrite covenant, e.g.: collapse a retired group to a single tombstone artifact (banner + map pointer + absorbed or relocated ledger), run the reference sweep against the retired slot so `<old>/000` mentions re-point to the tombstone or the map, and teach the health identity-check the pruned state. Route the design through /jim:spec — the disposal must stay a gated, ledger-recorded operation, not an rm.

Concrete instance (surfaced while resolving [[20260725-script-preamble-rule-vs-source-inherited-preambles-fix-or-fold]]): the retired jim/000-blueprint/spec.md still carries the full `script-preamble` invariant row (its Invariants table has ~20 rows), while the live platform blueprint that inherited that territory deliberately withheld the same rule. So the retired blueprint is not merely dangling references — it holds authoritative-looking invariant rows that duplicate, and can silently contradict, the live partition's decisions (a withheld-in-platform rule still reads as held here). Any tombstone/collapse design must neutralize the retired blueprint's Invariants/Provides/Requires tables, not just re-point `<old>/000` prose mentions: a stale invariant row reads as live doctrine to a human or a verify judge. This strengthens the case for collapsing the whole spec.md body to a tombstone rather than leaving it in place with only its references swept.
