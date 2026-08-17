---
id: 20260805-correct-the-surviving-stale-doc-site-and-the-four-resolutions-th
num: 236
title: "Correct the surviving stale doc site and the four resolutions that outran their measurement"
status: open
priority: medium
labels: [docs, 000-blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:30Z
updated: 2026-08-05T22:20:30Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

One stale doc site survived the pass, and four Resolutions assert fixes or
mechanisms that did not exist when they were written.

**The stale site.** `ARCHITECTURE.md:396` still reads: "absorbed sources append
from a caller-passed `<start>` taken verbatim from `next-id`, never re-minting a
vacated id". Both clauses are false:

```
bash skills/file/scripts/jimfile.sh next-id spec platform
  -> error: 'next-id' answers for issues only - a spec ordinal comes from the
     coordination allocator (jimalloc.sh peek spec <group>)
     rc=2
```

The code is correct at `skills/partition/scripts/jimpartition.sh:1540-1543`, and
the document's own `:284` already carries the right wording. Commit `0620603`
edited line 396 — it fixed the `renumber-map` clause in the same sentence and left
this one. The new doc sweep cannot catch it: `tests/docsurfaces.sh:45-58` excludes
`ARCHITECTURE.md` by design, and its retirement pattern `'next-id spec'` does not
match this phrasing.

**The Resolutions.** This site is named by file:line in both issues that closed
over it:

- The stale-doc-sites issue's own table lists `ARCHITECTURE.md:395` as row 1, and
  its Resolution says `ARCHITECTURE.md` "was regenerated through `/jim:arch`".
- The emission-cluster doc issue's Resolution says "all eleven sites verified
  against the current tree and all eleven are already fixed".

What landed was six targeted hand-edits (+424 words on a 590-line file), not a
regeneration. The commit message was explicit and honest about this; the
Resolutions were not, and the substitution is why `:395` survived — it was on the
list the regeneration was supposed to sweep.

Two more, sharper because they are what the verify judges caught. Both were
written at 12:00:42 and became true at 12:58:09; neither was amended:

- The locale-pinning issue's Resolution: `scripts/` need not be swept "which the
  existing case already requires" — at that moment the case looped
  `skills/*/scripts/*.sh` only.
- The stray-test issue's Resolution: the sweep "sweeps `skills/` and `agents/`" —
  `agents/` was absent from the enumeration at any depth.

Two of the three judge-found defects are exactly the two those Resolutions had
already declared closed.

## Proposed action

Correct `ARCHITECTURE.md:396` to the wording its own `:284` uses, and drop the
"never re-minting a vacated id" clause.

Amend the four Resolutions so the record says what shipped: hand-corrections
rather than a regeneration, and the two sweep claims dated to the commit that made
them true.

Decide whether `ARCHITECTURE.md` belongs in the doc sweep's corpus — it is
hand-edited in practice, which is the premise its exclusion denies.
