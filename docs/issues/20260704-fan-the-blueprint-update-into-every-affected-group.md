---
id: 20260704-fan-the-blueprint-update-into-every-affected-group
num: 41
title: "Fan the blueprint update into every affected group"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, cross-group]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T08:08:23Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/006-contract-graph/spec.md
---

## Description

## Context

Restores a deferral that went dangling. Spec 030's Out of Scope deferred
multi-group updates to "issue #19/#21": #19 closed when spec 033 shipped, and
[[20260630-add-the-cross-group-contract-graph-and-blast-radius]] (#21)'s
spec (034) explicitly re-excludes fan-out ("it joins the resulting faces, it
does not fan updates out"). Surfaced during 034 scoping.

## What

Spec 030's targeted update refreshes **one group per run** — a change
spanning several groups silently updates only the target group's blueprint.
The blocker 030 named ("a file→group mapping jim does not yet have") is now
solved: spec 033's territory declarations map changed paths to groups.

Fan the update out:

- Determine the affected groups from the change's paths via the map's
  territory declarations (re-validating each path through
  `jimfile.sh valid-relpath` at use).
- Run the existing targeted per-group update for each affected group —
  reusing the 030 update core, its 031 guard, and its commit discipline
  unchanged; fan-out is orchestration, not a new update mechanism.
- 034's blast radius enriches the consumer side: a provides-face change in
  one group names the consumer groups whose blueprints may need refreshing
  even when the diff never touched their territory.

## Depends on

Spec 033 (territory declarations — shipped). Consumer-side enrichment
arrives with spec 034; path-based fan-out is buildable now.
