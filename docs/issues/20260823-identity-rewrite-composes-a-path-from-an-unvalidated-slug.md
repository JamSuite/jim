---
id: 20260823-identity-rewrite-composes-a-path-from-an-unvalidated-slug
num: 360
title: "Identity rewrite composes a path from an unvalidated slug"
status: open
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, migration, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:37:26Z
updated: 2026-08-23T23:37:26Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## Description

The blueprint invariant `id-gate-before-path` states that "every id passes the
validator before any path composition or file read." The identity rewrite's
apply path composes `"$dir/$slug.md"` with no validator call on the slug.

## What is there now

The slug reaching that composition is a byte-identical reconstruction of a
directory entry the plan builder enumerated by glob, with dot-prefixed names
and the index file excluded. No traversal is reachable — a globbed basename
cannot contain a separator — so this is not an exploitable defect.

## Why it is still worth fixing

The invariant's text is unconditional, and this project has already decided
this exact question three times in the other direction:

- `new.sh` applies the validator even to allocator-derived ids, with the stated
  reason that "the sanitization that produced it lives in another group, so the
  value is not provably validator-clean here" — an explicit refusal of
  safe-by-provenance reasoning
- `index.sh` validates this identical category of glob-derived slug, even
  though it composes no path from it
- `migrate.sh` itself was fixed once before for this class: the collision
  discriminator was reaching a filename unvalidated, and the test that pins the
  fix names `id-gate-before-path` as the critical invariant it breached

Leaving it unvalidated makes the new site inconsistent with its own neighbours
and reopens a question the project settled.

## Scope

The sibling `apply_schema_plan` composes `"$dir/$SCHEMA_SLUG.md"` the same way
and predates this change. Both are the same one-line fix and belong together.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 2,
and the living-intent violation resolved `fix` at the blueprint fork.
