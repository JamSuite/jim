---
id: 20260817-unify-the-two-issue-frontmatter-parsers
num: 351
title: "Unify the two issue frontmatter parsers"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, refactor, parser]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-17T23:16:40Z
updated: 2026-08-18T05:15:56Z
origin: "docs/specs/issue/012-schema-and-state-model/research.md"
---

## Description

## Context

The `issue` group parses issue frontmatter in **four independent places**, with
different field sets and different output encodings, and nothing enforces that
they agree:

- `skills/issue/scripts/index.sh` — `parse_scalar_fields`, one awk pass over a
  hard-coded allowlist (`status`, `priority`, `title`, `origin`, `labels`,
  `created`, `num`, `type`, `filed-by`, `claimed-by`, `outcome`), returning the
  values **positionally, one per line**.
- `skills/issue/scripts/render.sh` — a separate inline awk parser over a
  *different* field subset, emitting TSV.
- `skills/issue/scripts/migrate.sh` — a `frontmatter()` / `fm_field()` pair, a
  fence-bounded extract plus a `grep`/`sed` field read.
- `skills/issue/scripts/transition.sh` — the same pair again. The two are
  **byte-identical** (cksum `889574657`, 86 bytes), so they are already a
  duplication rather than two designs that happened to converge.

The last two were added by the schema conversion and the lifecycle verbs. They
are the cheapest to unify, because unlike the first two they need no
reconciliation of differing field sets — they are the same function twice.

## Why it matters

A field added to one parser and not the other fails silently in exactly one
view — the index and the read views disagree, and no test catches it because
each parser is tested against its own expectations.

The positional return compounds it: callers read `parse_scalar_fields` output by
line position, so inserting a field in the middle of the `END` block silently
shifts every downstream field by one.

Surfaced while researching the schema-and-state-model work, which adds five
fields (`type`, `filed-by`, `claimed-by`, `outcome`, `part-of`) and therefore
pays this cost twice — taking the positional read from 7 lines to 12. That spec
adds the fields to both parsers as-is; it does not address the duplication.

## What

Either:

1. **Unify** — one parser, one field list, consumed by both `index.sh` and
   `render.sh`; or
2. **Formalize the lockstep** — keep both, add a check that their field sets
   agree, in the shape already used for the `is_valid_id` contract between
   `platform` and `issue` (see [[20260725-formalize-the-is-valid-id-lockstep-contract-between-platform-and]]).

Option 2 is the cheaper, more conservative move and has direct precedent in this
codebase. Option 1 removes the class of bug rather than detecting it.

A keyed rather than positional return for `parse_scalar_fields` is worth
considering under either option — it contains the blast radius of every future
field independently of whether the parsers are merged.
