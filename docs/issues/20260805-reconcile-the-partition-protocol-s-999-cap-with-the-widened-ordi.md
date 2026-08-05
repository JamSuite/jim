---
id: 20260805-reconcile-the-partition-protocol-s-999-cap-with-the-widened-ordi
num: P-20260805-reconcile-the-partition-protocol-s-999-cap-with-the-widened-ordi
title: "Reconcile the partition protocol's 999 cap with the widened ordinal bound"
status: open
priority: high
labels: [id-coordination, partition, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:41Z
updated: 2026-08-05T01:53:41Z
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
