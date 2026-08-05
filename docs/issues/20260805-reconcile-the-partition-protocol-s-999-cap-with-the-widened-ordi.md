---
id: 20260805-reconcile-the-partition-protocol-s-999-cap-with-the-widened-ordi
num: 228
title: "Reconcile the partition protocol's 999 cap with the widened ordinal bound"
status: closed
priority: high
labels: [id-coordination, partition, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:41Z
updated: 2026-08-05T10:21:33Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

Two things shipped in the same range contradict each other above ordinal 999, and
following the partition skill's own instruction verbatim is refused.

`#212` widened the canonical ordinal bound to `{3,15}` and closed the `>999` dead
end in the registry and ledger primitives. `#209 fork` — same range, `d872159` —
wired `skills/partition/SKILL.md:365-369`:

> Every fresh child's start is the ordinal part of `jimalloc.sh peek spec <child>`
> stdout, **copied verbatim** — a fresh name peeks to `001`; a previously retired
> name resumes above its high-water.

But `jimpartition.sh:1440` still refuses anything that is not three digits:

```
jimpartition renumber-map: start must be a 3-digit id 001-999: checkout=1000
```

A group past 999 peeks to `cart/1000`, and copying it verbatim — exactly as the
skill instructs — fails at map time. Neither issue could have caught this alone:
each is internally consistent, and the contradiction lives only in their
composition.

`merge-map` is worse than a refusal. At `jimpartition.sh:1566` the tree-basename
scan is `^[0-9]{3}(-.*)?$`, so a 4-digit spec is **silently omitted from the map at
rc 0** — weaker than the loud refusal `move-spec-dir` gave before `#212` widened
it. `rewrite-refs` at `:1962` refuses with `malformed remap line`.

Six ordinal-width gates in `jimpartition.sh` (`:1439`, `:1467`, `:1548`, `:1566`,
`:1962`, plus the `(( seq > 999 ))` mint caps at `:1503`/`:1570`) were counted by
neither issue #212 nor the width fixture. The fixture's comment at
`tests/jimfile.sh:1524` dismisses them all as "the partition maps' exactly-3
*starts* … a protocol cap", but only two of the six are starts.

No group is near 999 today, so impact is nil now and certain later — this fires
exactly when a group succeeds.

## Proposed action

Decide whether the partition protocol shares the registry's ceiling or keeps its
own. If it shares: widen the six gates to `{3,15}` and drop the `> 999` mint caps.
If it keeps its own: make `peek spec` unusable-as-a-start explicit at the skill
boundary, so the instruction cannot tell an operator to copy a value the next verb
rejects.

Either way `merge-map:1566` must stop dropping representable specs silently —
omission at rc 0 is the one outcome no operator can act on.

Fixture: nothing in `tests/jimpartition.sh` pins any 4-digit case in either
direction (`grep '1000\|4-digit'` returns no hits).

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 2).

## Resolution (2026-08-05)

Settled as **share the registry's ceiling**, and it is purely a validator
widening — the split protocol is untouched, so B″ stayed a build rather than
escalating to a spec.

The evidence for "validator only": the verb sequence, the tab-delimited
`MAP\t<g>/<ord>\t<g>/<ord>` grammar and the human gate carry no width-bearing
field; `%03d` is a POSIX *minimum* field width, so both emit sites already
printed four digits correctly; `renumber-map` already sorted on a numeric key.
The 999 cap sat between a producer (`peek spec`) and a consumer
(`partition-batch spec`, via `alloc_valid_ord`) that both admit 15 digits — an
undocumented third refusal mode the skill body never named, which is why the
composition failure was invisible from either side.

**Eight gates, not six, and the two extra ones were the dangerous ones.**
`jimpartition.sh:1567` was a fixed three-character slice (`onum="${bn:0:3}"`),
not a regex — widening the scan pattern alone would have truncated `1000-foo` to
`100` and emitted a *wrong* MAP row, turning an omission bug into a corruption
bug. And `merge-map`'s scan glob is credited in its own header as pre-sorted,
which holds only while every basename is three digits (`1000` sorts ahead of
`999` lexically); it now sorts numerically like `renumber-map` does.

`merge-map:1566` no longer drops anything silently. A dir outside the width
bound is refused rc 1 with no partial output; a dir that is not ordinal-shaped
at all is still skipped, because it is not a spec. Leading digits separate the
two cases.

**The re-divergence fix is the fixture, not a shared validator.** The width
guard's omission sweep required a comma (`\{[0-9]+,[0-9]+\}`), and these gates
spell a fixed repetition — so this file was never *exempted* from the guard, it
was invisible to it, and `ARCHITECTURE.md` already named the seam as the one
place a divergence would not be caught structurally. The guard now classifies a
spelling as ordinal when its bounds name the floor 3 or the ceiling 15, which
leaves the corpus's many date `{8}` and timestamp `{2}`/`{4}` widths out of
scope without enumerating them. Routing the scan through a `jimfile.sh`
predicate was considered and rejected: that loop runs per spec directory, and a
boundary subprocess there would add a fork per directory in the same pass that
is closing a fork-amplification DoS.

Twelve mutations, all red, including the one that matters most — narrowing the
scan back to `{3}` now turns the width guard itself red, which is the check that
did not exist when this drift happened.

The fixtures also gained the boundary the issue found missing: both overflow
cases are now written AT the ceiling rather than at a value that merely happens
to be refused, and both start gates are probed under-width and over-width.
