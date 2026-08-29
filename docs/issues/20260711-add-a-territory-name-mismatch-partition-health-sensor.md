---
id: 20260711-add-a-territory-name-mismatch-partition-health-sensor
num: 71
title: "Add a territory-name-mismatch partition-health sensor"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition, health, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-11T09:10:28Z
updated: 2026-07-25T07:49:14Z
origin: docs/brainstorms/20260711-partition-migrate-capabilities.md
---

> **Resolved by spec 044 (partition-health sensors) — 2026-07-12.** Folded into
> 044 as the `jimpartition.sh identity-check` name-mismatch sensor (foreign +
> retired classes); shipped in `docs/specs/blueprint/016-partition-health/`.

## Description

## Context

The partition-migrate brainstorm resolved the code-move coupling fork for
`/jim:partition rename` as a user choice at the gate: *(a) move the code in
the same operation*, or *(b) docs-only* — rename everything jim owns while
identity-bearing territory paths keep truthfully pointing at the old-named
code directory, with the code move routed to the normal spec→plan→build
workflow as a tracked issue.

Arm (b) is doctrine-clean (the map never lies — present-tense doctrine
demands truth, not name-matching) but leaves a lingering smell: a group
whose name no longer matches the code directory its territory names. The
filed code-move issue is the primary mitigation, yet nothing *senses* the
mismatch if that follow-up stalls.

## What

Add a partition-health sensor that detects group-name/territory-path
mismatch — a mapped group whose territory paths embed a different group
identity token than the group's own name — and surfaces it as a
partition-health signal (a smell, never a doctrine violation).

Sibling of the split/merge signal family tracked in
[[20260704-add-partition-health-sensors-split-merge-signals]]; natural home is whatever surface
that issue lands on (e.g. alongside the reconcile graph-health block).
