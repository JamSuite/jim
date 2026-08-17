---
id: 20260729-allocate-spec-under-provisional-mints-an-unrealizable-identity
num: 135
title: "allocate spec under provisional mints an unrealizable identity"
status: closed
priority: medium
labels: [id-coordination, provisional]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-29T21:02:34Z
updated: 2026-07-31T05:51:48Z
origin: docs/specs/platform/011-rename-path-correctness/spec.md
---

## Description

Surfaced while scoping `platform/011` (rename-path correctness), by probing what
provisional mode does per kind.

Under `id_coordination_unreachable = provisional` with an unreachable
coordination point, `allocate spec` hands back a whole-identity provisional:

```
allocate spec platform "some new thing"  →  platform/P-20260729-some-new-thing
reconcile spec                           →  error: spec reconcile is not implemented
```

So the allocator issues a spec identity that nothing can ever realize.
`alloc_provisional_spec`'s own docstring records the asymmetry — it defines the
spec provisional grammar while spec-side reconcile is deferred, because realizing
a provisional spec renames a directory rather than editing a frontmatter field
the way the issue consumer does.

## Why it is latent, and why that ends soon

Nothing calls `allocate spec` yet — the spec consumer is unwired. The moment that
wiring lands, every spec created where the coordination point is unreachable gets
a `P-` identity with no realization path. jim's own agent sandbox is exactly that
environment and its config already selects `provisional`, so this would fire on
first use rather than as an edge case.

## Fix

Either:

- refuse `allocate spec` under `provisional` — a clear "spec allocation cannot
  defer; use the host" beats minting a dead identity — until spec-side reconcile
  exists; or
- implement spec-side reconcile, which requires rename/redirect records and so
  composes with the rename-emitting work.

The first is small and closes the trap now; the second is the eventual answer.

## Relation to existing issues

Distinct from both neighbours: the spec-consumer wiring owns *calling* the
allocator, and the sandbox-provisional decision owns *whether jim selects the
mode*. This issue is the allocator's own missing guard — it should not hand back
an identity whose realization path is absent, regardless of who calls it or why
the mode is set.

## Resolution (2026-07-31)

Closed by `sdlc/017`. The realization path exists: `jimalloc.sh reconcile spec
[--apply]` does a keyed find-or-allocate on `(group, slug, issuance-date)`, and
`skills/spec/scripts/reconcile.sh` renames each pending directory onto its
ordinal, rewrites the frontmatter `id:`, sweeps citations across the content
roots, and records the provisional→real mapping durably on the specs-root ledger.

**The fork resolved the second way this issue proposed** — implement realization
rather than refuse `allocate spec` under `provisional`. Refusing was the cheaper
close, and it was rejected because it makes offline scoping impossible: jim
treats working without the coordination point as a supported mode, not a degraded
one. Issuance without realization would also have left #135 as a permanent state
rather than a trap, which is why `sdlc/017` scoped the whole loop.

Verified in production: eighteen provisional issue ordinals filed offline and
realized in one host batch, and the spec path exercised end to end.

Worth carrying forward — the property this issue asked for in the abstract ("the
allocator should not hand back an identity whose realization path is absent") is
satisfied by the path now existing, not by a check that enforces it. If another
kind gains provisional issuance before its realizer, the same trap returns
silently.
