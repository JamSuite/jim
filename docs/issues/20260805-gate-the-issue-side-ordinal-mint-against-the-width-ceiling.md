---
id: 20260805-gate-the-issue-side-ordinal-mint-against-the-width-ceiling
num: 223
title: "Gate the issue-side ordinal mint against the width ceiling"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T01:53:47Z
updated: 2026-08-05T10:21:33Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
---

## Description

The spec side gates a freshly minted ordinal against `alloc_valid_ord`; the issue
side does not. Past the ceiling the issue registry stops coordinating, silently
and permanently.

- `alloc_next_id_spec:1022-1025` — `if ! alloc_valid_ord "$next"; then … group
  exhausted … return 1`
- `alloc_reconcile_realize_spec:1326-1329` — same gate
- `alloc_next_num_issue:1032-1037` — **no gate**, returns `$((max + 1))`
- `alloc_reconcile_realize:1157-1160` — **no gate**, `ord=$next; next=$((next + 1))`

At the 15-digit ceiling (`ALLOC_MAX_ORD_DIGITS=15`, `:831`):

```
issue side  → 1000000000000000   rc 0     (a 16-digit ordinal)
spec side   → error: group exhausted …    rc 1
```

No overflow and no wrap — 1e15 is far inside 2^63. The consequence is that the
record is **write-only**: `alloc_fold_max_issue:948` filters every candidate
through `alloc_valid_ord`, so the record just written is invisible to the next
mint.

```
next after the 16-digit record was written: 1000000000000000
fold_max sees:                              999999999999999
```

**Every subsequent issue allocation mints the same ordinal, forever**, with no
error on any run. The registry silently stops doing the one thing it exists for.

A prior judge recorded this as "reachable only if a crafted record already sits at
the 15-digit ceiling". That is too narrow. `alloc_seed_derive_issues:1487` gates
the frontmatter ordinal with the same `alloc_valid_ord`, which *admits* 15 digits,
so ordinary user-editable issue markdown seeds the ceiling through the supported
bootstrap:

```
$ cat issues/20260101-ceiling.md    # frontmatter: num: 999999999999999
$ alloc_seed_derive_issues issues/  → issue allocate 999999999999999 …
$ … | alloc_next_num_issue          → 1000000000000000
```

The constant's own header at `:829-831` states the invariant this violates: "an
ordinal the fold skips as malformed must also be one the seed refuses, or the
allocator could mint a repository that can never be rebuilt into a registry from
its own tree."

## Proposed action

Add the `alloc_valid_ord` recheck to `alloc_next_num_issue` and
`alloc_reconcile_realize`, mirroring `:1022` and `:1326` — two lines each, with
the same "group exhausted" refusal so the failure is loud rather than a repeating
ordinal.

Fixture: seed a ceiling ordinal from frontmatter, mint, and assert refusal rather
than a 16-digit id.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 10). Recorded as a non-defect
judge observation in the prior handoff's § 5; this review re-measured it and found
both the consequence and the reachability understated.

## Resolution (2026-08-05)

Fixed as proposed. `alloc_next_num_issue` refuses with "issue ordinals
exhausted" rather than returning a 16-digit ordinal, mirroring
`alloc_next_id_spec`'s "group exhausted". `alloc_reconcile_realize` blocks the
identity per-identity — a `-` ordinal and the claimants on stderr — mirroring the
duplicate-durable-id refusal directly beside it, so the rest of the batch still
realizes.

The issue's re-measurement of the reachability was the load-bearing part and it
holds: the seed admits a 15-digit ordinal from ordinary issue frontmatter, so the
ceiling is reachable through the supported bootstrap and not only by a crafted
record. The consequence was worse than "no ordinal left" — the record was
write-only, invisible to the very fold that computes the next mint, so every
later allocation returned that same ordinal forever with no error on any run.

Both fixtures mutation-tested: deleting either recheck turns its case red.
