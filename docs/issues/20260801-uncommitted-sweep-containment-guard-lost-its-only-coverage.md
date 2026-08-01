---
id: 20260801-uncommitted-sweep-containment-guard-lost-its-only-coverage
num: 196
title: "Uncommitted-sweep containment guard lost its only coverage"
status: closed
priority: medium
labels: [test, spec, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T06:36:08Z
updated: 2026-08-01T10:01:09Z
origin: docs/notes/20260801-c-prime-fix-handoff.md
---

## Description

## Context

`tests/specreconcile.sh:235-248`,
`case_specreconcile_uncommitted_sweep_refuses_escape`, carries an AC comment
describing the **containment guard** — that the uncommitted own-directory sweep
refuses a write escaping the worktree.

## Problem

After the symlink arm was added to the sweep in the C-prime-fix, this case now
exercises the *symlink* path rather than the containment guard its comment
describes. The containment guard has silently lost its only own-directory
coverage.

This is the failure mode the C-prime-fix review named as its own generalization:
a practice that detects things about the code but not its own absence. The suite
still reports green, the case still passes, and the guard it was written to
protect is now untested — indistinguishable, from the outside, from a guard that
is covered.

## Proposed action

1. Restore direct coverage of the containment guard for the uncommitted
   own-directory sweep — a case whose target escapes the worktree by a means
   other than a symlink.
2. Rename the existing case to describe what it now actually exercises, so the
   comment and the assertion agree.
3. Mutation-test both: neuter the guard each is meant to cover and confirm the
   corresponding case fails. A fixture that has never failed proves nothing.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, finding P3). Anchor
re-confirmed 2026-08-01. The claim that the case no longer reaches the
containment guard is the investigator's reading of the two arms and was not
confirmed by mutation — step 3 above is what would settle it.

## Resolution (2026-08-01) — not a defect

**The guard is covered.** Mutation-tested directly: neutering the escape
refusal in the own-directory enumeration makes
`case_specreconcile_uncommitted_sweep_refuses_escape` fail on both assertions.

The finding assumed the symlink arm and the containment guard were separable.
They are not — the escape refusal lives *inside* the symlink branch, because a
symlink is the only way an entry under a realized spec directory can resolve
outside the worktree. A plain `*.md` entry there is inside by construction. So
the case exercises exactly what its AC comment describes, and no coverage was
lost. No code or test change.
