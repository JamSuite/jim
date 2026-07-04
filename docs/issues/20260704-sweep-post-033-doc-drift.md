---
id: 20260704-sweep-post-033-doc-drift
num: 36
title: "Sweep post-033 doc drift"
status: open
priority: low
labels: [docs, workflow, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T00:22:57Z
updated: 2026-07-04T00:22:57Z
origin: docs/specs/jim/033-context-map/review.md
---

## Description

## Context

Surfaced by the 033 post-build review (origin). The build's ecosystem
touches exposed pre-existing schematic staleness plus a handful of
cosmetic drift items introduced or highlighted by 033.

## What

One sweep of documentation drift, smallest-possible edits:

- `WORKFLOW.md` illustrative sections: the Agent ↔ Skill Composition
  example still shows architect `skills: [plan, arch]` (real file now
  carries `blueprint`; the pm example is stale too); the Agents table
  omits `/jim:blueprint` from architect's row and has other pre-existing
  incompleteness; the plugin directory tree predates spec 029.
- `skills/file/scripts/jimfile.sh:590` comment: "the only KINDS∩KEYS
  overlap is `debug`" — `blueprint` is now the second overlap.
- Cosmetic cross-references: `skills/blueprint/SKILL.md` cites
  "methodology § Scrub" vs the actual heading "Scrub reminder (canonical
  text)"; `map-methodology.md` is the only `references/` file carrying a
  literal `${CLAUDE_PLUGIN_ROOT}`; the map banner tail wording differs
  slightly from ARCHITECTURE.md's.

## Why low

No behavioral impact — comment/illustration drift only. Review findings
2, 4, 5 of [[20260703-build-intelligence-for-context-aware-spec-group-definition]]'s
build review.
