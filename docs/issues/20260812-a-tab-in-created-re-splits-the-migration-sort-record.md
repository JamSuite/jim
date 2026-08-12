---
id: 20260812-a-tab-in-created-re-splits-the-migration-sort-record
num: P-20260812-a-tab-in-created-re-splits-the-migration-sort-record
title: "A tab in created re-splits the migration sort record"
status: open
priority: high
labels: [issue, security, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:33Z
updated: 2026-08-12T21:53:33Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`cmd_assign_numbers` joins an untrusted frontmatter value into a tab-delimited
sort record, then splits it back out.

`skills/issue/scripts/backfill.sh:118` builds the record:

    "$created"$'\t'"$f"

and `:125` reads it back with `IFS=$'\t' read -r createdkey file`.

`field_value` (`:62-66`) preserves tabs — its capture is `([^\"]*)`, which matches
them. So a `created:` value containing a tab puts attacker-controlled text at the
head of `$file`.

At `:131` that corrupted value becomes an `awk` operand:

    awk -v n="$next" 'PROG' "$file"

with `$file` now shaped like `1<TAB>/dir/x.md`. `awk` recognises a `NAME=VALUE`
argument as an **assignment**, not a filename — with escape expansion on the
value — so it falls through to stdin and drains the `while` loop's process
substitution at `:148`, silently skipping every remaining issue. The subsequent
`mv "$tmp" "$file"` at `:136` then targets an attacker-influenced path.

I traced no write outside the collection: the real path is appended *after* the
tab, so the target's parent directory cannot exist. The impact is aborting the
migration with a misleading error and consuming the work list — not arbitrary file
write.

This is the one remaining site in `backfill.sh` where untrusted issue text reaches
a command operand. The `timestamp` subcommand was hardened in the
review-remediation round (values travel via `ENVIRON`, and only a normalizer-minted
value is written); `cmd_assign_numbers` was not in that issue's scope.

Under a branch placement the `created:` value comes from a shared branch, so this
is reachable by any teammate.

No test covers it.

## Action

Validate `created` against the `SYNC(ts-shape)` pattern (or `tr -d '\t'` it)
before it is joined into the sort record at `:118`, and make the record
NUL-delimited so no field value can re-split it.

Related and worth doing in the same pass: `backfill.sh` installs no
`trap … EXIT INT TERM` for its `.backfill.tmp.*` / `.normalize.tmp.*` namespaces,
unlike `index.sh:581` and `new.sh:306`, so a signal mid-run leaves a hidden temp in
the collection. `reconcile.sh` and `migrate.sh` have the same gap.
