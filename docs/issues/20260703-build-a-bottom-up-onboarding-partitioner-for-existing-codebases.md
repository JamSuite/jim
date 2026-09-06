---
id: 20260703-build-a-bottom-up-onboarding-partitioner-for-existing-codebases
num: 35
title: "Build a bottom-up onboarding partitioner for existing codebases"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec-groups, onboarding]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-03T20:48:04Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/005-context-map/spec.md
---

## Context

Surfaced during spec 033 (context map) scoping. The 033 creation flow reads
strategic docs and existing specs to propose a partition, but heavy
code-analysis machinery was explicitly excluded from its scope.

## What

A bottom-up onboarding partitioner for the case 033 does not cover: jim
adopted on an **existing non-jim codebase**, where there are no specs or
strategic docs to reason from — only code. Propose an initial context map
from code-derived signals (directory structure, dependency graph, git
co-change clusters); the developer refines and approves through the standard
map-creation interview.

## Relation to existing work

Adjacent to [[20260703-build-the-partition-migration-skill]] (#34), which
covers re-partitioning projects already under jim (layered → vertical,
territory-mode upgrades). This issue covers first-contact adoption where the
bottom-up signal is all there is. Both depend on the map artifact and
doctrine from spec 033 (issue #19).

## Why low

Speculative until real adoption demand appears — jim's current audience
develops projects with jim from the start (greenfield multi-group). Filed as
a trend marker for the adoption story.

## Resolution (2026-07-07)

Absorbed into [[20260703-build-the-partition-migration-skill]] (#34) as its
`greenfield` entry mode. The 2026-07-06 dry-run (recorded in #34)
exercised exactly this first-contact case — adoption demand did appear —
and showed it
shares the extract → propose → interview → materialize pipeline with
re-partitioning: one skill, two entry modes. Closed without separate
implementation.
