---
id: 20260803-restore-the-classifier-s-lost-local-declarations
num: 217
title: "Restore the classifier's lost local declarations"
status: open
priority: low
labels: [id-coordination, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:27Z
updated: 2026-08-03T05:50:27Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

`alloc_classify_spec` in `skills/file/scripts/jimalloc.sh` declares `derived`,
`lines`, `n`, `i`, `c1`, `c2`, `c3`, five associative arrays, `g`,
`unreadable_n`, `tag`, `ra`, `rb`, `rc`, `tree_slug`, `tree_groups` and `id` as
`local` — but **not** `c4` or `canon`, both of which it assigns in the
tree-derivation loop (`c4` from the `while read -r c1 c2 c3 c4 _`, `canon` from
`alloc_canon_specid`). Both leak to global scope.

Harm is currently contained: both call sites run the function inside `$(...)`,
so the leak dies with the subshell. That containment is real but incidental —
nothing asserts it, and the file's convention is that every function declares
its own locals. The extraction that produced this is the same one the review
found dropping `SRC` rows, so the region deserves a careful pass rather than a
one-line patch.

Alongside, `g` at `:1563` is declared and no longer read; the extraction left it
behind.

## Proposed action

Add `c4` and `canon` to the function's `local` list, drop the dead `g`.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 18). Not filed alongside that review's other follow-ons.
