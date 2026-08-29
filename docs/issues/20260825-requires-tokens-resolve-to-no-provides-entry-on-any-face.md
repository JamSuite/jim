---
id: 20260825-requires-tokens-resolve-to-no-provides-entry-on-any-face
num: 377
title: "Requires tokens resolve to no Provides entry on any face"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, contract-graph, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: [20260829-machine-resolvable-contract-graph]
created: 2026-08-25T06:40:35Z
updated: 2026-08-29T07:46:10Z
origin: "BLUEPRINT.md"
---

## Description

The two halves of the contract graph name surfaces in different vocabularies,
so no consumer's `Requires` token resolves to any provider's `Provides` entry.
Joining every requires token against every provides slug across the four group
faces resolves **none of fifteen**, and marks **all twenty-three** provides
entries unconsumed.

## The two vocabularies

`Provides` entries are keyed off the **artifact** — `jimfile-sh`, `new-sh`,
`jim-blueprint`, `is-valid-id`. `Requires` entries name the **capability** —
`platform.jimfile-cli`, `issue.emitter`, `blueprint.advisor`,
`issue.validator-lockstep`. The map's own Contract Graph column uses the
capability vocabulary.

Unresolved today, one line per required surface:

```
blueprint.advisor                 issue.emitter             platform.jimalloc
blueprint.blast-radius-facts      issue.placement-door      platform.jimconf-cli
blueprint.gate-presentation-rule  issue.placement-read      platform.jimfile-cli
blueprint.living-intent-sensor    issue.validator-lockstep  platform.jimledger-cli
sdlc.personas                     platform.testlib          platform.valid-branch-shape
```

## Why it matters

Three of the reconcile pass's six finding classes quantify over the two faces
and can only be as good as the join between them:

- **leak** — a consumer requires what a provider never declared. Every edge
  qualifies mechanically; only judgment separates the real one from the
  fourteen that are naming drift.
- **dead-surface** — a provides entry no mapped consumer requires. Every group
  has a blueprint, so this detector is under full coverage and firing: a
  mechanical join reports twenty-three, the pass reports zero.
- **breaking** — powered by comparing a persisted graph against the current
  face, so it inherits the same identity problem across regens.

The blueprint template shapes both sides around one shared name —
`` `{surface}` — {guarantee} `` against `` `{other-group}.{surface}` `` — and
the `contract-checks` block keys its inert check data by "a Provides entry's
backticked surface name slugified", asking that those names stay stable across
regens. The join is the design; nothing computes it and nothing checks it, so
the two sides drifted apart without a signal.

## One surface, two names

`issue.placement-door` and `issue.placement-read` both name `place.sh`. A
single provides entry cannot carry two slugs, so this one is a modelling
decision rather than a rename: either the door splits into a write surface and
a read surface with distinct guarantees, or the two consumers name one surface
and the read-only restriction moves into the guarantee text.

## Direction

Canonicalize on the capability vocabulary — the side the map already speaks and
the side three groups already agree on — so every `Provides` entry leads with
the backticked slug its consumers name, and every `Requires` token resolves.
Then add the join as a mechanical check, which is the part that keeps it true:
a requires token resolving to no provides entry is exactly the leak class, and
computing it is a set difference rather than a judgment.

Two dependencies worth knowing before scheduling this:

- The join cannot be computed until the faces parser stops dropping entries
  ([[20260825-faces-verb-skips-bold-first-provides-entries]]); nine entries are
  invisible today, including every one of `sdlc`'s.
- `/jim:blueprint` has no verb for correcting a face's surface names. Generate,
  update, reconcile, retire and the migrate arms are the write paths, so a
  naming correction means a full regeneration per group — four of them — or a
  new narrow arm.

Surfaced by a census run before fixing
[[20260825-declare-platform-s-mirrored-branch-name-gate-or-sever-the-mirror]],
which is one instance of this: a required surface with no provides entry to
resolve to.
