---
id: 20260731-close-the-remaining-edges-of-the-ordinal-identity-invariant
num: 181
title: "Close the remaining edges of the ordinal identity invariant"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [file, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:39:24Z
updated: 2026-07-31T21:09:14Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

Two places where the "two spellings of one ordinal are one ordinal" invariant
stops short.

**Width asymmetry.** `spec_ordinal_holder` skips a sibling whose leading token
exceeds 15 digits (`skills/file/scripts/jimfile.sh:529` — deliberate, documented,
fixtured), while `cmd_next_id` strips leading zeros and counts *any* width
(`:330-338`). A 19-digit-padded `…018-wide` therefore floors `next-id` to `019`
while reading as "018 is free" to the occupancy gate, so a rename onto 018 is
permitted alongside the padded twin.

**The partition move primitives are unguarded.** `jimledger.sh move-spec-dir`
(`:553-620`) and `rename-tracked` (`:275-320`) refuse only an exactly-existing
destination and never consult `spec_ordinal_holder`. Split and merge renumbering
can therefore still land a padding-variant twin.

## Assessment

The first is hand-made-only and pathological. The second is the more meaningful
boundary: the claim that the occupancy halt is *structural rather than
discipline* holds for the spec-creation and realize paths, and stops at the
partition operations, which rename spec directories through a different pair of
primitives.

## Fix

Agree one width policy across the predicate and `next-id`; and either route the
partition primitives through the shared predicate or record explicitly that the
guarantee is scoped to the two paths that do enforce it.

Finding 11 and Finding 12 of
`docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31) — both edges closed

**Width asymmetry — one policy, and `next-id` is the side that moved.** The
predicate cannot compare over-wide tokens safely; that is the `intmax_t` wrap the
rename-path work already fixed, and it is why skipping is the only option there.
Coherence then requires `next-id` to skip too: a token the numbering system
cannot represent is not an ordinal, and should not move the floor. `cmd_next_id`
now applies the same bound, so the two surfaces agree that such a sibling decides
nothing — the disagreement that permitted a padding twin. Fixtured on both
surfaces in one case, since the defect was that they disagreed.

**The move primitives — gated, and the guarantee is no longer scoped.** This
closes as the stronger of the two options rather than as a recorded limitation.

`move-spec-dir` now decides occupancy through the same predicate the rename and
realize paths enforce. Its shape gate is exactly 3 digits, so what it could
actually land was never a padding variant — it was a **same-ordinal
different-slug twin** (`018-beta` beside `018-alpha`), which the exact-path check
cannot see. The source excludes itself, so a within-group slug renumber still
lands. Neither batch flow is affected: split targets fresh child groups and merge
appends above the target's high-water, so no transient collision exists for the
gate to refuse.

The predicate's verb form grew a `--root` so the gate reads the specs dir the
caller was handed rather than assuming it equals the configured one — a gate
reading a different tree than the one it guards decides nothing.

`rename-tracked` is deliberately left ungated. It is a generic sibling rename
over group directories and arbitrary tracked paths; a spec-ordinal check does not
belong on it, and the realize path that does use it already consults the
predicate itself.
