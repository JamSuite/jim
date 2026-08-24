---
id: 20260823-identity-rewrite-composes-a-path-from-an-unvalidated-slug
num: 360
title: "Identity rewrite composes a path from an unvalidated slug"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, migration, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:37:26Z
updated: 2026-08-24T07:30:25Z
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

## Resolution (2026-08-24)

Fixed in `2536459`.

`jf valid-id` runs before the path composition in `apply_identity_plan` and in
the sibling `apply_schema_plan`, as the Scope section above asked — fixing only
the first would have left the wrong shape for the next reader to copy.

Nothing reachable changes: each slug is still a byte-identical reconstruction
of an entry the same run globbed. What changes is that the boundary is the
validator call rather than an argument about where the value came from.

Pinned by `case_migrate_identity_apply_gates_the_id_before_composing_a_path`,
which places a `..`-bearing entry in the collection and asserts the run refuses
whole with nothing written. It was run against the unfixed script first and
fails there.
