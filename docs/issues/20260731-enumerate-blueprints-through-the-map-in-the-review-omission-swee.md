---
id: 20260731-enumerate-blueprints-through-the-map-in-the-review-omission-swee
num: 169
title: "Enumerate blueprints through the map in the review omission sweep"
status: open
priority: high
labels: [sdlc, review, 000-blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:08:15Z
updated: 2026-07-31T12:08:15Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/plan.md
---

## Description

## Description

`/jim:review`'s omission sweep locates a declared invariant by matching its id
across blueprint **files** rather than enumerating groups through the project
context map. A retired group's blueprint is still a file, so it is still a match.

Concretely: `docs/specs/sdlc/017-coordinated-spec-identity/review.md:146,179`
reported `spec-id-sequencing` as "declared in `docs/specs/sdlc/000-blueprint/spec.md:100`
and again in `docs/specs/jim/000-blueprint/spec.md:233`". The `jim` group had been
split into `sdlc`/`blueprint`/`issue`/`platform` five days earlier; its blueprint
carries `status: retired` and a banner naming the map as its successor, and the
group is absent from `BLUEPRINT.md`.

## Why it matters

The other consumers get this right, which is what makes the sweep the outlier:
`/jim:verify` and the reconcile pass both enumerate groups from the map, so a
retired group is excluded by construction — `jimverify.sh territory BLUEPRINT.md
jim` returns "group not in map".

One file-level read propagated the retired group through five downstream
artifacts, none of which re-checked liveness: an issue, a grouping note, a spec
acceptance criterion, that spec's research, and a plan task with a verify command
asserting the retired file's content. The work was only stopped at build time by a
developer asking why a retired blueprint was being edited.

This recurs for any invariant declared in a group that is later split, merged, or
retired — i.e. every partition operation makes it more likely.

## Fix

Enumerate blueprint-bearing groups through the map in the sweep, the way
`/jim:verify` and the reconcile already do; or, at minimum, read `status:` and
exclude a retired blueprint from the reported set. A retired blueprint is a frozen
record — the reason it is excluded from reconcile and the graph applies equally to
a drift sweep.

Surfaced during the `sdlc/018` build, when the propagated finding reached a task
that would have edited the retired document.
