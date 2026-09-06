---
id: 20260826-schema-gate-misses-a-partly-converted-collection
num: 399
title: "Schema gate misses a partly converted collection"
status: open
priority: medium
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
created: 2026-08-26T07:59:55Z
updated: 2026-08-26T07:59:55Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

The schema gate in `render.sh` decides an index cannot answer a query from a
single witness: `saw_type` flips to 1 the moment any one row carries a non-`-`
`type`, and the gate fires only when `seen_rows > 0 && saw_type == 0`. That
premise — stated in the code as "`type` is non-empty on every record the
current schema produces" — holds for a wholly legacy index and fails for a
partly converted one.

## Reproduced

A collection holding one converted record and one legacy record, indexed by the
current emitter:

```
- `20260101-alpha` — Alpha · status: open · num: 1 · created: 2026-01-01 · type: issue · filed-by: dev@example.test
- `20260102-bravo` — Bravo · status: open · num: 2 · created: 2026-01-02

render.sh list --type issue <dir>    ->  1 of 2 records, rc 0, no disclosure
```

`bravo` is excluded silently. Every record the schema conversion has not
reached is invisible to `--type`, `--filed-by`, `--claimed-by`, the `held` bare
words, and any `--cols` naming those fields — on both read verbs. The gate
cannot fire, because one converted record is enough to satisfy it.

## Why this is an ordinary state rather than an edge case

`new.sh` writes `type: issue` on every new filing, `index.sh` emits the row
pair only when the file carries one, and giving legacy files a `type` is a
one-shot opt-in conversion. Nothing forces that conversion to run, so a
collection where converted and unconverted records coexist is the normal
steady state of any project that adopted the wider row after it had already
filed issues.

## Where

- `skills/issue/scripts/render.sh` — `schema_gate`, its `seen_rows`/`saw_type`
  condition, and the comment stating the premise
- `skills/issue/scripts/render.sh` — the two row loops that compute `saw_type`
- `skills/issue/scripts/index.sh` — conditional emission of the row pair

## Fix shape

Detection needs to be per-record rather than per-index: a row that lacks a
gated field cannot answer a query over it, whatever its neighbours carry. The
cheapest honest form is to count unanswerable rows inside the loop both verbs
already run and disclose the count — "N of M records predate these fields" —
rather than to refuse. Refusing would make a partly converted collection
unreadable on those axes until the conversion runs, which is a worse trade than
the one the all-or-nothing case makes.

## Coverage

No fixture exercises a mixed collection. The `strip_new_scalars` helper in
`tests/issues.sh` strips the fields from every row uniformly, which is exactly
the case the current gate does catch — the same shape of blind spot as a test
whose domain is drawn from the implementation it checks.
