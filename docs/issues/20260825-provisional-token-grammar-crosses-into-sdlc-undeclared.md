---
id: 20260825-provisional-token-grammar-crosses-into-sdlc-undeclared
num: 376
title: "Provisional-token grammar crosses into sdlc undeclared"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, contract-graph, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260829-machine-resolvable-contract-graph]
created: 2026-08-25T06:40:40Z
updated: 2026-08-29T07:49:55Z
origin: "docs/specs/platform/000-blueprint/spec.md"
---

## Description

`is_prov_token` — the grammar deciding which tokens count as provisional
identifiers — is mirrored byte-for-byte across three scripts in **two groups**,
and neither group's face declares the coupling.

## The sites

- `skills/file/scripts/jimfile.sh:345` — platform
- `skills/file/scripts/jimalloc.sh:269` — platform
- `skills/spec/scripts/reconcile.sh:143` — **sdlc**

Each carries a `SYNC:` comment naming the other two, and a `tests/jimfile.sh`
case asserts all three are byte-identical, so drift fails loudly. What is
missing is the *declaration*: `sdlc`'s `Requires` face does not record that it
mirrors a platform grammar, and `platform`'s `Provides` face does not record
that its grammar is a stable shape another group copies. The contract graph
carries no edge for it.

## Why it matters

The grammar decides which `num:` values `/jim:spec reconcile` treats as pending
realization. If the sdlc copy narrows, a genuinely provisional spec is not
recognized as one and stops being realized — silently, because a file nobody
looks for is a file nobody misses. If it widens, a real ordinal is fed back to
the allocator as a token to realize. The test catches divergence; nothing tells
the person editing the platform copy that a second group's realizer depends on
it, which is the same gap the validator-lockstep declaration closed on the
issue side.

## The family census

Four byte-identity families exist. The couplings, their group pairs, and
whether each side declares the dependency:

| family | sites | groups | declared |
| :--- | :--- | :--- | :--- |
| `is_valid_id` | `jimfile.sh`, `index.sh`, `render.sh` | platform ↔ issue | both faces |
| `is_prov_token` | `jimfile.sh`, `jimalloc.sh`, `spec/reconcile.sh` | platform ↔ sdlc | **neither face** |
| `ts-shape` | `index.sh`, `render.sh`, `backfill.sh`, `jimfile.sh` | issue ↔ platform | consumer only |
| `valid-branch` | `place.sh`, `jimalloc.sh` | issue ↔ platform | consumer only |

`write-contained` (`place.sh:868`) is a fifth marker and deliberately *not* a
copy — it records that the containment rule beside it is the tighter of two
related rules. It belongs in the census as the declared asymmetry, not as a
gap.

So the rule has three undeclared halves, not one: the two provider-side halves
that [[20260825-declare-platform-s-mirrored-branch-name-gate-or-sever-the-mirror]]
names one of, and this pair, which is undeclared on both sides and crosses a
boundary neither group's face mentions.

## Direction

Declare the coupling on both faces — a `Requires` entry on `sdlc` naming the
grammar it mirrors, and a `Provides` entry on `platform` stating the
byte-identity guarantee — so the derived graph carries the edge and an editor
of either copy can see who depends on it. Severing the mirror is the
alternative and is worse here than for the branch gate: the grammar is a
parsing rule with a real fixture cost, and three copies already agree.

Whichever way it goes, the surface names have to resolve for the edge to be
readable mechanically
([[20260825-requires-tokens-resolve-to-no-provides-entry-on-any-face]]).
