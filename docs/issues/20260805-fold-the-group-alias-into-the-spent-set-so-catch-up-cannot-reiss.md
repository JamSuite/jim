---
id: 20260805-fold-the-group-alias-into-the-spent-set-so-catch-up-cannot-reiss
num: P-20260805-fold-the-group-alias-into-the-spent-set-so-catch-up-cannot-reiss
title: "Fold the group alias into the spent set so catch-up cannot reissue a vacated ordinal"
status: open
priority: critical
labels: [id-coordination, alloc, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:04Z
updated: 2026-08-05T22:20:04Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

The never-reissue rule fails once a group rename intervenes. The high-water fold
applies the group alias (`skills/file/scripts/jimalloc.sh:958`,
`g="${alias[$g]:-$g}"`). The spent set does not: the group-rename arm at
`:1669-1671` re-spells only *live* claims into `src_only`, so an ordinal already
spent by an earlier **spec** rename keeps its retired spelling.

After `spec rename ui/001 ui/044` then `group rename ui parts`, `src_only` holds
`ui/001` while the live spelling is `parts/001`. A tree directory at `parts/001`
therefore classifies `MISSING`, not `SPENT-TREE`, and the append-only repair verb
acts on it:

```
peek spec parts   -> parts/045              registry says ordinal 1 is consumed
sweep             -> missing-record spec parts/001            rc=3
catch-up --apply  -> appended: spec allocate parts/001        rc=0
sweep             -> rc=0                                     (reads clean)
resolve ui/001    -> parts/044
resolve parts/001 -> parts/001                                (two answers)
realize           -> error: duplicate spec claim ... refusing (wedged)
```

This is issue 229's failure shape verbatim, one partition step later, and worse in
one respect: the appended record manufactures a `duplicate-realize-key` — the
registry-internal contradiction whose repair needs a corrective-write primitive
the grammar does not have. 229's Resolution states that scope is untouched; it is
now reachable from `catch-up`.

The same skew defeats `partition-batch`'s by-name spent refusal on both doors
(`:3483-3486`, `:3561-3564`) and demotes the lift's by-name check to its
neighbour's gate (`:3755`, `:3779`) — the lift still refuses, but by
`destination-not-established`, which is precisely the condition the lift's own
comment at `:3693-3697` declares insufficient.

`/jim:partition` issues `partition-batch spec` then `partition-batch group`, so
the ordering that triggers this is the feature's normal operation.

## Proposed action

Apply the alias map when filling `src_only` in `alloc_spec_replay`'s group-rename
arm, so the spent set is spelled in the same namespace the fold and the
classifier compare against. The rule to hold: every path that reads the spent set
must agree with every path that reads the alias-folded high-water.

Fixture both orderings — spec-rename-then-group-rename and
group-rename-then-spec-rename — and assert the classifier reaches `SPENT-TREE`,
`catch-up` refuses at rc 3, and the log is byte-identical after `--apply`.
