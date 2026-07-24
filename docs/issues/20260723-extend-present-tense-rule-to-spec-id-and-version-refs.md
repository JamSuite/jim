---
id: 20260723-extend-present-tense-rule-to-spec-id-and-version-refs
num: 92
title: "Extend present-tense rule to spec-id and version refs"
status: closed
priority: medium
labels: [blueprint, present-tense]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-23T20:23:16Z
updated: 2026-07-24T00:34:08Z
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

## Resolution

Resolved under spec `jim/052`
(`docs/specs/jim/052-blueprint-provenance-guard/`). Scoped as a feature spec,
built TDD, reviewed `aligned` (0 findings), and folded into the `jim` blueprint.

**Doctrine home — a separate companion doc, not a fourth present-tense
category.** Provenance is a distinct axis from tense: "the spec-047 verbs" reads
as present tense yet rots when `/jim:partition` renumbers, so it slips past all
three present-tense marker categories. The rule lives in a new
`skills/blueprint/references/provenance.md` (sibling to `present-tense.md`),
cited by path and scanned at the same exit door — keeping "tense" conceptually
pure.

**Flagged forms (this issue's core set).** Bare spec ids, spec ranges, mutable
numbered spec paths (excluding the reserved `000-blueprint`), and pinned
versions, each with its normalization (describe by function; name the manifest
as the version source). The broader `CLAUDE.md` artifact-ref set (AC / Finding /
DD / issue numbers, cross-file line ranges) is deferred to issue #93 — the
doctrine's "illustrative and extensible" framing already generalizes the
judgment scan to them; only the *mechanical* widening is deferred.

**Mechanical assist (as suggested).** A deterministic `tests/provenance.sh`
guard scans jim's own group blueprint spec and project map and fails on any
flagged form — the self-hosting regression guard, mirroring the prose-pin
precedent. Adversarially verified against edge cases (ids ≥ 100, all three dash
types, date/timestamp false-positives, the reserved-path mask). The
over-constraint guard spares a verb's own name, functional groupings, and
dates/counts.

**Wiring + enforcement.** The exit-door self-scan now runs both the
present-tense and provenance scans at all ten composition sites; jim's own map
was normalized *through* `/jim:blueprint` (the new scan flagged its own
boundary-rationale ranges — the feature dogfooding itself); and the
`present-tense` verify invariant was extended to sense a dropped provenance
citation the same way it senses a dropped present-tense one.

Verified: full suite 701/701 green; review `aligned`; living-intent sensor 0
violations. Ships on `feat/blueprint`.
