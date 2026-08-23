---
id: 20260728-new-sh-mixed-pin-slug-xor-num-registry-on-disk-skew
num: 132
title: "new.sh mixed-pin (--slug XOR --num) registry/on-disk skew"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-28T21:39:38Z
updated: 2026-07-28T21:39:38Z
origin: docs/specs/issue/010-ordinal-coordination/review.md
---

## Description

`new.sh` resolves issue identity via `jimalloc.sh allocate issue` when `--slug`
and/or `--num` are unset. The fallback fires when **either** flag is unset, but
`allocate issue` always reserves a full pair (durable id + display ordinal) in
one CAS — so when a caller pins exactly one of the two, the unused half of the
freshly-allocated pair is discarded. The registry then records an ordinal/id
pair that can diverge from the id/ordinal actually written to disk.

## Status

Latent: no current caller pins exactly one of `--slug`/`--num` (the USAGE
documents them as a pre-resolved pair, and `/jim:issue add` passes both). But
the mixed-pin path is reachable and would produce registry↔on-disk skew.

## Fix

Allocate only when **both** `--slug` and `--num` are unset; when exactly one is
pinned, reconcile the pinned half instead of discarding the allocated one (or
reject the mixed-pin as unsupported). Add a mixed-pin test covering the
registry/on-disk agreement.
