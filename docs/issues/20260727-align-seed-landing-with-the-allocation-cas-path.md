---
id: 20260727-align-seed-landing-with-the-allocation-cas-path
num: 122
title: "Align seed landing with the allocation CAS path"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-27T05:34:22Z
updated: 2026-07-29T20:05:42Z
origin: docs/specs/platform/008-registry-seed/review.md
---

## Description

The seed's landing path diverged from the allocation CAS (`alloc_cas_append`) in
two ways, both surfaced by the `platform/008` post-build review (Findings 2 and
3). `platform/009` closed the first when it introduced the shared `alloc_publish`
batch-publish step; **the second is what remains and is what this issue now
tracks.**

Line anchors below are current as of the 2026-07-29 verification, against
`skills/file/scripts/jimalloc.sh`.

## Resolved — the in-loop erosion re-check

`alloc_cas_append` hard-fails on a truncated or rewritten coordination history by
re-checking the erosion baseline inside its retry loop (`:835`); the seed's
original landing had no equivalent. `platform/009` routed `alloc_seed_land`
(`:1319`) through `alloc_publish`, which now re-checks erosion on **both**
writable logs on every attempt (`:1250-1259`) — strictly stronger than the
allocation path, which checks only the single logfile it writes. Covered by
`case_jimalloc_seed_publish_detects_erosion` (`tests/jimalloc.sh:1177`).

## Open — allocation and publish are still two land implementations

`alloc_publish` inlines its own `git push` (`:1272`) and `git update-ref`
(`:1279`) rather than calling `alloc_origin_cas` / `alloc_local_cas`, whose only
caller remains `alloc_cas_append` (`:858`, `:865`). The divergence runs through
all three parts of the land step:

| Step | Allocation | Publish (seed + reconcile) |
|---|---|---|
| build commit | `alloc_build_commit` — one blob (`:752`) | `alloc_seed_commit` — up to two (`:1146`) |
| compare-and-swap | `alloc_origin_cas` / `alloc_local_cas` (`:784`, `:772`) | inlined (`:1272`, `:1279`) |
| arm baseline | inline `alloc_update_baseline` (`:859`, `:866`) | `alloc_seed_arm_baselines` (`:1191`) |

The structural reason is unchanged from the original finding: the allocation
helpers take a single logfile plus piped content, while publish needs a
multi-blob commit.

Guarantees are equivalent today, so this is not a correctness gap — the cost is
two implementations kept in sync by convention, where a fix or hardening applied
to one can silently miss the other. `platform/009` held the count at two rather
than three (reconcile, the third registry writer, shares `alloc_publish` with
seed instead of adding a copy) but did not merge the two.

## Fix

Factor the shared land step — tier select → CAS → arm baseline — so the
allocation path and `alloc_publish` share one implementation, generalizing the
commit builder over one-or-many blobs.

Low priority — consistency and maintainability, no behavior change.
