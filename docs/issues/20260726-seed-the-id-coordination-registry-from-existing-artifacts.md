---
id: 20260726-seed-the-id-coordination-registry-from-existing-artifacts
num: 114
title: "Seed the id-coordination registry from existing artifacts"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T19:01:58Z
updated: 2026-07-29T19:38:53Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

A migration/`seed` step builds the initial registry from existing spec directories and the issue `INDEX.md` so the allocator has a correct baseline the moment a project adopts it (otherwise the first allocation recomputes from an empty log and reissues consumed IDs).

Open sub-fork to decide during scoping — historical **duplicate** issue ordinals:
- renumber the younger dupes once at seed time (breaks some old handles, once, then clean), **or**
- grandfather them with dup-tolerant resolution (`show #42` may return two candidates) forever.

Follow-on to `platform/007` (foundation); `platform`-group.

## Resolution

Shipped as spec `platform/008` (Registry seed from existing artifacts), whose
`origin` is this issue — a one-time `jimalloc.sh seed` verb, preview-then-apply.
All 10 ACs functionally met; the post-build review is `minor-drift` over
`bed0317..baa7683` (10 commits, 5 files, +683/−9), the drift being a bounded
reserved-slot normalization edge (below).

What landed: one allocate record per spec directory and one group-allocate per
distinct group, derived from the tree; one allocate record per issue, read from
each issue file's **frontmatter** rather than the regenerable `INDEX.md`
projection, which can lag. The whole seed lands as a single all-or-none commit;
a kind whose log is already non-empty is refused rather than merged; no spec
directory is renamed and no issue file is rewritten; and every tree-derived
token passes the `is_valid_id` boundary before it reaches git.

Live on jim: the registry holds 64 spec records, 4 group records
(`blueprint`, `issue`, `platform`, `sdlc`), and 134 issue records, with no
`<group>/000` record — the reserved blueprint slot is correctly skipped.

**The open sub-fork was resolved as neither branch.** Rather than renumbering
younger duplicates or grandfathering them with dup-tolerant resolution, the seed
**halts and names the conflicting artifacts**, issuing no records and leaving
the fix to the developer (AC 6). A seed that silently reconciles a conflict
produces a registry that misrepresents the repo, and every later allocation
inherits that lie; stopping keeps the registry's first state provably faithful.

Known limits recorded at ship time, not gaps in this issue: the seed captures
materialized artifacts only, so it cannot reproduce the vacated-ordinal
high-water for a retired or partition-source group — jim's own retired `jim`
group is exactly that case, and establishing the floor plus the redirect records
that keep old citations resolving belongs to the rename-emitting follow-on
[[20260726-emit-rename-split-redirect-records-and-wire-jim-partition-batche]]
(#113).

Residuals, all tracked: the reserved-slot skip is a literal `"000"` match rather
than a numeric test, and the spec ordinal has no digit-length cap —
[[20260727-normalize-seed-reserved-slot-skip-and-spec-ordinal-magnitude]]
(#121); the landing path's parity with the allocation CAS —
[[20260727-align-seed-landing-with-the-allocation-cas-path]] (#122), now half
closed, since `platform/009`'s shared `alloc_publish` gave `alloc_seed_land` the
in-loop erosion re-check, while allocation and publish remain two
implementations; and catching a
*non-empty* log up to the tree, which the one-time bootstrap deliberately
refuses — [[20260728-registry-drift-catch-up-has-no-incremental-seed-verb]]
(#130).
