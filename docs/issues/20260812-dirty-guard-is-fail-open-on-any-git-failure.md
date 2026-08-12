---
id: 20260812-dirty-guard-is-fail-open-on-any-git-failure
num: 308
title: "Dirty guard is fail-open on any git failure"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:52Z
updated: 2026-08-12T03:41:52Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`place_dirty_guard` treats any git failure as "the collection is clean", so the
guard passes vacuously on exactly the paths it should refuse.

## Mechanism

`skills/issue/scripts/place.sh:552-560`:

```
st="$(git --literal-pathspecs status --porcelain -- "$prefix" 2>/dev/null)"
[[ -n "$st" ]] || return 0
```

The exit status is discarded and only stdout is tested. Any condition that makes
git produce no output — a pathspec it refuses (a path beyond a symlink), a
corrupt index, a permissions error — reads as "clean" and the guard returns 0.

This is what makes the missing containment check on `cmd_begin`'s direct arm
silent rather than noisy: the symlinked-collection case produces exactly this
empty-output-plus-error shape.

A second, structural weakness: the handle records no fingerprint of *when* the
collection was clean (`place_direct_handle` writes only `mode`/`dest`/`prefix`/
`read`). Two `begin` calls on a clean collection mint two live handles; after the
first `commit` publishes and removes handle #1, handle #2 remains a durable,
non-expiring capability to publish whatever is dirty in the collection later,
with no dirty guard having seen that state.

## Proposed action

Check git's exit status and refuse on a non-zero one rather than reading empty
output as clean. Consider recording the collection's state fingerprint in the
handle so `commit` can tell whether the tree it publishes is the one `begin`
approved.

## Origin

Post-build review of `issue/011`; found by the two-phase region investigator.
