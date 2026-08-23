---
id: 20260812-migration-preview-drops-every-skip-reason
num: 337
title: "Migration preview drops every skip reason"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, migrate, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T08:07:42Z
updated: 2026-08-12T08:31:52Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

The migration preview announced `(un-migratable: )` with nothing after it for
every skipped issue, so the operator approving a destructive migration was never
told why anything was skipped.

## Mechanism

`skills/issue/scripts/migrate.sh`. Plan rows are
`<action>\t<old>\t<new>\t<reason>`, and every skip row carries an **empty** new-id
field:

```
rows+=("skip-unmigratable"$'\t'"$id"$'\t'""$'\t'"id has no prefix delimiter")
```

Five sites read those rows with `IFS=$'\t' read -r action old new reason`. Tab is
IFS *whitespace*, so a run of tabs collapses to a single delimiter — the empty
middle field disappears and every later field shifts left:

```
printf 'A\tB\t\tD\n' | while IFS=$'\t' read -r a b c d; do echo "[$a][$b][$c][$d]"; done
  -> [A][B][D][]
```

So `reason` lands in `new` and `reason` ends up empty. It compounds:
`resolve_collisions` reads a row, then re-emits it from the shifted variables, so
the reason is destroyed before `render_plan` ever sees the row.

All three skip reasons were affected — `id has no prefix delimiter`, the
`prefix-from` failure text, and `re-derived id failed validation`.

## Why it matters

The preview is the gate. `migrate.sh prefix` is destructive and recovery is via
version control, so the operator decides on the strength of this output — and a
skipped issue is exactly the row that needs to explain itself. A skip with no
reason reads as arbitrary.

## Proposed action

Split the row explicitly rather than with `IFS=$'\t' read`, in one shared helper
used by all five consumers.

## Origin

Found while re-validating the collision discriminator for
`20260812-new-sh-composes-and-stats-a-path-before-valid-id-runs`: the new skip
row that fix emits was itself losing its reason, which is what exposed the class.

## Resolution (2026-08-12)

Fixed in `227ce29`. All five consumers of the plan-row grammar now go through one
`split_row` helper that splits on tab explicitly. Pinned by
`case_issues_migrate_preview_states_the_skip_reason`, proven to go red when the
splitter reproduces the shift.
