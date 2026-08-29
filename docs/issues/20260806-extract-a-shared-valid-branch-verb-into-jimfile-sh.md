---
id: 20260806-extract-a-shared-valid-branch-verb-into-jimfile-sh
num: 257
title: "Extract a shared valid-branch verb into jimfile.sh"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [platform, jimfile, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-06T21:48:56Z
updated: 2026-08-06T21:48:56Z
origin: docs/specs/issue/011-issue-placement/plan.md
---

## Description

Two scripts carry the same three-line branch-name gate: `alloc_valid_branch` (`skills/file/scripts/jimalloc.sh:1979-1984` — empty / leading `-` / `git check-ref-format refs/heads/<v>`) and, once spec `issue/011` ships, the placement gate in `skills/issue/scripts/place.sh` (same three checks plus the coordination-branch refusal). Both defer to `git check-ref-format`, so the duplication is small — but it is the shape the ordinal-single-source lesson warns about: one rule, two spellings, nothing pinning them together.

Proposed action: extract a `valid-branch` verb into `jimfile.sh` (platform group — an additive provides-face change), consume it from both `jimalloc.sh` and `place.sh`, and drop the local copies. Until then, a textual-invariant test pinning both spellings is the cheaper interim.

Deferred out of `issue/011`'s plan (DD 4): the cross-group blast radius wasn't worth three lines mid-feature. See also [[fixture-the-invalid-id-coordination-branch-refusal-in-tests-jima]] — the existing gate's untested refusal path, which unification would naturally absorb.
