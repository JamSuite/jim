---
id: 20260805-replay-renames-in-reconcile-s-claim-key-folds-so-a-vacated-ordin
num: 248
title: "Replay renames in reconcile's claim-key folds so a vacated ordinal is never returned as have"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [id-coordination, alloc, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:08Z
updated: 2026-08-13T11:01:21Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

`reconcile spec` and `reconcile issue` hand back vacated ordinals as `have`,
because their claim-key folds never replay renames.

`alloc_spec_claim_keys:1227` folds claim keys from raw `spec allocate` records
with no replay, so a claim a rename moved away still owns its key;
`alloc_reconcile_realize_spec:1364` answers `have` from that map. The issue side
is the same shape: `alloc_reconcile_realize:1171` builds
`existing[<full-id>] = <ordinal>` from `issue allocate` records only, and `issue
rename` never updates it.

```
allocate spec core "Widget"                       -> core/001
printf 'core/001\tother/001\twidget\n' | partition-batch spec 20260805
resolve spec core/001                             -> other/001
printf 'core/P-20260805-widget\n' | reconcile spec
  -> core/P-20260805-widget   core/001   have     rc=0
```

`resolve` says the identity lives at `other/001`; `reconcile` tells the consumer
to rename the provisional directory onto `core/001` — a spent ordinal under a
group that no longer holds it. Applying it manufactures exactly the
`tree-on-vacated-ordinal` class this cluster shipped, from the allocator itself,
at rc 0. On the issue side the result is drift `catch-up` then refuses to repair.

These two verbs are the cells absent from the door matrix the cluster drew: the
matrix crossed verbs with entities, and `reconcile` reads the log without the
classifier, so framing the defect as a classifier intersection kept the search
away from them.

## Proposed action

Route both claim-key folds through `alloc_spec_replay` (or the equivalent alias
and rename replay for the issue kind) so a moved claim no longer owns its old
key, and a vacated ordinal can never be returned as `have`.

Fixture both kinds: allocate, rename away, then reconcile the same durable
identity and assert the answer is the rename destination or a fresh mint, never
the vacated ordinal.

## Note

**2026-08-13.** This issue falsifies a standing blueprint invariant, and nothing
on either side says so.

`docs/specs/platform/000-blueprint/spec.md` states, as current fact, that the
per-kind fold "counts every ordinal a group has ever held — allocate ids, rename
destinations, and rename sources — so **a vacated ordinal is permanently gapped
whatever shape the log takes**".

This issue describes `reconcile spec` / `reconcile issue` handing a vacated
ordinal back as `have`, from the allocator itself, at rc 0. Both cannot be true.

The direct mechanism an earlier review found was fixed; this path was not, so the
invariant has been describing an intent rather than a behavior since then. Under
the fold discipline — a fold is a waypoint, and the pre-fold text is the
restoration target — the blueprint sentence is this issue's restoration target:
closing this issue is what makes it true again, and until then a reader of that
blueprint is being told something the code does not do.

Recorded here rather than weakening the blueprint, because the invariant is
right and the code is wrong — the opposite of the case a fold is for.
