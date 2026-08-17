---
id: 20260805-refuse-a-newline-bearing-basename-in-merge-map-s-numeric-sort-ro
num: 246
title: "Refuse a newline-bearing basename in merge-map's numeric sort round-trip"
status: closed
priority: critical
labels: [id-coordination, partition, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:05Z
updated: 2026-08-06T06:38:55Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
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

## Resolution (2026-08-06)

Fixed. `cmd_merge_map` refuses a basename containing a newline before the
numeric sort runs, at rc 1 with no rows emitted.

Refused rather than skipped, as the Proposed action asked: these ids bind at
Close through `partition-batch spec` into an append-only registry, so a spec
directory whose name cannot survive the map grammar is drift the operator has to
see. The refusal is the whole map's, not one row's — a real spec sharing the
scan with a newline-bearing sibling is withheld too, so no one is handed a map
that looks complete over a tree the verb could not read.

**Refuse-then-sort, not NUL-delimiting.** The Proposed action offered `sort -z` /
`read -d ''` as an option; `sort -z` is a GNU extension and this codebase is
POSIX-only, so the gate is what makes the line-oriented sort provably sound
rather than conventionally sound. The two sit eight lines apart in one function
and the fixtures pin the pair.

The offending name is never echoed — its own bytes are what made it
unprintable — so the message names the source group and the class only.

Door check, since a contract names a site and a site is not a class: this is the
only line-oriented round-trip over filesystem basenames in the script.
`renumber-map` reads an operator-supplied assign file whose grammar validates
each source against `^[0-9]{3,15}(-wip)?$`, so a newline cannot survive it, and
`pending_provisionals` space-joins into a refusal, where splitting fails safe.

Covered by `case_jimpartition_merge_map_refuses_a_newline_basename` (rc 1, no
rows, no `fabricated` id anywhere in the output, single-line stderr) and
`case_jimpartition_merge_map_newline_withholds_the_whole_map`. Both
mutation-tested — downgrading the refusal to a `continue` and deleting the gate
each turn them red — and
`case_jimpartition_merge_map_orders_numerically_not_lexically` confirms mixed
widths still map in numeric order.
