---
id: 20260704-strengthen-commit-map-containment-or-amend-dd-4
num: 38
title: "Strengthen commit-map containment or amend DD 4"
status: open
priority: low
labels: [security, review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T00:22:58Z
updated: 2026-07-04T00:22:58Z
origin: docs/specs/jim/033-context-map/review.md
---

## Description

## Context

Surfaced by the 033 post-build review (origin) — the single counted plan
deviation. Plan DD 4 specified that `commit-map` verify each path
"resolves inside `git rev-parse --show-toplevel`"; the implementation
substitutes shape validation (`valid-relpath` on both arguments) plus a
repo-presence check, with the rationale documented at
`skills/review/scripts/jimledger.sh:178-180`.

## What

Two investigations judged the substitution sound (lexical containment
holds for `..`-free relative paths under a repo CWD; `git add` refuses
worktree-escaping symlink traversal; failures degrade rc 2), but it is a
narrowing of the plan's letter that was not surfaced for approval
mid-build. Resolve the gap one of two ways:

1. **Strengthen:** add the literal resolved-path-inside-toplevel
   comparison to `commit-map` (belt and suspenders; closes the
   invoked-from-subdirectory nuance), with reject tests; or
2. **Accept:** amend plan DD 4 / security.md Finding 2's wording to match
   the shipped mechanism, recording the acceptance explicitly.

## Relates to

Spec 033 plan DD 4 / Task 3; security.md Findings 2, 8; review finding 1.
