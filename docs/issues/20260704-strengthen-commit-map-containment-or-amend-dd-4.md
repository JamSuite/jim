---
id: 20260704-strengthen-commit-map-containment-or-amend-dd-4
num: 38
title: "Strengthen commit-map containment or amend DD 4"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [security, review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T00:22:58Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/005-context-map/review.md
---

## Description

Surfaced by the 033 post-build review (origin) as the single counted plan
deviation. Closed by strengthening the check to match plan DD 4's letter.

## What it was

Plan DD 4 (and its security fold-ins, Findings 2 and 8) specified that
`commit-map` verify each path argument "resolves inside `git rev-parse
--show-toplevel`". The shipped `commit-map` substituted shape validation
(`valid-relpath` on both args — relative, no `..`) plus a repo-presence check.
Two investigations judged the substitution sound, but it narrowed the plan's
letter without being surfaced for approval mid-build, and the plan/security
artifacts still asserted the literal check.

## Resolution

Strengthened rather than accepted (developer's call). `cmd_commit_map` now
captures `git rev-parse --show-toplevel` and rejects (rc 2) any git-add target
whose `realpath -m` resolution falls outside the worktree top — a
belt-and-suspenders backstop over `valid-relpath` and git's own symlink
refusal, catching a shape-valid path that symlinks out of the tree. Added a
symlink-escape reject test in `tests/jimledger.sh`; full suite green. The code
now matches plan DD 4 / security.md Findings 2 & 8, so no doc amendment is
needed.

Spec 033 plan DD 4 / Task 3; security.md Findings 2, 8; review finding 1.
