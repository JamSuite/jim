---
id: 20260827-backfill-sh-rewrites-the-collection-with-no-preview-gate
num: 404
title: "backfill.sh rewrites the collection with no preview gate"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-27T11:20:44Z
updated: 2026-09-06T07:46:04Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

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

## Resolution — 2026-09-06 (done)

Fixed in `5c34db64`. Both subcommands now build their plan read-only, render
it with a `PLAN-HASH`, and mutate only under `--apply`, refusing an `--expect`
that no longer matches at exit 3. The gate sits at `cmd_backfill` rather than
inside each subcommand — they take the same flags, and a second parse is a
second place for the preview default to be got wrong — while `gate_apply` is a
single function for the reason `migrate.sh` states about its own.

What pins it: ten cases in `tests/issues.sh` (`case_issues_backfill_*_previews_by_default`,
`*_expect_refuses_drift`, `*_expect_matching_applies`, `*_expect_requires_operand`,
`*_plan_hash_is_checkout_independent`, and two placement cases). Each was
mutation-checked rather than trusted green: making apply the default fails 8 of
them, disarming `gate_apply` fails the 2 drift cases, and dropping the routing
operand skip fails the placement case.

Three things the fix shape above did not anticipate, all decided while building:

- **The plan is keyed by issue id, not path.** A placement-routed run
  materializes into a fresh directory every time, so a path-keyed plan would
  have read every placement apply as drift.
- **`route_placement` would have read the `--expect` hash as a directory**, which
  declines routing — the apply would have hit the working tree with the gate
  aimed at another collection. `reconcile.sh` already had the `skip_next` idiom.
- **A preview must route read-only**, or previewing under a placement publishes
  and "writes nothing" stops being true. Same precedent.

Wider than the record asked: `normalize_ts` became a pure `classify_ts`, so a
malformed value is named by the preview instead of only while rewriting. A
malformed row deliberately carries no value — a tab in `created` would re-split
the row, the defect #324 records against `migrate.sh` — while normalize rows are
safe by construction, their values minted from a date-only match.

Deliberately left alone: `frontmatter` / `fm_field` / `resolve_dir` stay
duplicated across the issue scripts, and `plan_hash` / `gate_apply` / `git_note`
are now copied here rather than shared. Every script in this directory is
standalone and composes by invocation; extracting a library is #351's question,
not this record's.

`WORKFLOW.md` was corrected — it told operators to run the bare command as a
mutation. `ARCHITECTURE.md` still describes both subcommands as ungated and
contrasts `migrate.sh`'s previewed migrations with "`backfill.sh`'s
fill-missing"; that refresh belongs to `/jim:arch` and has not been run.
