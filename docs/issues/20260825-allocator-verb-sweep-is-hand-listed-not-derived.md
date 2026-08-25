---
id: 20260825-allocator-verb-sweep-is-hand-listed-not-derived
num: P-20260825-allocator-verb-sweep-is-hand-listed-not-derived
title: "Allocator verb sweep is hand-listed, not derived"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [testing, docs, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T07:15:45Z
updated: 2026-08-25T07:15:45Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

`case_docsurfaces_registry_verbs_reach_every_surface` checks that three
allocator verbs reach README, WORKFLOW and the blueprint feature doc — from a
list written into the test:

```
local -a verbs=('sweep' 'catch-up' 'lift')
```

The case's own comment says "a fourth verb, or a fourth surface, has to be added
everywhere or fail here". A fourth surface would, because the surfaces are
looped. A fourth verb would not: nothing connects that array to the script, so a
verb added to `jimalloc.sh` and to no document passes this check in silence.
That is the omission class the sweep exists to catch, reintroduced one level up.

## Why it was not derived

The other three rosters now derive from code — `jimledger.sh`'s dispatch,
`migrate.sh` and `backfill.sh`'s usage text, `jimconf.sh keys`. The allocator
cannot be derived the same way because its verbs are not one population.
`allocate`, `peek` and `resolve` are called by other scripts and belong in no
operator table; `seed`, `sweep`, `catch-up` and `lift` are hand-run and belong
in all of them. The script draws no line between the two, so a sweep reading its
dispatch or its usage text would demand rows for verbs that should not have any.

The gap is real rather than theoretical: `lift` shipped and never reached the
script's own header roster, which listed the commands and stopped at `catch-up`.
That was corrected in `ec97331`; nothing would have caught it.

## Direction

Give the script a mechanical mark for the hand-run family, and derive the sweep
from that mark. A comment marker on each hand-run verb's definition is the
cheapest form and matches how this project records other cross-file facts, but
the choice is a small design question rather than an obvious one — a separate
usage section for operator verbs would also be derivable, and would put the
distinction where a reader already looks.

`seed` is worth deciding on at the same time. It is hand-run like the other
three and appears in neither the test's array nor the operator tables, so
whatever mark is chosen has to say whether a one-time bootstrap is an operator
verb that owes rows or a setup step that does not.

Surfaced by the census behind
[[20260823-sweep-config-keys-and-migrate-subcommands-against-their-referenc]],
which found four hand-enumerated rosters in the project. Three are now derived
from code; this is the fourth.
