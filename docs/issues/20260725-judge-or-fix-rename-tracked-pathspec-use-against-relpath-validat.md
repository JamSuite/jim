---
id: 20260725-judge-or-fix-rename-tracked-pathspec-use-against-relpath-validat
num: 100
title: "judge or fix rename-tracked pathspec use against relpath-validation"
status: open
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:42Z
updated: 2026-07-25T08:04:42Z
origin: BLUEPRINT.md
---

## Description

The relpath-validation rule's letter says an untrusted path is never handed to git as a pathspec, but cmd_rename_tracked in skills/review/scripts/jimledger.sh runs `git ls-files -- "$old"` on a valid-relpath'd (not slug-composed) argument; valid-relpath does not neutralize pathspec magic. Downstream guards (sibling constraint, containment, git-mv failure) narrow exploitation. The invariant is withheld from the platform blueprint (fail-closed) until judged or fixed.

Fork: fix (enumerate `git ls-files` without a pathspec and filter in bash, matching the rule's own prescription) or judge the site conformant and restore the row with the clause clarified.
