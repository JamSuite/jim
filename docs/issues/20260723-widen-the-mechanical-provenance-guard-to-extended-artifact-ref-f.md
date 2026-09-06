---
id: 20260723-widen-the-mechanical-provenance-guard-to-extended-artifact-ref-f
num: 93
title: "Widen the mechanical provenance guard to extended artifact-ref forms"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [blueprint, provenance]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T21:23:49Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/024-blueprint-provenance-guard/spec.md
---

## Problem

Spec 052's mechanical provenance guard covers spec-IDs, ranges, mutable spec
paths, and version pins. The `CLAUDE.md` script-comment rule (052's sibling
rationale) names a broader artifact-ref set that rots identically: AC numbers
(`AC 11`), Findings (`Finding 4`), DDs (`DD 9`), issue numbers (`#87` → `#92` on
merge), and cross-file line ranges (`jimledger.sh:204-227`).

## Current coverage

052's provenance doctrine frames its forms as "illustrative, extensible,
judgment-resolved" (mirroring the present-tense rule), so the judgment exit-door
self-scan already generalizes to these forms — a human authoring a blueprint gets
them flagged. What is deferred is adding them to the **deterministic** self-hosting
guard, not the doctrine. There is no doctrine hole.

## Suggested action

Evaluate widening the guard's grep patterns to the extended forms, weighing:

- **Low occurrence** — these artifact refs almost never appear in current-state
  blueprint/map prose (blueprints "capture the rule, not per-instance
  implementation," so a line range is already a template smell); versus
- **Higher false-positive surface** — `#NNN` collides with markdown headings,
  `AC`/`DD` are short prose tokens, and line-range patterns are noisier than
  052's clean set.

Likely outcome: keep AC/Finding/DD on the judgment scan only, and add a mechanical
arm for the two cleaner forms (`#NNN` with heading-exclusion, `file.ext:NNN-NNN`)
only if a real offender surfaces — a reactive widening, not preemptive.

## Origin

Surfaced during `/jim:spec` + `/jim:research` for spec 052
(`docs/specs/blueprint/024-blueprint-provenance-guard`), as the explicit Out-of-Scope
deferral of the full `CLAUDE.md` artifact-ref set.
