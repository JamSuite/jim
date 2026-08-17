---
id: 20260730-gate-the-realized-spec-ordinal-and-stop-silent-record-loss
num: 150
title: "Gate the realized spec ordinal and stop silent record loss"
status: closed
priority: critical
labels: [id-coordination, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:00Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

The realized ordinal is the one tree/registry-derived token the spec realizer
never revalidates, and two defects follow from it — a silent duplicate-ordinal
rename, and a silently missing durable record. Both are reachable through the
crafted-record vector `sdlc/017`'s security review accepted as
detected-not-prevented; on this path it is **not** detected.

## 1. The drift halt is bypassable

`skills/spec/scripts/reconcile.sh:223` takes `ord="${real##*/}"` and uses it as a
path component (`:226`), a glob (`:227`), a git argument (`:232`) and frontmatter
(`:248`) with no numeric gate.

The allocator's `have` branch emits whatever digits a record carries — it gates
on `^[0-9]+$`, not `%03d` — while the `new` branch canonicalizes with `%03d`
(`skills/file/scripts/jimalloc.sh:665` vs `:711`). So a record

    spec allocate sdlc/18 alpha 20260728

matching a pending `sdlc/P-20260728-alpha` yields `ord=18`. `ordinal_holder`
matches the ordinal as a **literal string**, so it globs `18-*/` and `18/` and
misses the existing `018-alpha` — no halt. On the committed branch
`jimledger.sh rename-tracked`'s basename gate (`^[a-z0-9][a-z0-9-]*$`) accepts
`18-alpha`.

Result: two directories on one numeric ordinal, `id: "18"` in frontmatter,
**exit 0, no warning**. The guarantee the spec exists to provide is defeated
silently. The untracked branch is safe only because `jimfile.sh mv-spec-id`
carries a digit gate — the two rename primitives enforce asymmetrically.

## 2. The durable record silently disappears

Reached with that same ordinal, `record_realized` re-gates each row on
`^…/[0-9]{3,15}$` and `continue`s on failure. The identity is renamed and its
citations swept while its provisional→real mapping never enters the ledger —
again exit 0, no warning. The record the spec requires for later dereferencing,
and the lift the rename-emitting follow-on depends on, is exactly what goes
missing.

## Fix

Four points, upstream first:

1. Gate `ord` with `^[0-9]{3,15}$` in `apply_pending` and halt otherwise.
2. Compare numerically (`10#$ord`) in `ordinal_holder`, so padding variants
   collide instead of passing each other.
3. Normalize the allocator's `have` branch to `%03d` so it matches `new` —
   the asymmetry that feeds this.
4. Make a `record_realized` row rejection **loud**: warn and set the failure
   status rather than dropping it. Ideally unreachable once (1) lands, but a
   silent drop is the wrong failure mode regardless.

Fixture the padding-variant ordinal and the bare-`<NNN>` occupant cases; both
are in the test debt this review exposed
([[20260730-close-the-coordinated-spec-identity-fixture-gaps]]).

See [[20260730-spec-creation-halts-only-on-an-exact-name-collision]] — the same
halt, missing on the creation path. A shared numeric "does any sibling hold this
ordinal?" predicate would close both.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30), where these are the two recorded security regressions.
