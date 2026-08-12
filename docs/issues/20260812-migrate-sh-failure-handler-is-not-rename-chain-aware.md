---
id: 20260812-migrate-sh-failure-handler-is-not-rename-chain-aware
num: 313
title: "migrate.sh failure handler is not rename-chain aware"
status: open
priority: medium
labels: [issue, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:47Z
updated: 2026-08-12T03:41:47Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`migrate.sh`'s commit-phase failure handler is not rename-chain aware, though the
retire loop is — so a failed `mv` part-way through a chain can leave an issue's
content nowhere on disk, under an error message asserting nothing was lost.

## Mechanism

`skills/issue/scripts/migrate.sh:232-243`. The commit phase renames every staged
file into position, then retires old names in a second pass that skips any name
another issue was just renamed onto:

```
for i in "${!s_old[@]}"; do
  [[ "${s_old[$i]}" == "${s_new[$i]}" ]] && continue
  [[ -n "${new_names[${s_old[$i]}]:-}" ]] && continue   # chain-aware
```

The failure handler has no equivalent guard:

```
for i in "${!s_tmp[@]}"; do
  if ... || ! mv "${s_tmp[$i]}" "${s_new[$i]}"; then
    for (( j=i; j<${#s_tmp[@]}; j++ )); do rm -f "${s_tmp[$j]}"; done
    ..."the issues committed before this point now exist under both names, and none has been lost"...
```

When an earlier index `m < i` has `s_new[m] == s_old[k]` for a still-pending
`k >= i` — a rename chain or swap, exactly the case the retire loop's guard
exists for — the `mv` at `m` overwrites file `k`'s only on-disk copy, and the
cleanup then deletes `k`'s staged tmp. File `k`'s content exists nowhere on disk,
recoverable only from git, while the message asserts the opposite.

Under the `sequential` prefix scheme this needs two issues sharing a slug whose
numeric prefixes are out of step with their `num:` fields, plus an `mv` failure.
Narrow, but the ordering is undefended and the existing mid-commit test covers
only the disjoint-names shape.

## Proposed action

Order the commit loop so a name that is another entry's pending source is
renamed last, or stage through a two-phase swap; and correct the failure message
so it does not claim a guarantee the handler cannot make.

## Origin

Post-build review of `issue/011`; found by the `atomic-index-write` judge.
