---
id: 20260725-give-retired-group-directories-a-sanctioned-end-of-life
num: 106
title: "give retired group directories a sanctioned end-of-life"
status: open
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:22:51Z
updated: 2026-07-25T08:22:51Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

Under `spec_migration = rewrite` the split's covenant is that no cruft or stale reference survives a group move — yet retirement's terminal state leaves the retired group's directory in place forever: docs/specs/jim/ still holds the retired 000-blueprint (spec.md + ledger.md), and 30 deliberately-kept `jim/000` typed references across moved spec bodies pin it there. Deleting it by hand would dangle those references and discard the group's ledger history, so the archive home is currently load-bearing cruft with no sanctioned disposal path.

Design a retirement end-of-life story consistent with the rewrite covenant, e.g.: collapse a retired group to a single tombstone artifact (banner + map pointer + absorbed or relocated ledger), run the reference sweep against the retired slot so `<old>/000` mentions re-point to the tombstone or the map, and teach the health identity-check the pruned state. Route the design through /jim:spec — the disposal must stay a gated, ledger-recorded operation, not an rm.
