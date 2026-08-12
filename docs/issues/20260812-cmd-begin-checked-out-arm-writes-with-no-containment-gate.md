---
id: 20260812-cmd-begin-checked-out-arm-writes-with-no-containment-gate
num: 302
title: "cmd_begin checked-out arm writes with no containment gate"
status: closed
priority: high
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:34Z
updated: 2026-08-12T06:06:19Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`cmd_begin`'s checked-out arm hands a collection directory to the agent with no
worktree-containment check, so a symlinked collection path lets the agent write
outside the repository before anything refuses.

## Mechanism

`skills/issue/scripts/place.sh:810-821`. The arm runs `place_disclose_rewrite`,
then (for a write) `place_dirty_guard`, then `place_direct_handle`, and returns.
`place_worktree_contained` is called at exactly two sites — `place_direct:597`
(before the wrapped command) and `place_direct_publish:620` (before staging) —
and `cmd_begin` is not one of them.

On the two-phase door there is no wrapped command: **the agent is the writer**.
`place_prefix` validates the path's *shape* only and never resolves symlinks;
`place_dirty_guard` is a `git status` on the pathspec with stderr discarded, so a
pathspec git refuses yields empty output and the guard returns 0 vacuously.

With `issue_placement` naming the checked-out branch and a `docs` symlink
pointing outside the repo — the exact fixture `tests/place.sh:1711-1722` builds
to prove the `run` arm refuses — `begin` returns rc 0 and prints `docs/issues`,
and `skills/issue/SKILL.md:186` directs the agent to edit inside that directory.

`commit` does refuse afterwards (`place.sh:620`), so nothing is staged or
published — but the write has already happened outside the worktree, and the
refusal message ("so it will not be written or staged") is false by the time it
prints.

This is the class the `materialization-contained` invariant (criticality
critical) exists to close, missing on the arm § 6a makes the default path for
every close and edit under a placement.

## Proposed action

Add `place_worktree_contained "$prefix" || return 2` to `cmd_begin`'s direct arm,
ahead of the read-arm print, mirroring `place_direct:597`. Add a case driving
`begin` against an escaping collection path — `tests/place.sh:1711` covers the
`run` arm only.

## Origin

Post-build review of `issue/011`. Found independently by a region investigator
and by the `materialization-contained` judge.

## Resolution (2026-08-12)

Fixed in `8673d3c`. `place_worktree_contained` now runs as the first thing
`cmd_begin`'s checked-out arm does, ahead of the rewrite disclosure and the
dirty guard, mirroring `place_direct`. It covers the read arm as well as the
write arm: § 6a opens a read handle on every insights run and it names the same
directory. Pinned by
`case_place_direct_begin_refuses_a_collection_outside_the_worktree`, which
drives both arms against a `docs` symlink pointing out of the repo and asserts
no handle and no directory come back — proven to go red with the gate removed.

The finding's observation that the dirty guard made this silent rather than
noisy is closed separately as #308.
