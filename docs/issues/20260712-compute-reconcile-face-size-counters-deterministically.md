---
id: 20260712-compute-reconcile-face-size-counters-deterministically
num: 74
title: "Compute reconcile face-size counters deterministically"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition, blueprint, reconcile, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-12T09:55:16Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/016-partition-health/plan.md
---

## Context

Surfaced while building spec 044 (partition-health sensors). The reconcile
pass's § Reconcile Step 2a (blueprint SKILL.md) has the LLM count `provides`
rows from `jimverify.sh faces <group-blueprint>` per blueprint-bearing group to
produce the finished event's `faces=` (sum) and `faces_max=` (max), capture the
group(s) at that max as `faces_max_group=`, and derive `fanin_group=` from the
health verb's `FANIN_GROUP` rows.

## The gap

`reconcile-methodology.md` § Outcome counters states the contract plainly:
*"every counter is a script-emitted value, never a value lifted from content."*
The four finding/health counters honor this — `jimverify.sh health` emits them
and the skill copies the sanitized integers verbatim. But the two face counters
and their attribution keys do **not**: `jimverify.sh faces` emits per-entry TSV
for one group, so producing `faces=`/`faces_max=`/`faces_max_group=` requires
the LLM to run the verb per group and aggregate — a sum, a max, sorted
comma-joined tie handling, and the ≤256-byte cap. That is LLM arithmetic
assembling a security-relevant, shape-validated value, not a copied integer.

This was a deliberate plan decision (spec 044 DD #4 chose Step 2a LLM counting),
so it is out of scope for that plan — but it is a real deviation from the
"script-emitted" doctrine and from the mechanical-over-judgment principle, and
the attribution slug-list (sorted, comma-joined, tie → all, slug-validated,
length-capped) is exactly the kind of value that belongs in a script.

## Proposed action

Add a deterministic aggregator — e.g. a `jimverify.sh faces-aggregate <map>`
verb (or a jimpartition helper) that reads each blueprint-bearing group's faces
and emits `FACES_TOTAL`, `FACES_MAX`, and `FACES_MAX_GROUP` (the sorted
comma-joined max holders) in one call — and have Step 2a copy those values
verbatim onto the finished event, the same way it copies the health counters.
`fanin_group=` is already derivable from the health verb's `FANIN_GROUP` rows;
fold it into the same mechanical path if convenient. `reconcile-series` /
`last-reconcile` already validate the keys on extraction, so this only tightens
the producer side.
