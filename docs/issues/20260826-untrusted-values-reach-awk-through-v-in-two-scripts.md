---
id: 20260826-untrusted-values-reach-awk-through-v-in-two-scripts
num: 398
title: "Untrusted values reach awk through -v in two scripts"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, security, awk]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:35:24Z
updated: 2026-08-26T02:35:24Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`migrate.sh` and `transition.sh` pass untrusted values into awk with `-v`.
`backfill.sh` deliberately does not, and says why: POSIX awk processes a `-v`
operand as a string literal and expands backslash escape sequences in it, so a
value carrying `\n` becomes a real newline inside the awk program's variable.

`ARCHITECTURE.md` records this reasoning as the project's convention — values
reach awk through the environment, not through `-v`.

## Where

- `skills/issue/scripts/migrate.sh` — `apply_schema_plan`, `apply_identity_plan`
- `skills/issue/scripts/transition.sh` — `set_fields`

Both write frontmatter fields, so the values in question are identities and
enumerated scalars rather than free text — which is what bounds the exposure.

## Exposure

Narrow, because of what else is true:

- identities clear `IDENTITY_CHARS` before they reach either path, and that set
  admits no backslash;
- outcomes and types clear their own enums.

So there is no presently-reachable value that carries an escape sequence into
either call. The concern is that the guarantee currently rests on the callers'
gates rather than on the channel, while the project has already decided the
channel is where it belongs — and `backfill.sh` already pays that cost.

## Provenance

Pre-existing; untouched by the read-view filter work. Surfaced while auditing
that work's own awk usage, which is clean throughout (every new program is a
single-quoted literal taking the index file as a positional argument, with the
relation type compared in shell rather than passed in).

## Fix shape

Route both through `ENVIRON`, matching `backfill.sh`'s `cmd_timestamp`. The
change is mechanical and the pattern to copy is in the same directory.
