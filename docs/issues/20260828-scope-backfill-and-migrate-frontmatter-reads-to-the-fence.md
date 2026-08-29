---
id: 20260828-scope-backfill-and-migrate-frontmatter-reads-to-the-fence
num: 415
title: "Scope backfill and migrate frontmatter reads to the fence"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [blueprint-divergence, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:33Z
updated: 2026-08-28T22:48:09Z
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

## Resolution

Fixed in `40827a63`.

`backfill.sh` gains the group's `frontmatter` / `fm_field` pair and a
fence-scoped `num_of`; both loops in `cmd_assign_numbers` and the
`cmd_timestamp` loop now take the fence once and read their fields off it.
`migrate.sh` loses `field_value` entirely and keeps a single copy of the pair
where `field_value` sat — the file carried both readers, and `build_plan` used
the unscoped one.

All four helper bodies across `resolve.sh`, `transition.sh`, `migrate.sh` and
`backfill.sh` are byte-identical (md5-checked), so the group now has one
definition of this read in four places rather than two competing disciplines.

**Four cases pin it**, each proved by neutering the fix and watching only those
cases fail. The two migrate cases are the sharp ones: before the fix a body line
reading `num: 900` planned `rename 0007-example -> 0900-example`, and one
reading `created: 2020-01-01` planned `rename legacy-example ->
20200101-example`. That is the rename `--apply` executes. Suite 1,681 green.

**Wider than filed, in three places.** The record asked to route the reads; the
fix also *deleted* `migrate.sh`'s duplicate pair rather than leave two
definitions to drift apart. `num_of` changed signature from a file to a
frontmatter block, matching `fm_field`'s convention, so its callers take the
fence once instead of once per field. And `#324` was re-anchored: it named
`field_value` at `:62-66`, and all six of its line references were exact before
this rename moved them.

**The sweep is complete for the group.** Every remaining field read under
`skills/issue/scripts/` is fence-scoped, operates on an already-extracted
frontmatter block, or reads a non-issue file — `index.sh` fences at `:137` and
`:239`, `render.sh:1602` reads the body deliberately, and `place.sh:929` reads
its own `key=value` state file.

**What this does not fix.** `#324` is untouched and still live: `fm_field`
preserves tabs exactly as `field_value` did, so a tab inside a frontmatter
`created:` value still re-splits the sort record. Narrowing the read to the
fence removes the body as a source of that value; it does not remove the value.

**Unverified against the sensor.** The invariant this record cites,
`issue-file-never-sourced`, is `judge`-method, and this group's blueprint
carries no `verify-checks` block — so there is no mechanical rung that can
confirm the divergence is closed without a judge fan-out, which was not run.
The four cases are evidence for the two scripts, not a sensor verdict.
