---
id: 20260805-disclose-what-catch-up-withheld-instead-of-claiming-every-identi
num: 237
title: "Disclose what catch-up withheld instead of claiming every identity has a record"
status: open
priority: high
labels: [id-coordination, alloc, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:12Z
updated: 2026-08-05T22:20:12Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

`catch-up` prints "nothing to append — every tree identity already has a record"
while silently withholding identities the sweep just reported as missing.

`alloc_catchup_compute:3144-3146` unsets `want_spec` entries whose group the
registry has renamed away. The withheld ids are removed from the append set and
never added to `CU_BLOCKED` — only the group row is — so `:3249` and `:3322`
assert total coverage:

```
sweep
  -> drift:
       missing-record            spec   dashboard/002  beta     <- named
       tree-on-vacated-ordinal   spec   dashboard/001  ...
       tree-group-renamed-away   group  dashboard      ...
     rc=3

catch-up --apply
  -> catch-up: nothing to append - every tree identity already has a record
     cannot repair (an operator decides which side is right):
       tree-on-vacated-ordinal   spec   dashboard/001  ...
       tree-group-renamed-away   group  dashboard      ...
     rc=3
```

`dashboard/002` appears nowhere in catch-up's output. With a healthy spec
alongside it the counts mislead the same way: "appended 1 record(s)" with the
withheld id never mentioned.

This is the shape issue 229's own Resolution invokes to reject one of its proposed
actions — "a repair verb that quietly skips what it could not fix, which is the
shape the cluster's own practice 6 exists to forbid." The build rejected a silent
filter for `SPENT-TREE` and shipped one for `GROUP-RETIRED`. The `SPENT-TREE` arm
does name its withheld id; this one does not. The test that was written asserts
nothing is appended and never asserts the operator is told what was withheld.

Related, same verb: `catch-up` is the only verb in the derive-from-tree family
that does not disclose what its derivation passed over. `seed` prints "not
recorded: N reserved blueprint slot(s), N pending provisional identity(ies)" and
`sweep` prints its "not covered" block; `catch-up` prints neither, though all
three share `alloc_seed_derive_specs`/`_issues`.

## Proposed action

Add the withheld specs to `CU_BLOCKED` under the retired group's row (or their own
class) so they are named as loudly as what was appended, and make the summary
sentence conditional on there being nothing withheld.

Give `catch-up` the same non-coverage disclosure `seed` and `sweep` already emit.

Fixture: a retired group holding one unrecorded spec, asserting the spec id
appears in the output and the summary does not claim total coverage.
