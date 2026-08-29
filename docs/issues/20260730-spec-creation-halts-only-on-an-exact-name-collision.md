---
id: 20260730-spec-creation-halts-only-on-an-exact-name-collision
num: 156
title: "Spec creation halts only on an exact-name collision"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T19:35:01Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`sdlc/017` requires the spec-creation path to halt loudly when the registry and
the tree disagree about an ordinal. `skills/spec/SKILL.md:218` delegates that
halt to `jimfile.sh mv-spec-id`, which refuses on `[[ -e "$target" ]]` — the
**exact composed name**, nothing more.

So with `001-bar` present in the tree and absent from the registry:

- `allocate spec` issues `001` (the registry high-water knows nothing of it),
- the target `001-foo` does not exist,
- the rename succeeds and the spec is written.

That is precisely the registry-vs-tree drift the halt exists to catch, and it
proceeds silently. Two directories now hold ordinal `001`.

The realize path has ordinal-level detection (`ordinal_holder` in
`skills/spec/scripts/reconcile.sh`); the creation path has only name-level
detection. The two halves of one contract are enforced asymmetrically, and no
test covers this half.

## Fix

Give the creation path the same ordinal-level check — either inside
`mv-spec-id` (refuse when any sibling directory already holds the target
ordinal) or as an explicit step before the rename — and fixture it.

Note the realize path's own ordinal check is currently defeatable for a separate
reason — it compares the ordinal as a literal string, so padding variants slip
past ([[20260730-gate-the-realized-spec-ordinal-and-stop-silent-record-loss]]).
Fixing both together is worth it: a shared "does any sibling hold this ordinal,
numerically?" predicate would close the creation-side gap and the realize-side
gap in one place.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
