---
id: 20260723-fix-ripple-engine-sweep-order-for-renumbered-self-refs
num: 87
title: "fix ripple-engine sweep order for renumbered self-refs"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition, ripple-engine]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T03:21:43Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/020-partition-merge/review.md
---

## Problem

The partition ripple-engine's `rewrite` materialize order runs `rewrite-identity`
**before** `rewrite-refs`, but the two verbs treat spec numbers differently:

- `rewrite-identity` rewrites a moved body's typed `group/NNN` refs **preserving
  the number** (`<src>/002` → `<target>/002`).
- `rewrite-refs` **changes** numbers via the renumber-append / renumber remap
  (`<src>/002` → `<target>/008`).

So an **intra-group numbered self-reference** inside a moved body is first
rewritten by `rewrite-identity` to `<target>/002`, after which `rewrite-refs`'
remap whitelist key (`<src>/002`) no longer matches — leaving a wrong ref that
may even collide with a real pre-existing `<target>/002`.

## Scope

- **Pre-existing** — surfaced by the spec-048 (merge) post-build review, but
  **split ships the identical two-verb, same-order sweep**, so it is a property
  of the shared ripple engine (rename is unaffected — numbers are stable there).
- **Narrow exposure** — only triggers on an intra-group numbered self-reference
  in a moved numbered spec's body; cross-group refs use other slugs that
  `rewrite-identity` leaves untouched.
- Merge (spec 048) correctly reuses the shipped verbs as-is (its AC 10/11 "no
  code change" reuse is sound); this is not a spec-048 defect.

## Suggested action

Reconcile the two sweeps against the shared engine so a renumbering move remaps
a numbered self-ref correctly — e.g. run the reference sweep (`rewrite-refs`,
number-changing) before the identity rewrite (`rewrite-identity`,
number-preserving), or scope `rewrite-identity` to skip typed `group/NNN` refs
that the remap will re-point. Add a regression test with an intra-group numbered
self-ref in a moved body over both the split and merge arms.

## Origin

`docs/specs/blueprint/020-partition-merge/review.md` — Deviations & feedback (the
AC-omission investigation).

## Resolution

Fixed under spec `blueprint/023` (`docs/specs/blueprint/023-partition-ref-sweep/`). Scoped as
a bug spec, built TDD, reviewed `aligned` (0 findings), and folded into the
`jim` blueprint.

Of the two proposed remedies, **scoping won, not reordering** — because scoping
the spec surfaced a **second, order-independent manifestation** this issue's
"reorder the sweeps" proposal could not fix:

- **M1 (this issue's case):** an intra-group renumbered self-ref
  (`src/002` → `target/008`) — reordering *would* fix it.
- **M2 (newly surfaced):** on the split extraction arm, a moved body's ref to a
  spec that stays in the **remainder** (`old/005`) is group-renamed by the
  identity pass to `child/005` in **either** order — the remap's remainder
  identity row (`old/005 → old/005`) is a no-op, so reordering cannot help.

The fix is an opt-in **`--skip-typed-refs`** flag on `rewrite-identity`: on a
renumbering split or merge the identity pass leaves typed `group/NNN` refs to
`rewrite-refs`' remap sweep exclusively (the two verbs then commute over typed
refs); rename passes no flag and is byte-identical. Regression tests cover both
arms and both manifestations, and a prose-pin test guards the four canonical
invocation lines against a future flow dropping the flag.

Verified: M1 → `target/008`, M2 → `old/005`; full suite 697/697 green.
Ships on `feat/blueprint`; `fix(partition)` commit carries `Spec: blueprint/023` +
`Issue: 87/20260723-fix-ripple-engine-sweep-order-for-renumbered-self-refs`.
