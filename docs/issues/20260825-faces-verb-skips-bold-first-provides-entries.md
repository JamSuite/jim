---
id: 20260825-faces-verb-skips-bold-first-provides-entries
num: 374
title: "faces verb skips bold-first Provides entries"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [verify, 000-blueprint, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T05:21:54Z
updated: "2026-08-26T08:43:55Z"
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

`jimverify.sh faces` recognizes a `Provides` entry only when its first token is
backticked. An entry leading with bold text is not emitted as a `provides` row,
so every mechanical consumer of the face is blind to it.

## What is invisible today

The verb slugifies the leading backticked token to key each provides row.
Running it over the `issue` group's face returns ten rows where the face carries
twelve entries. The two it drops:

- **§ 7a candidate-batch contract** — the canonical fileable bar and emitter
  call shape every surfacing skill in the project is bound by
- **Untrusted-issue-content discipline** — the canonical delimiter form for any
  agent handoff of issue content

Both are declared surfaces other groups depend on. `sdlc` and `blueprint` each
name `issue.candidate-batch-contract` in their own `Requires` faces, so the edge
exists in the derived graph while the provider-side entry backing it cannot be
read mechanically.

## Two consequences

**The face-size trend undercounts.** `faces` and `faces_max` feed the reconcile
pass's outcome counters and the face-growth signal. A face can gain a bold-first
entry and the counter will not move, so growth reads as flat.

**The contract floor cannot ground those edges.** Checks that locate a
provider-side surface have nothing to match for an entry the verb does not emit,
so those edges fall to judgment where a peer entry is checked mechanically.

## How it surfaced

Writing a new provides entry in the obvious shape produced an entry a person
could read and no tool could see — half a declaration, which is the failure the
declaration exists to prevent. Reshaping it to lead with the backticked token
moved the project face counters from 22 to 23 and the group maximum from 9 to
10. The reshape is a workaround: the convention is undeclared, so the next
author faces the same coin-flip.

## Direction

Either teach the verb to key an entry from its first bold span when no leading
backticked token exists, or state the leading-backtick requirement in the
blueprint template and check it, so a face entry no tool can see fails authoring
rather than passing silently. The second is cheaper and makes the rule visible
where entries are written; the first also rescues the two entries already in
this shape.

## Census (2026-08-25)

Sweeping all four group faces widens this from two entries to nine, and turns
up a second failure mode on the requires side.

### Nine invisible entries

| face | entries | emitted | dropped |
| :--- | ---: | ---: | ---: |
| sdlc | 5 | 0 | 5 |
| blueprint | 9 | 8 | 1 |
| issue | 12 | 10 | 2 |
| platform | 6 | 5 | 1 |

`sdlc` declares its whole surface bold-first, so the face emits **no provides
rows at all** — every consumer requiring `sdlc.personas` is reading a provider
that mechanically declares nothing. `platform`'s dropped entry is its
`meta-test framework`, the surface two groups require as `platform.testlib`.

### The requires side loses tokens too

The parser takes the *first* backticked token per bullet, so a bullet naming
two surfaces registers one. Three required surfaces are lost that way:
`platform.jimfile-cli` from `sdlc`'s combined config/path bullet, and
`issue.candidate-batch-contract` from both `sdlc` and `blueprint`, each of
which pairs it with `issue.emitter` in one bullet. Twenty-six declared
requirements emit twenty-three rows.

`issue.candidate-batch-contract` is invisible on **both** sides — dropped as a
bold-first provides entry, and swallowed as a second token on every bullet that
requires it.

### What this changes about the fix

Reshaping entries to lead with a backticked token is still the cheaper
direction, but the rewrite is nine entries across four faces rather than a
convention note, and the leading token has to be the name consumers already
use — otherwise the entry becomes visible and still joins to nothing
([[20260825-requires-tokens-resolve-to-no-provides-entry-on-any-face]]). Since
no face parses cleanly today, the parser has to be fixed or the entries
reshaped before any join over the faces can be computed at all.

## The undercount is durable (2026-08-26)

The reconcile pass writes `faces=` and `faces_max=` onto the specs-root ledger
verbatim, as the counter contract requires — script-emitted, never recomputed
by the caller. So every run banks the undercount into history rather than only
reporting it: the 2026-08-26 run recorded `faces=23` against 32 declared
entries and `faces_max=10` against a true 12.

That bears on the direction above, and it splits the two options apart. Fixing
the parser makes a backfill meaningful — the faces can be re-counted from the
blueprints at any past commit. Reshaping the nine entries cannot be backfilled
at all: a re-count would read historical content that is still bold-first
through a parser that still drops it, so the growth trend stays unreadable
across the boundary in exactly the period the reshape was meant to fix.

`faces_max_group=issue` is correct today only by coincidence — `issue` holds
the maximum under both the emitted count and the true one. Two groups whose
bold/backtick mix differs could trade the lead in the emitted count while the
true maximum never moves, and the attribution would follow the wrong one.
