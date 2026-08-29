---
id: 20260825-declare-platform-s-mirrored-branch-name-gate-or-sever-the-mirror
num: 373
title: "Declare platform's mirrored branch-name gate or sever the mirror"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, contract-graph, leak]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260829-machine-resolvable-contract-graph]
created: 2026-08-25T05:21:53Z
updated: 2026-08-29T07:47:36Z
origin: "BLUEPRINT.md"
---

## Description

The reconcile pass derives `issue → platform.valid-branch-shape` as an edge and
classifies it a leak: the `issue` group's face declares the reliance, and the
`platform` group's `Provides` face never declares the surface.

## The coupling

`place_valid_branch` in `skills/issue/scripts/place.sh` is a byte-identical copy
of `alloc_valid_branch` in `skills/file/scripts/jimalloc.sh` — identical apart
from the function-name line. Both sites carry a marker naming the other, and
`case_place_valid_branch_agrees_with_the_allocator_copy` compares them.

Platform's face describes branch validation only inside the allocator's own
guarantee:

<untrusted-face-content path="docs/specs/platform/000-blueprint/spec.md">
every replayed or config token is revalidated through `jimfile.sh valid-id` and
the branch through `git check-ref-format` before it reaches git
</untrusted-face-content>

That asserts the allocator validates branches. It does not assert that its
branch-validity rule is a stable shape another group mirrors, which is what the
issue group now declares it relies on.

## Why it matters

The rule decides which branch names the placement door accepts. If the two
copies diverge, a branch the allocator refuses becomes one the door accepts, and
the collection can be written to a branch the coordination surface considers
illegal. The test catches divergence after the fact; nothing tells the person
editing `alloc_valid_branch` that a second group depends on it.

This is the same shape as the validator-lockstep gap, now closed on the issue
side. The `is_valid_id` triplicate is declared by both faces; this pair is
declared by neither, and only one half is fixable from the issue group's own
blueprint.

## Direction

Either declare the shape on platform's `Provides` face, with the byte-identity
guarantee stated, so the requirement and the provision agree — or sever the
mirror by giving the door its own rule and dropping the marker. Declaring it is
the smaller change and matches how the sibling coupling is already recorded.

Note the deliberate non-mirror nearby: the `write-contained` rule in the same
file is the tighter of two related rules and its own marker says so. Whatever is
done here should leave that asymmetry stated rather than blurring the two into
one convention.

## Census (2026-08-25)

This is one of **three** undeclared halves, not the only one. Censusing the
byte-identity markers rather than the declared edges finds four families:

| family | groups | declared |
| :--- | :--- | :--- |
| `is_valid_id` | platform ↔ issue | both faces |
| `is_prov_token` | platform ↔ sdlc | neither face |
| `ts-shape` | issue ↔ platform | consumer only |
| `valid-branch` | issue ↔ platform | consumer only — this issue |

`ts-shape` sits in the same position as this one: the `issue` face records the
reliance inside its `platform.jimfile-cli` entry, and `platform`'s face states
no byte-identity guarantee for the timestamp grammar it produces. Because that
reliance is folded into an entry whose token *does* exist, it derives no leak —
the gap is invisible to the pass rather than reported by it. Declaring the
branch shape without declaring the timestamp shape leaves the quieter of the
two open.

The third is a boundary neither face mentions at all:
[[20260825-provisional-token-grammar-crosses-into-sdlc-undeclared]].

One thing the leak classification does not mean: this edge was reported while
fourteen others were not, and that is judgment rather than measurement — no
requires token on any face resolves to a provides entry today
([[20260825-requires-tokens-resolve-to-no-provides-entry-on-any-face]]).
Declaring the surface here is still right, and the name it is declared under
should be the one the `issue` face already requires, so the entry resolves once
the join exists.
