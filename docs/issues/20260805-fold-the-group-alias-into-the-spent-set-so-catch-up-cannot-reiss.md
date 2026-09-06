---
id: 20260805-fold-the-group-alias-into-the-spent-set-so-catch-up-cannot-reiss
num: 238
title: "Fold the group alias into the spent set so catch-up cannot reissue a vacated ordinal"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, alloc, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:04Z
updated: 2026-08-06T06:38:55Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

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

## Resolution (2026-08-06)

Fixed. `alloc_spec_replay`'s group-rename arm now carries every **already-spent**
ordinal under the source group forward into the destination group's spelling,
before the loop that moves live claims runs. The spent set holds both spellings:
an id is closed to arrivals under every name it has ever had.

**The Proposed action above is wrong as written, and was measured to be.** It
says to apply the alias map "when filling `src_only` in the group-rename arm" —
but the entries that arm *fills* are the live claims it is moving, whose
destination spelling is live, not spent. Implemented literally over
`group allocate g` / `spec allocate g/001` / `group rename g h`, the replay emits:

```
LIVE	h/001	3	alpha
SRC	h/001          <- the same id, both live and spent
```

`alloc_live_claim_set` would then fill `live[h/001]` and `spent[h/001]` together,
and `alloc_lift_state`'s spec arm consults `spent` *before* `live`, so a
legitimate destination under a renamed group would be refused
`destination-vacated`. It also drops the retired spelling `g/001` entirely. And
it does not fix the reported bug —
`case_jimalloc_sweep_vacated_ordinal_survives_a_group_rename` still fails under
it. The entries needing the alias are the ones already in the set when the group
rename arrives, not the ones the arm writes. Under the fix the same log gives
`LIVE h/001` + `SRC g/001`.

**Union rather than replace, and that choice is load-bearing rather than
tidy.** Re-spelling in place would drop the vacated spelling, whose refusal is
then only redundant *while its neighbours stay put* — the condition
`alloc_lift_state`'s own header calls "not enforcement". Demonstrated: with
`core/002` vacated, `core` renamed to `parts`, and the freed name `core` later
taken over by another group, `partition-batch spec` refuses a renumber onto
`core/002` **on the spent gate by name**, and `resolve core/002` shows why —
it already dereferences to `parts/044`. Reaching that state needs a
hand-appended record, since both guarded emitters refuse to rename into a name
that renamed away; that is precisely the crafted-record threat model
`alloc_fold_max_spec`'s contract is written against ("a crafted record can waste
an ordinal, never make a consumed one available again"). Under replace, a
crafted record could make a consumed one available again.

Reported cost, measured: in the drift case the sweep's `rename-source-ids`
counter is unchanged, because the carried spelling has a tree directory and is
reported as `tree-on-vacated-ordinal` instead. In the settled case it rises by
one per already-spent ordinal in a renamed group — a true row, since that
ordinal is genuinely vacated with no artifact. The counter's *name* is the part
that strains; its class label, `vacated-ordinal`, fits exactly.

Covered by `case_jimalloc_sweep_vacated_ordinal_survives_a_group_rename`,
`case_jimalloc_sweep_vacated_ordinal_group_renamed_first` (the ordering that was
never skewed, so the pair pins the rule and not the one arm that broke),
`case_jimalloc_catchup_refuses_a_vacated_ordinal_across_a_group_rename` (rc 3,
log byte-identical, citation still single-referent) and
`case_jimalloc_partition_batch_refuses_a_retired_spelling_after_reuse`. All
mutation-tested: deleting the loop turns the first two red, and downgrading union
to replace turns the last one red.
