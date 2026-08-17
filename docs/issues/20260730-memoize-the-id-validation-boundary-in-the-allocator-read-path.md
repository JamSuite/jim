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
updated: 2026-08-02T01:07:27Z
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

## Addendum — 2026-08-02: partly done in-process, and the measurement moved

`platform/012` put an in-run cache inside `alloc_valid_token` itself, so each
distinct token crosses `jimfile.sh` once per process rather than once per use.
That removes the repeat forks a whole-registry read pays, where the same group,
slug or id is revalidated on both the tree side and the record side. The cache
sits inside the boundary rather than beside it, so no call site has to remember
a faster variant, and it is not a fourth copy of the rule.

Two things this build learned that change what remains here:

- **The cache carries a hazard the plain fork did not.** Indexing on a raw token
  means an empty one — produced by any record short a field — is not a usable
  array subscript. That shipped, and broke the read path outright until fixed
  by rejecting the empty token ahead of the cache. Anything further along these
  lines should carry a fixture for a truncated record.
- **The dominant cost is not this boundary.** Profiled on the live collection,
  the sweep's ~14 s breaks down as ~6.9 s in `alloc_seed_derive_issues`, ~2.2 s
  in a second per-file pass, ~1.2 s in the spec derivation, and **167 ms** in
  the two classification cores. The cost is per-file frontmatter `sed` forks,
  not id validation. That is issue 201, and it is a different problem — **do not
  close 201 against this issue, and do not assume fixing this one fixes 201.**

Still open for the cross-process case: the derivation, each classifier, and each
group probe run in their own subshell, so the cache is rebuilt per subshell and
does not carry between them.
