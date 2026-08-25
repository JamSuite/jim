---
id: 20260825-faces-verb-skips-bold-first-provides-entries
num: P-20260825-faces-verb-skips-bold-first-provides-entries
title: "faces verb skips bold-first Provides entries"
status: open
priority: medium
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
updated: 2026-08-25T05:21:54Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

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
