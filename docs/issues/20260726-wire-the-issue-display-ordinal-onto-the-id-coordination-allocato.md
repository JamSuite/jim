---
id: 20260726-wire-the-issue-display-ordinal-onto-the-id-coordination-allocato
num: 111
title: "Wire the issue display ordinal onto the id-coordination allocator"
status: closed
priority: high
labels: [id-coordination, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T19:01:55Z
updated: 2026-07-29T19:38:53Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

The issue display ordinal (`#42`) is derived at `INDEX.md` render time today, so reindex and concurrent branches produce duplicate ordinals and hard `INDEX.md` git collisions.

Once `platform/007` ships the coordination allocator, wire `/jim:issue` filing to allocate the ordinal **once** via the mechanism and store it in the issue frontmatter; `INDEX.md` becomes a pure, idempotent projection with no allocation authority, so duplicate ordinals become structurally impossible. `show #42` resolves via frontmatter/registry lookup.

This consumer also introduces the `issue_placement` config (content-on-branch vs reservation-only) that `platform/007` deferred as a consumer-side concern.

Follow-on to `platform/007` (foundation); this is the `issue`-group consumer slice.

## Resolution

Shipped as spec `issue/010` (Coordinated issue display ordinals), whose `origin`
is this issue. All 11 ACs met; the post-build review is `minor-drift` over
`90b9dd0..cb692e9` (22 commits, 7 files, +673/−60), the drift being four code
comments that cite artifact IDs — a convention slip with no functional gap,
spun out as
[[20260728-remove-spec-id-citations-from-issue-group-script-comments]] (#131).

What landed against this issue's ask:

- **Allocate once, store in frontmatter.** `new.sh` resolves an unset
  slug/ordinal as a coordinated pair through `jimalloc.sh allocate issue`, and
  the identity is durable at the coordination point before the file is written —
  a failed reservation writes no issue file at all.
- **`INDEX.md` is a pure projection.** `index.sh` emits the stored `num`
  verbatim with no allocation authority, so regeneration can neither introduce
  nor renumber a duplicate ordinal.
- **`show <ordinal>` resolves** through that stored ordinal, including one
  realized from an earlier provisional.
- **Beyond the original ask:** the full provisional + reconcile loop, wiring
  `platform/009`'s frozen consumer contract — offline filing yields a
  structurally distinct `P-…` ordinal, and `/jim:issue reconcile` realizes
  pending provisionals preview-then-apply.

Live on jim: the registry's `issues.log` carries 134 records, ordinals 131–134
allocator-issued at filing time.

**One clause did not ship — `issue_placement`.** Where a filed issue's *content*
lives (on-branch vs a shared destination) was carved out of `issue/010` as a
separable, larger concern with its own disclosure surface; no `issue_placement`
key exists in `jimconf.sh` today. Tracked as
[[20260728-spec-issue-placement-config-for-issue-content-location]] (#126).

Other deferrals, all tracked: batch filing coordinates per item (one CAS per
issue) — collapsing an end-of-run candidate batch into a single CAS is
[[20260728-spec-batch-cas-candidate-batch-allocation-7a-rework]] (#127); and the
review's three low-severity robustness edges are
[[20260728-new-sh-mixed-pin-slug-xor-num-registry-on-disk-skew]] (#132),
[[20260728-reconcile-sh-provisional-detection-not-fence-bounded]] (#133), and
[[20260728-reconcile-sh-swallows-the-index-regen-exit-code]] (#134).
