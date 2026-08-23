---
id: 20260726-wire-spec-id-allocation-onto-the-id-coordination-allocator
num: 112
title: "Wire spec-ID allocation onto the id-coordination allocator"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T19:01:56Z
updated: 2026-07-31T05:51:48Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

`/jim:spec` assigns `group/NNN` by listing the group on the current branch (via `jimfile.sh next-id`), which two branches on separate clones compute identically and then collide on — and a spec ordinal is expensive to unwind because it is already frozen in directory paths and commit trailers.

Once `platform/007` ships, reserve `group/NNN` through the allocator at ID-assignment time in `/jim:spec` instead of deriving it from the tree. The spec directory is still created on the feature branch; the registry reservation always runs ahead of content on the coordination branch (an abandoned branch leaves a permanent gap, which is fine).

Follow-on to `platform/007` (foundation); this is the `sdlc`-group consumer slice.

## Resolution (2026-07-31)

Closed by `sdlc/017` (coordinated spec identity). `/jim:spec` binds through
`jimalloc.sh allocate spec <group> "<title>"` at spec-write time, with an
advisory `peek spec` at interview open that reserves nothing — so the
reservation still runs ahead of content on the coordination branch, as this
issue asked, while an abandoned interview burns no ordinal.

The offline case this issue did not anticipate is covered rather than traded
away: where the coordination point is unreachable, scoping completes on a
reserved provisional identity that `/jim:spec reconcile` later realizes onto a
real ordinal. Wiring the allocator did not cost the ability to scope offline.

**Carve-outs, tracked.** The mechanism shipped; its safety did not. The
registry-vs-tree drift halt is bypassable on both the realize and creation paths
([[20260730-gate-the-realized-spec-ordinal-and-stop-silent-record-loss]],
[[20260730-spec-creation-halts-only-on-an-exact-name-collision]]), the path
helper composes directories that do not exist
([[20260730-define-how-a-provisional-spec-dir-resolves-through-the-path-help]]),
and the group's own blueprint still declares the pre-allocator grammar
([[20260730-fold-spec-id-sequencing-to-admit-provisional-identities]]). Those are
`sdlc/017`'s own acceptance criteria rather than new scope, grouped as C′ in
`docs/notes/20260728-id-coordination-issue-grouping.md`.

Separately, the registry still holds no `spec allocate` record for `platform/011`
or `sdlc/017` — a consumer stops new drift, it does not repair drift that
predates it ([[20260730-align-the-registry-with-tree-scan-era-spec-ordinals]]).
