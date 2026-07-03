---
id: 20260703-build-the-partition-migration-skill
num: 34
title: "Build the partition migration skill"
status: open
priority: medium
labels: [migration, spec-groups, 000-blueprint]
relations:
  blocks: []
  depends-on: [20260630-build-intelligence-for-context-aware-spec-group-definition]
  related-to: []
  duplicates: []
created: 2026-07-03T20:08:37Z
updated: 2026-07-03T20:08:37Z
origin: docs/brainstorms/20260703-context-aware-spec-group-definition.md
---

## Description

## Context

The 20260703 brainstorm (origin) resolved the partition doctrine:
**opinionated vertical-first** bounded contexts, with the axis
(`vertical|layered`) and a code-territory mode
(`directory` / `declared-paths` / `none`) as config knobs. Existing jim
projects grew **layered** partitions (`foundation` / `storage` /
`dashboard`) before the blueprint concept existed — they need a supported
path onto the new doctrine.

## What

A migration capability (skill for the reasoning, script for the mechanics)
that moves a project onto a chosen partition/mode:

- **Re-partition (layered → vertical):** propose a new context map from the
  existing specs, blueprints, and code; interview to refine; materialize it
  in `BLUEPRINT.md`. Freeze-history doctrine applies: numbered specs are
  point-in-time artifacts and stay where they are — only living artifacts
  (the map, group blueprints, future spec filing) migrate. No reference
  rewriting.
- **Territory-mode upgrades (`none` → `declared-paths` → `directory`):**
  each step strengthens the mechanical verification floor; the `directory`
  step implies code moves, so it is proposed as a reviewable plan, never
  auto-applied.

LLM reasoning is required for the re-partition proposal (boundary judgment);
the file mechanics should be deterministic script work. Human approval gates
every materialization, per jim's phase-gate convention.

## Depends on

Issue [[20260630-build-intelligence-for-context-aware-spec-group-definition]]
(#19) — the vertical doctrine, `BLUEPRINT.md` context map, and territory
modes must exist before anything can migrate onto them.
