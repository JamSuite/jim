---
id: 20260730-single-source-the-provisional-identity-grammar
num: 155
title: "Single-source the provisional identity grammar"
status: open
priority: medium
labels: [id-coordination, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T10:55:22Z
updated: 2026-07-30T19:35:56Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

## Description

The reserved provisional-identity grammar — the prefix, then an 8-digit issuance
date, then a slug — is now expressed in three places across a trust boundary:

- `skills/file/scripts/jimalloc.sh` — `alloc_is_prov_form`, `alloc_valid_provid`
- `skills/file/scripts/jimfile.sh` — `is_prov_basename`, `is_spec_dir_basename`
- `skills/spec/scripts/reconcile.sh` — `is_prov_identity`

Each delegates the *token* check to `jimfile.sh valid-id`, so the id boundary
itself is not duplicated and `ARCHITECTURE.md`'s "single `is_valid_id` boundary,
no new validator copy" rule is met in letter. The grammar wrapped around that
boundary is what is triplicated: if one copy loosens — say one stops requiring
the date segment — a token the other two would reject reaches a filesystem path
or a git argument through that one.

The repo already has a precedent for a knowingly-duplicated check: `is_valid_id`
is mirrored verbatim in three files, carrying an explicit `SYNC:` comment naming
its copies plus a `tests/jimfile.sh` case asserting the three are byte-identical.
These new predicates have neither.

Two shapes, either acceptable:

- **Single-source it** — expose the check as a `jimfile.sh` verb the allocator
  and the realizer call, the way they already call `valid-id`. Costs one more
  shell-out per candidate on paths that already shell out per token.
- **Or adopt the `is_valid_id` discipline** — `SYNC:` comments naming every copy
  and a fixture asserting they agree, so drift fails a test rather than widening
  a boundary quietly.

One concrete consequence, independently corroborated: `is_prov_basename` admits
id-charset slugs, so a hand-typed `P-20260728-New.Widget` creates a directory
the realize path later rejects.

Surfaced by `sdlc/017`'s post-build review.
