---
id: 20260828-scope-backfill-and-migrate-frontmatter-reads-to-the-fence
num: P-20260828-scope-backfill-and-migrate-frontmatter-reads-to-the-fence
title: "Scope backfill and migrate frontmatter reads to the fence"
status: open
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [blueprint-divergence, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:33Z
updated: 2026-08-28T11:37:33Z
origin: "docs/specs/issue/015-epic-authoring-and-views/review.md"
---

## Description

The blueprint invariant `issue-file-never-sourced` requires that frontmatter and
body are read line-oriented "on every read path". Two helpers read the whole
file instead of the frontmatter fence.

## Where

- `skills/issue/scripts/backfill.sh:62-66` (`field_value`) and `:69-72`
  (`num_of`) — used throughout the `num` and `timestamp` subcommands.
- `skills/issue/scripts/migrate.sh:110-115` (`field_value`) — used by
  `build_plan`, i.e. the `prefix` subcommand.

## Reproduction

A record whose frontmatter lacks `num:` and whose body contains a line starting
`num:`:

    ---
    id: 20260101-example
    title: "Example"
    status: open
    created: 2026-01-01T00:00:00Z
    ---

    ## Description

    num: 5 retries were attempted before the fix landed.

The fence-scoped read correctly finds no `num`. `backfill.sh`'s `num_of`
answers **5**.

## Why it matters

That is `backfill.sh`'s own operating condition — it exists to fill the field in
on records that lack it. A record answering from its body is treated as already
numbered and skipped, silently, forever. On the `migrate.sh prefix` path the
bogus value feeds `jf prefix-from "$created" "$num"`, corrupting the migration
plan for that record; under `--apply` that reaches a file rename.

## The sharp part

`migrate.sh` contains **both** readers: the unscoped `field_value` at `:111`
and a correctly fence-scoped `frontmatter`/`fm_field` pair at `:442`/`:447`,
used by its `schema` and `identity` subcommands. The file demonstrably knows
the hazard — its own comment names it — and the `prefix` path uses the wrong
helper anyway.

## The fix

Route both scripts' field reads through the fence-scoped pair the rest of the
group already uses. The pattern is in `resolve.sh:55-63`, `transition.sh:97-105`
and `migrate.sh:442-450`, all byte-identical.

## Classification

Pre-existing: neither file was in the epic increment's change set. It is the
most serious thing that increment's reviews found and did not fix.
