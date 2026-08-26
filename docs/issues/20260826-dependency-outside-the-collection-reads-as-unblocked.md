---
id: 20260826-dependency-outside-the-collection-reads-as-unblocked
num: 389
title: "Dependency outside the collection reads as unblocked"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, read-views, graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T01:36:56Z
updated: 2026-08-26T01:36:56Z
origin: "docs/specs/issue/014-read-view-filter-composition/plan.md"
---

## Description

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
