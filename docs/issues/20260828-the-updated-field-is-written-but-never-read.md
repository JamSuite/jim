---
id: 20260828-the-updated-field-is-written-but-never-read
num: 409
title: "The updated field is written but never read"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, schema]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T05:17:24Z
updated: 2026-08-28T05:17:24Z
origin: "docs/specs/issue/015-epic-authoring-and-views/plan.md"
---

## Description

## What

Every issue record carries an `updated` timestamp, refreshed on every mutation
by the lifecycle verbs and by the documented hand-edit convention. Nothing reads
it.

## The census

Swept while planning the epic increment, across `skills/`, `agents/`, `tests/`
and the group blueprints. One reader exists:

- `backfill.sh` `cmd_timestamp` — a one-shot, opt-in migration that normalizes
  the field's *format* (a date-only value becomes a day-start timestamp). It
  reads the value only to decide whether to rewrite it.

Everywhere the field could have a purpose, it is absent:

- `index.sh` `parse_scalar_fields` carries a hard allowlist and `updated` is not
  in it, so the value cannot reach an `INDEX.md` row at all.
- `render.sh` contains no occurrence of the token. `show` prints `created` and
  not `updated`.
- It is not in `COL_TOKENS`, so it cannot be selected as a column.
- It is not in `AXIS_FIELDS`, so it cannot be filtered on.
- `issue_list_sort` accepts `date`, `priority` and `num`; `date` sorts on the
  row's `created` field, not `updated`.

File modification time, which is a separate signal, drives the index staleness
gate. That gate asks whether a file changed, never when — so it reads mtime and
never the field.

## The documentation says otherwise

`skills/issue/SKILL.md` § 6a instructs refreshing the field "so recency ordering
reflects the real time of the last change". No recency ordering exists. The epic
increment corrects that sentence to describe what the field actually is; it does
not answer what it should be.

## The follow-on

Either give the field a reader or retire it. A recency sort is the obvious
candidate and would be cheap — the value would have to join the row schema and
the sort vocabulary, both of which are declared constants that their consumers
already iterate. Retiring it is also defensible: the creating and modifying
commits are in version control beside the collection, and a field written on
every mutation that nothing consumes is a write with no reader.

Worth noting that the epic increment makes the field *more* accurate, not less:
a verb that changes nothing now leaves the stamp alone, so a moved `updated`
starts meaning something actually changed. That is the version of the field
worth deciding about.
