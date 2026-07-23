---
id: 20260723-extend-present-tense-rule-to-spec-id-and-version-refs
num: 92
title: "Extend present-tense rule to spec-id and version refs"
status: open
priority: medium
labels: [blueprint, present-tense]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-23T20:23:16Z
updated: 2026-07-23T20:23:16Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

## Problem

The present-tense doctrine (`skills/blueprint/references/present-tense.md`) and
its exit-door self-scan — plus `/jim:verify`'s `present-tense` invariant (high) —
target historical / transitional / aspirational **framing** ("was introduced",
"will add", "formerly"). They say nothing about **point-in-time provenance
references**: spec IDs, spec ranges, and pinned version numbers.

This gap let a real violation ship and persist in the `jim` blueprint's
Responsibility / Provides / Structure sections, which described
`jimpartition.sh`'s verbs by the spec that introduced each ("the spec-043 rename
verbs", "the spec-047 split verbs", …), cited a stale spec range (`001–044`,
already wrong once the archive passed 044), and pinned `v2.0.0`. It passed
original authoring, the `present-tense` verify judge, and a
`/jim:blueprint --from-review` self-scan — which even *added* a fresh `spec-046`
reference before the omission was caught by eye.

Spec IDs are especially wrong in a blueprint: `/jim:partition`'s
rename/split/merge verbs **renumber specs**, so a `spec-047` reference rots the
moment the thing it names moves — the same rationale the script-comment rule in
`CLAUDE.md` already codifies ("No spec IDs … the reference rots the moment the
thing it names moves"). The blueprint describes current state; provenance is
neither current-state nor stable.

## Suggested action

Extend the present-tense rule (and its exit-door self-scan) to explicitly flag
and normalize point-in-time provenance in blueprint / map content:

- spec-ID / spec-range references (`spec-0NN`, `001–044`, `docs/specs/<g>/0NN`)
  → describe by function / current state, not by originating spec;
- pinned version numbers (`vX.Y.Z`) → name the manifest as the version's single
  source rather than copying the value.

Consider a mechanical assist — a `pattern`/`structure` floor check or a lint over
blueprint specs — so the obvious cases (`spec-0NN`, a bare `NNN–NNN` range) fail
deterministically without spending a judge, mirroring the prose-pin precedent.
Weigh against over-constraining legitimately-current descriptions (a verb's own
name, a functional grouping).

## Origin

Surfaced while correcting the `jim` blueprint during spec 051's
`/jim:blueprint --from-review` fold: the fold inherited pre-existing spec-ID
provenance and added a new one, and neither the self-scan nor the `present-tense`
judge caught it.
