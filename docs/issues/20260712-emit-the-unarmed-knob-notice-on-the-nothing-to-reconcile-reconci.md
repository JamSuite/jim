---
id: 20260712-emit-the-unarmed-knob-notice-on-the-nothing-to-reconcile-reconci
num: 75
title: "Emit the unarmed-knob notice on the nothing-to-reconcile reconcile"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [blueprint, partition, health]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-12T10:12:32Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/016-partition-health/review.md
---

## Description

## Context

Surfaced by the post-build review of spec 044 (partition-health sensors) as
Finding 1 (`docs/specs/blueprint/016-partition-health/review.md`), alignment
`minor-drift`.

## The gap

AC #5/#6 require the reconcile report to note in one line that the hook is
unarmed whenever `require_health` / `auto_health` is truthy but no valid
threshold is configured — "the fail-open knob is never invisible." The health
hook is gated **full-run path only** (`skills/blueprint/SKILL.md:431`), and the
nothing-to-reconcile short-circuit (a project with fewer than two
blueprint-bearing groups) skips straight to close
(`skills/blueprint/SKILL.md:399-401`). So on that path a truthy-but-unarmed
health knob produces **no unarmed-knob notice**.

Impact is narrow: no threshold crossing is possible on the short-circuit path
(health counters ride as `na`, `breaking=0`), so the only observable miss is the
single advisory line — and only on a sub-threshold project. But that is exactly
where a misconfigured operator would most benefit from being told "health knobs
set but you don't have enough groups yet."

## Proposed action

Either:

1. Surface the unarmed-knob notice from the nothing-to-reconcile branch too —
   resolve `require_health` / `auto_health` there and, if either is truthy, emit
   the one-line "health knobs set but no thresholds configured — hook unarmed"
   notice (there are no thresholds to cross on that path, so the notice is
   unconditional when a knob is truthy); or
2. Tighten AC #5/#6's wording to scope the unarmed-knob notice to the full-run
   path, making the current behavior correct by definition.

A one-line skill-prose change to `skills/blueprint/SKILL.md`; no script change
is needed. Low priority — the feature targets multi-group projects, so the gap
only bites during the sub-two-group ramp-up.

## Resolution

Closed via **proposal 2** — the AC over-promised relative to the mechanism it
governs. The unarmed notice is a property of the health hook, and the health
hook is by construction a full-run-path construct
(`skills/blueprint/SKILL.md:431`); the nothing-to-reconcile note already covers
health on the short-circuit path
(`skills/blueprint/references/reconcile-methodology.md:354-356`). Scoping the AC
to the full-run path makes the current behavior correct by definition, and the
guarantee "the fail-open knob is never invisible" is honored the moment a
project crosses into two-plus groups — the first run on which health can
structurally fire.

Proposal 1 was rejected: as written it would emit "no thresholds configured —
hook unarmed" unconditionally on the short-circuit path, misattributing the
cause for an operator who *did* configure thresholds (nothing fires there
because there are fewer than two groups, not because thresholds are missing). A
faithful version would add knob resolution and a bespoke message to the cheap
fast-exit branch to cover a transient, structurally-inert window — not worth the
cost.

AC #5 and AC #6 in `docs/specs/blueprint/016-partition-health/spec.md` now scope the
unarmed notice to the full-run path.
