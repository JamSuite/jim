---
id: 20260730-memoize-the-id-validation-boundary-in-the-allocator-read-path
num: 142
title: "Memoize the id-validation boundary in the allocator read path"
status: open
priority: medium
labels: [id-coordination, performance, availability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T00:50:00Z
updated: 2026-07-30T00:50:00Z
origin: docs/specs/platform/011-rename-path-correctness/plan.md
---

## Description

Surfaced while building `platform/011` (rename-path correctness).

`alloc_valid_token` validates a token by shelling out to `jimfile.sh valid-id`
— one `bash` process per call. That is the deliberate single-validation
boundary, and it is correct; the cost is the boundary crossing, paid per record
on every read-path pass.

## Measured

A crafted spec log of N `group rename` records, timed through
`alloc_group_alias_map`:

| records | wall clock |
| :--- | :--- |
| 200 | 10s |
| 400 | 20s |
| 800 | 45s |

Linear, so the fold's own algorithm is sound — roughly 56ms per record, all of
it forks. `alloc_group_alias_map` validates both tokens of each record, and
`alloc_next_id_spec` builds the map **twice** per call (once to check whether
the queried group was renamed away, once inside `alloc_fold_max_spec`), so the
constant is doubled on the path every allocation takes.

## Why it is worth tracking

Two things, neither of which is about current scale — the live spec log holds
four group records, where this is unmeasurable:

- **Log length is attacker-influenceable.** The coordination branch is writable
  by anyone who can push it. The erosion guard catches a *truncated or
  rewritten* history; it does not bound *growth*. Appending records is the one
  registry mutation that is supposed to be cheap and legitimate, so a large
  append is not itself a detectable anomaly — it just makes every subsequent
  allocation slow, which reads as flakiness rather than as an attack.
- **The doubled map build is avoidable.** Design Decision 2 accepted two passes
  over the log as free, and per pass it is. It compounds with the per-record
  fork cost rather than standing alone.

## Proposed fix

Memoize validated tokens for the life of one script invocation — an
associative array keyed on the token, holding the boundary's verdict. Tokens
repeat heavily in these logs (a group name recurs once per record in its
group), so the hit rate is high and the memo cannot go stale within a single
run. This preserves the single-boundary invariant exactly: `jimfile.sh
valid-id` stays the only implementation of the rule, and the cache only avoids
asking it the same question twice.

Deciding whether `alloc_next_id_spec` should also pass its already-resolved
group through to the fold, instead of having the fold rebuild the map, belongs
with the same change.

## Not a regression

This is pre-existing in kind. The resolvers already pay the same per-record
fork cost over spec records, and have since the allocator shipped. What
`platform/011` added is a second record class that pays it. Filing it as the
measurement that makes the existing cost concrete, not as damage this build
did.
