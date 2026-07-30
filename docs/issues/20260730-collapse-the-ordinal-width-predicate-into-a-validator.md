---
id: 20260730-collapse-the-ordinal-width-predicate-into-a-validator
num: P-20260730-collapse-the-ordinal-width-predicate-into-a-validator
title: "Collapse the ordinal-width predicate into a validator"
status: open
priority: low
labels: [id-coordination, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T01:09:08Z
updated: 2026-07-30T01:09:08Z
origin: docs/specs/platform/011-rename-path-correctness/review.md
---

## Description

Surfaced by the post-build review of `platform/011` (rename-path correctness).

`platform/011` introduced `ALLOC_MAX_ORD_DIGITS` as the single value deciding
what counts as a legal ordinal — read by the high-water folds and by the
registry bootstrap, so the allocator can never mint an ordinal the bootstrap
refuses.

That requirement is met exactly. The spec's criterion asked for **one shared
value, "not two that happen to agree"**, and there is one.

## The residue

The *predicate* around that value is now written out five times in
`skills/file/scripts/jimalloc.sh`:

| Site | Context |
| :--- | :--- |
| `alloc_fold_max_spec` | skip an over-wide record ordinal |
| `alloc_fold_max_issue` | skip an over-wide record ordinal |
| `alloc_next_id_spec` | refuse when the next ordinal would exceed the width |
| `alloc_seed_derive_specs` | reject an over-wide spec-directory ordinal |
| `alloc_seed_derive_issues` | reject an over-wide issue `num` |

All five are `(( ${#x} > ALLOC_MAX_ORD_DIGITS ))`. Four of them additionally
pair it with the same `^[0-9]+$` numeric-class check.

This is a smaller instance of the pattern the spec existed to remove. The
failure mode is not drift in the *value* — that is shared now — but drift in the
*comparison*: a future edit that changes one site to `>=`, or adds the numeric
check to one path and not another, produces exactly the read-path/bootstrap
disagreement `platform/011` closed, and no current test would catch it. The
round-trip fixture (`fold_max_spec_mint_is_seedable`) pins that a minted ordinal
seeds successfully, but only at three digits — it would not notice a
one-off boundary skew.

## Proposed fix

Add an `alloc_valid_ord` one-liner beside the existing `alloc_valid_token` /
`alloc_valid_specid` validators — same shape, same file, same role — folding
both the numeric-class check and the width check:

```
alloc_valid_ord <token>   # exit 0 iff pure digits and no wider than the limit
```

Then have all five sites call it. That puts ordinal legality in one place the way
the id boundary already is, and matches the file's established convention that a
validation rule lives in exactly one function.

## Why low

No defect today — all five sites agree, and the tests confirm the read path and
the bootstrap accept the same set. This is structural hygiene that makes the
guarantee hold by construction rather than by five sites happening to match.
