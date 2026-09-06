---
id: 20260812-a-tab-in-created-re-splits-the-migration-sort-record
num: 324
title: "A tab in created re-splits the migration sort record"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, security, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:33Z
updated: 2026-09-06T21:19:04Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`build_num_plan` joins an untrusted frontmatter value into a tab-delimited sort
record, then splits it back out.

`skills/issue/scripts/backfill.sh:353` builds the record:

    "$created"$'\t'"${base%.md}"

and `:365` reads it back with `IFS=$'\t' read -r createdkey slug`.

`fm_field` preserves tabs — its capture is `([^\"]*)`, which matches them. So a
`created:` value containing a tab puts attacker-controlled text at the head of
`$slug`, which the plan then carries as the row's first field and the applier
composes into a path.

Under a branch placement the `created:` value comes from a shared branch, so
this is reachable by any teammate.

## Status — the sort-record half is fixed

Fixed in `723cb682`. `build_num_plan` strips tab and newline from `created`
before joining it. The value is a sort key only — never written — so stripping
rather than rejecting keeps a malformed stamp orderable and still ordinal-worthy.

A second, structural guard was added with it: every applier composes its target
through `plan_file`, which refuses a slug holding a path separator or a leading
dot. Nothing reaches that refusal now, and the code comment says so rather than
implying coverage.

`case_issues_backfill_num_tab_in_created_cannot_redirect_the_write` pins it, and
was mutation-checked: removing the strip fails that case and only that case.

### What the severity was, and briefly became

This record originally traced *no* write outside the collection, reasoning that
the real path is appended after the tab so the target's parent cannot exist. That
was correct against the code as filed, where the record carried `<created>\t<full
path>`.

The preview-gate work re-keyed the plan by slug (`<created>\t<slug>`) so a hash
taken under one checkout would match the same collection materialized under
another. That removed the bound: the applier composed `$dir/$slug.md` from a slug
that a re-split had filled with issue text, so `created: 2026-01-01<TAB>../outside/victim`
wrote into `../outside/victim.md`. Demonstrated, then closed by the fix above.

The lesson worth keeping: the containment here was incidental to a data shape,
not enforced by a check. A refactor with no security intent removed it silently.
That is why the fix pairs stripping the value with a guard at the write.

## Still open — the temp-file trap

`backfill.sh` installs no `trap … EXIT INT TERM` for its temp namespaces, unlike
`index.sh` and `new.sh`, so a signal mid-run leaves a hidden temp in the
collection. There are now **three** namespaces, not two: `.backfill.tmp.*`,
`.normalize.tmp.*` and `.heading.tmp.*`, the last added with the `heading`
subcommand. `reconcile.sh` and `migrate.sh` have the same gap.

This is the remaining work on this record.
