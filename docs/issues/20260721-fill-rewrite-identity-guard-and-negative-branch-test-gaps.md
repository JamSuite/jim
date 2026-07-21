---
id: 20260721-fill-rewrite-identity-guard-and-negative-branch-test-gaps
num: 78
title: "Fill rewrite-identity guard and negative-branch test gaps"
status: open
priority: medium
labels: [046, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-21T05:45:36Z
updated: 2026-07-21T05:45:36Z
origin: docs/specs/jim/046-spec-migration/review.md
---

## Description

## Finding (from review of spec jim/046)

The `rewrite-identity` verb's tests leave gaps for a security-sensitive mutating
verb:

- The "all guards before any edit" property is asserted only by code structure
  (the guard loop and the edit loop are separate) — no test passes one good + one
  guard-failing file to prove the good file is left unedited.
- The `after2` alpha-negative branch (a `cart/subdir` path segment left
  untouched, since only `<old>/<digit>` is a typed ref) has no case.
- The `valid_relpath` `..`/absolute rejection, an invalid `<new>` slug, and the
  not-in-a-git-repo branch are untested.

## Suggestion

Add to `tests/jimpartition.sh`: a multi-file guard-abort case (good + guard-
failing → good file unedited), a `cart/subdir` no-rewrite case, and the
`valid_relpath` / invalid-`new` / no-git negative cases.

Origin: docs/specs/jim/046-spec-migration/review.md (Finding 2)
