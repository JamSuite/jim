---
id: 20260807-place-direct-publish-stages-without-the-worktree-containment-gat
num: 268
title: "place_direct_publish stages without the worktree containment gate"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:56Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

`place_direct_publish` stages a config-derived path with `git add -- "$prefix"`
without first resolving it against `git rev-parse --show-toplevel`.

It is the only staging site in the repository that does not. Every other one
does: `jimledger.sh` (six sites), `jimpartition.sh` (two), `spec/reconcile.sh`,
`jimalloc.sh`. jimledger's own comment states why:

> backstopping valid-relpath and git's own symlink refusal against a shape-valid
> path that symlinks out of the worktree

`place_prefix` runs the first gate (`jimfile.sh valid-relpath` plus a leading-dash
refusal) — which is exactly the pair that precedent describes as needing the
second. The plan cites `commit-map` as its containment precedent and
`jimledger.sh commit-*` as its staging shape; only the per-tree-entry half was
carried over.

Residual risk is what blueprint-tier work already decided to close for
`commit-map`: git's own "pathspec is beyond a symbolic link" refusal is the only
remaining stop.

## Proposed action

Three lines, mirroring `cmd_commit_map`: resolve the staging target with
`realpath -m`, compare against `git rev-parse --show-toplevel`, refuse if it
does not land inside.

## Resolution (2026-08-11)

Fixed in `37df7c6`. `place_worktree_contained` resolves the configured
collection against `git rev-parse --show-toplevel` and refuses a path landing
outside it — before the wrapped command as well as before `git add`, so a
refused run writes nothing anywhere rather than only failing to stage. Covered
by `case_place_direct_refuses_a_collection_outside_the_worktree`.
