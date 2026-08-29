---
id: 20260803-restore-the-classifier-s-lost-local-declarations
num: 217
title: "Restore the classifier's lost local declarations"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-03T05:50:27Z
updated: 2026-08-05T02:25:13Z
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

## Resolution (2026-08-05)

`local c4 canon` restored in `alloc_classify_spec`, dead `g` dropped. A
mechanical scope audit over the whole file — tracking plain assignment, `+=`,
subscripted assignment, `read`, `mapfile`, both `for` forms and `printf -v` —
reproduces the reported leak at `d36deed^` and finds it gone at HEAD, with every
variable the function assigns now declared. The only remaining file-wide hits are
`alloc_rename_index`'s `rn` and `alloc_live_claim_set`'s `live`/`spent`, both
documented out-params.

The leak check discriminates per name, not merely in aggregate: dropping `c4`
alone, `canon` alone, or both each turns it red.

Scope note for future work: the check is name-pinned (`declare -p c4 canon`) and
covers one function, so it would not have caught the missing declarations found
elsewhere in this same range. A file-wide version would need an allowlist for the
three deliberate out-params above.
