---
id: 20260808-direct-arm-commit-re-resolves-issues-path-and-publishes-the-wron
num: 283
title: "Direct-arm commit re-resolves issues path and publishes the wrong collection"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:39:49Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`cmd_commit`'s `direct` arm re-resolves the collection path instead of reading
what `begin` recorded, so a configuration change between the two steps publishes
an empty collection to the shared branch at rc 0 while the agent's actual edits
are never committed.

## Mechanism

The handle arm records `prefix` at `begin` (`skills/issue/scripts/place.sh:660`)
and reads it back at commit (`:727`). The `direct` arm re-resolves it (`:707`).

If `issues` changes between `begin` and `commit` — say `docs/issues` →
`docs/tickets`:

1. `place_direct_publish` calls `place_reindex "$prefix"` (`:476`) against the
   **new** prefix.
2. `index.sh:301` does `mkdir -p "$dir"`, creating it.
3. `git status --porcelain -- docs/tickets` is therefore non-empty
   (`?? docs/tickets/INDEX.md`), so the early return at `:478-479` does not fire.
4. `:480-481` stage and commit the new prefix; `:487` pushes.

A fresh empty-collection `INDEX.md` lands on the shared branch. The edits the
agent made under the old prefix are never committed. The caller sees rc 0.

## Related, same window

`place_prefix` validates path *shape* only, never existence. A collection
deleted between `begin` and `commit` is recreated empty by `index.sh:301`, and
`git add`/`commit -- "$prefix"` then publishes the deletion of every issue file
as the mutation.

## Proposed action

The `direct` arm already re-proves the destination, the `branch` sentinel and
HEAD. Add `prefix` to what it re-proves — or, better, record the prefix at
`begin` the way the handle arm does and refuse on mismatch, since the whole
point of the re-verification is that the fixed literal token carries no evidence
of what `begin` established.

## Test

No case covers `issues`-path drift across the two-phase boundary.
`tests/place.sh:1262-1272` covers only the `branch` sentinel.

## Resolution (2026-08-11)

Fixed in `37df7c6`. Having a handle to read from is what lets the arm stop
re-resolving configuration: the collection path is recorded at `begin` and
`commit` refuses a mismatch, rather than publishing wherever the configuration
now points. Covered by `case_place_direct_commit_refuses_a_moved_collection`,
which also asserts no empty collection is created at the new path.
