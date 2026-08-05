---
id: 20260805-restore-alloc-group-has-records-s-locals-and-correct-its-header
num: P-20260805-restore-alloc-group-has-records-s-locals-and-correct-its-header
title: "Restore alloc_group_has_records's locals and correct its header"
status: open
priority: medium
labels: [id-coordination, registry, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:47Z
updated: 2026-08-05T01:53:47Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

Two defects in one 30-line function, both introduced by the commit that widened
it, and both of the class the same cluster filed other issues about.

**1. Missing `local rdst rdok`.** `jimalloc.sh:2702` declares:

```bash
local group="$1" i c1 c2 c3 rk rsrc rsok
```

while `:2722` consumes five fields:

```bash
while IFS=$'\t' read -r rk rsrc rsok rdst rdok _ _ _; do
```

`a21f55d` widened the read from `rk rsrc rsok _ _ _ _ _` to include `rdst rdok`
and did not extend the declaration. Every one of the other nine sites in the file
that reads the same `alloc_rename_scan` 5-tuple declares all five (`:572`, `:626`,
`:732`, `:856`, `:906`, `:951`, `:1584`, `:1734`, `:3675`) — `:2702` is the sole
outlier.

Latent, not currently reachable: all three production call sites (`:2800`,
`:3418`, `:3651`) pipe into the function, so it runs in a pipeline subshell and
`lastpipe` is set nowhere in the repo. Demonstrated clobbering with an
un-subshelled here-string call:

```
victim locals after callee: rdst=ui rdok=y     ← was rdst=MY-DEST before the call
```

The tests already call it in that leaky form (`tests/jimalloc.sh:851`, `:854`,
`:864`), so the suite exercises the leaky path and asserts nothing about it. The
dangerous neighbour is `:3651`, inside `alloc_lift_states`, which holds live
`rdst`/`rdok` locals at `:3675` — converting that call site to a here-string would
corrupt the lift's rename index mid-loop.

This is the exact class issue #217 was filed for, in the same change that fixed
#217.

**2. The function's header is now false.** `:2696-2700` still reads:

> exit 0 iff the registry holds any valid record for `<group>`: its group-allocate
> record, or a spec-allocate record under it.

The body has **four** arms: group-allocate, spec-allocate, spec-rename source, and
group-rename destination. `a21f55d` added the fourth, updated the *body* comment
at `:2715-2720`, and left the header contract. A reader trusting the header
concludes the opposite of what the function does — and under the project's
"comments state current behavior" rule the header is wrong, not merely
incomplete.

## Proposed action

Add `rdst rdok` to the `local` list at `:2702`. Rewrite the header at `:2696-2700`
to name all four coverage arms, or to state the rule the body comment already
gives ("the registry knows this name") rather than enumerating a stale subset.

The leak check at `tests/jimalloc.sh:730` is name-pinned (`declare -p c4 canon`)
and covers one function, so it cannot see this. Whether that check should become a
file-wide invariant is a separate question — it would need an allowlist for `rn`,
`live` and `spent`, which are deliberate out-params.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 10). Found by the adversarial
omission sweep's mechanical scope checker over all 27 functions the change
touched; `alloc_group_has_records` was the only genuine miss.
