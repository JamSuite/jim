---
id: 20260805-refuse-a-newline-bearing-basename-in-merge-map-s-numeric-sort-ro
num: 246
title: "Refuse a newline-bearing basename in merge-map's numeric sort round-trip"
status: open
priority: critical
labels: [id-coordination, partition, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:05Z
updated: 2026-08-05T22:20:05Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

`merge-map` fabricates map rows for specs that do not exist.

Commit `2690614` replaced a per-directory `basename` with a numeric-sort
round-trip (`skills/partition/scripts/jimpartition.sh:1585-1615`): basenames are
collected into `bns`, re-serialized through `printf '%s\n' "${bns[@]}" | sort`,
and re-read with `while IFS= read -r bn`. A basename containing a newline splits
into multiple rows.

```
on disk:  docs/specs/src/001-real
          docs/specs/src/"notes\n004-fabricated-a\n005-fabricated-b"

merge-map docs/specs tgt 001 src
  -> MAP  src/001  tgt/001
     MAP  src/004  tgt/002      <- src/004 does not exist
     MAP  src/005  tgt/003      <- nor does src/005
     rc=0
```

The pre-fix code never round-tripped through a line-oriented pipe, so this is a
regression introduced by the widening.

The verb's own docstring calls its output "the deterministic id arithmetic the
gate presents verbatim (no LLM arithmetic)". The ids bind at Close through
`partition-batch spec`, into an append-only registry that never reissues an
ordinal. So a single odd directory permanently burns ordinals in the target
group, writes rename records for specs that do not exist, and shifts every real
spec's assignment — with the human gate reviewing a map that is arithmetically
self-consistent and wrong. A directory named `002-a\n003-x` misnumbers a real
spec the same way.

## Proposed action

Iterate the basenames without a line-oriented round-trip — sort an index, or use
NUL delimiting (`sort -z` / `read -d ''`) — and refuse a basename containing a
newline outright rather than skipping it, since a spec directory whose name
cannot survive the map grammar is drift the operator must see.

Fixture a newline-bearing basename and assert the verb refuses at non-zero rc
with no rows emitted, and that a mixed-width tree still maps in numeric order.
