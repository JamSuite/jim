---
id: 20260826-dependency-outside-the-collection-reads-as-unblocked
num: 389
title: "Dependency outside the collection reads as unblocked"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:56Z
updated: 2026-08-26T21:23:44Z
origin: "docs/specs/issue/014-read-view-filter-composition/plan.md"
---

## What

An issue whose `depends-on` names a slug the collection does not hold reads as
**unblocked**. The predicate keys on the target being *not finished*, and a
target that is not in the collection has no status to judge, so it contributes
nothing and the record falls through to unblocked.

## Reproduce

```
$ cat <dir>/20260101-a.md
---
title: "A"
status: open
relations:
  depends-on: [20260199-ghost]
---

$ render.sh list blocked <dir>
_No matching issues._

$ render.sh list unblocked <dir>
  #1     -            -         A
```

The index does notice the edge — it reports `--depends-on--> 20260199-ghost has
no inverse blocks back-edge` — but the read view answers confidently in the
other direction rather than deferring to that.

## Why it matters

The point of a derived predicate is that no record can disagree with it, because
there is no stored copy to fall out of step. This is a different failure: the
derivation is consistent, and it is confidently wrong about a record whose
dependency simply cannot be found. A developer picking work off `unblocked` is
handed an issue that names a blocker nobody can open.

## Fix shape

Three options, in increasing strength:

1. **Treat an unresolvable target as blocking.** An unknown dependency is not a
   finished one, and the predicate's own wording — depends on an issue that is
   not finished — arguably already says so.
2. **Disclose.** Keep the current answer and name the records whose
   blocked-ness could not be settled, the way the axis-answerability
   disclosure does.
3. **Leave it and lean on the index's dangling-edge warning**, which already
   fires. This is the status quo, and it is defensible only if a reader of the
   list view is expected to have read the index's warnings first — which is the
   assumption every other disclosure in this group declines to make.

Worth noting the interaction with the one-hop keying: the derivation is one hop
precisely because keying on *not finished* makes one hop and the transitive
closure agree. An unresolvable target is the one input where that equivalence
has nothing to stand on.

## Resolution

Fixed by the first of the three options above: an unresolvable target counts as
blocking. `build_derived_axes` now keeps the set of slugs the collection holds
alongside the set that is unfinished, and a `depends-on` edge blocks when its
target is unfinished **or** is not in the collection at all.

**Option 3 is not available, and running it is what showed that.** It reads
"lean on the index's dangling-edge warning, which already fires" — but the
warning that fires is

```
- `20260101-alpha` --depends-on--> `20260199-ghost` has no inverse `blocks` back-edge.
```

and it fires identically for a dependency that resolves perfectly well. It
reports missing reciprocity, not a missing target. Nothing on any surface says
the target is absent, so the status quo was not "the read view is quiet while
the index warns" — it was silence in both places.

**A neighbouring asymmetry, not fixed here.** `index.sh` does warn
`names an umbrella not in the collection` when a `part-of` target is missing.
There is no analogue for `depends-on`. So the collection already has the
shape of this check for one relation type and not the other — worth its own
record rather than folding into this fix.

**Option 2 was not taken, and stays available.** Disclosure would have left the
wrong answer standing beside a note about it; the wrong answer was the harm.
A disclosure naming the records whose blocked-ness rests on an unresolvable
target could still be added on top, and would now be a note about a *blocked*
record rather than a caveat on an unblocked one.

**On the one-hop keying.** The comment above the derivation notes that keying
on *not finished* is what makes one hop and the transitive closure agree, and
this record observed that an unresolvable target is the one input where that
equivalence has nothing to stand on. Blocking resolves that: the record is
blocked at the first hop, and no traversal past an unreachable target could
have reached any other answer.

**Pinned by**
`case_issues_render_blocked_by_a_dependency_outside_the_collection`, asserting
both directions — the ghosted record is blocked and is not offered under
`unblocked`, while a record with no dependency and one whose dependency is
finished both stay unblocked.

**Blast radius, measured:** this repository's collection holds seven
`depends-on` edges across three distinct targets, all of them present, and one
blocked record before and after. The change moves nothing here; it moves only a
collection carrying a dependency that cannot be resolved.

**Not closed by this.** A target that fails the id validator never becomes an
edge at all — `index.sh` refuses it with `invalid relation target` and the
record reads unblocked. That is a different path with its own warning, and it
is the one case where the operator is already told.
