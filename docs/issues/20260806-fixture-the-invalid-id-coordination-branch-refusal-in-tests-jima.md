---
id: 20260806-fixture-the-invalid-id-coordination-branch-refusal-in-tests-jima
num: 256
title: "Fixture the invalid id_coordination_branch refusal in tests/jimalloc.sh"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [tests, jimalloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-06T20:20:17Z
updated: 2026-08-06T20:20:17Z
origin: docs/specs/issue/011-issue-placement/research.md
---

## Description

`alloc_valid_branch` (`skills/file/scripts/jimalloc.sh:1979-1984`) refuses an empty value, a leading `-`, and anything `git check-ref-format` rejects — but `tests/jimalloc.sh` exercises only the valid-custom-branch case (`case_jimalloc_custom_branch_from_config`, ~:1713-1727). No test supplies an *invalid* `id_coordination_branch` through config and asserts the named refusal from `alloc_coord_branch` (`:1989-1998`). The refusal path guarding every git interpolation of the branch name is unpinned; a mutation deleting the gate would leave the suite green.

Proposed action: add fixtures driving an invalid `id_coordination_branch` (e.g. leading `-`, embedded space, `..`) through config and asserting rc 1 with the named error, so the refusal discriminates under mutation.

Note: spec `issue/011` (issue placement) adds a second branch-name config key; if its plan takes the shared-gate route (reusing/extracting `alloc_valid_branch`), this fixture naturally rides that build and this issue closes with it. Filed so the gap survives the other fork (a SYNC-copied gate leaving `jimalloc.sh` untouched).
