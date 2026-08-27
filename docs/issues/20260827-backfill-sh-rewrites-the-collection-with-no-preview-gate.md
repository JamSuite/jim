---
id: 20260827-backfill-sh-rewrites-the-collection-with-no-preview-gate
num: P-20260827-backfill-sh-rewrites-the-collection-with-no-preview-gate
title: "backfill.sh rewrites the collection with no preview gate"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-27T11:20:44Z
updated: 2026-08-27T11:20:44Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## What

`backfill.sh`'s `num` and `timestamp` subcommands rewrite every matching issue
file in the collection on their first invocation. There is no preview form, no
`--apply` flag, and no plan hash — no gate of any kind exists in the file.

The group's blueprint states the rule unconditionally:

> Every collection-wide rewrite previews by default and mutates only under an
> explicit apply flag, and a plan hash supplied with that flag refuses a run
> whose collection drifted since the preview it names.

`migrate.sh` upholds it across all three of its collection-wide verbs. It is
the one surface that does not.

## Where

- `skills/issue/scripts/backfill.sh` — `cmd_assign_numbers`, `cmd_timestamp`,
  and `main`'s dispatch, which routes a bare subcommand straight into the
  mutating function.

The pattern to copy is in the same directory: `migrate.sh`'s `gate_apply`
recomputes the plan hash from the *current* collection and refuses when it
disagrees with the caller's `--expect`, which is what makes the drift check
real rather than advisory.

## What bounds it today

Worth stating plainly, because it is why this is not urgent:

- Both subcommands are **idempotent**, so a retry completes an interrupted run
  rather than compounding.
- Each file is rewritten per-file **atomic tmp+mv**, so no partial write
  corrupts a record.
- `num` only fills a field that is **absent**; all other content is preserved.
- The script is **not wired into the verb flow** and is not in the skill's
  `allowed-tools` — an operator runs it deliberately, once, before normal use.

## What is not bounded

`timestamp` **rewrites existing values** — a date-only `created`/`updated`
becomes a `T00:00:00Z` day-start — across every matching record, with nothing
to inspect first. That is the case the invariant is for. "Idempotent" bounds
repetition, not correctness: an operator who points it at the wrong directory,
or who did not expect the normalization, has no preview that would have shown
them and no hash that would refuse a collection that moved underneath them.

## Fix shape

Give both subcommands the shape `migrate.sh` already has: build a plan
read-only, render it with a `PLAN-HASH`, mutate only under `--apply`, and
refuse an `--expect` that no longer matches. The two subcommands share a
per-file rewrite loop, so the gate belongs at the dispatch rather than
duplicated inside each.

## Provenance

Surfaced by the `/jim:verify --since` grounding run for a blueprint update —
`collection-rewrite-preview-gated`, judged `partial`, which the engine maps to
violated. Confirmed independently before filing: the file contains no
`--apply`, `--expect`, `PLAN-HASH` or preview machinery at all.

The record is filed at `high` rather than at the invariant's own `critical`
because of the four bounds above — the surface is opt-in, one-time, idempotent
and atomic per file. The gap is real; the blast radius is an operator's own
deliberate invocation, not a path any skill reaches.
