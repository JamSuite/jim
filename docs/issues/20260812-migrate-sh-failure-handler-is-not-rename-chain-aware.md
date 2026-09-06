---
id: 20260812-migrate-sh-failure-handler-is-not-rename-chain-aware
num: 313
title: "migrate.sh failure handler is not rename-chain aware"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:47Z
updated: 2026-08-12T18:58:07Z
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

## Decision (2026-08-12)

**Fix the handler; do not reorder the commit loop.** The proposed action offered
ordering or a two-phase swap, and neither is the root.

Staging is non-destructive, so `s_tmp[j]` already holds every issue's content.
Clobbering `s_old[j]` therefore loses *nothing* while that tmp survives — the
handler deleting it is the entire defect, and it is one line. Fixing it there
covers rename chains and swaps alike.

Topological ordering was weighed and rejected. It would keep chains from
clobbering a pending entry at all, but only as belt-and-braces over a path the
handler already makes safe — and a guard that cannot be driven red is exactly
what this review round penalized (*"2 of 115 cases cannot fail"*). It also does
not cover a true cycle, where no ordering exists. Refusing a cyclic plan up
front was rejected for permanently refusing a migration that works correctly
today on the happy path, at more code than the handler fix it would replace.

## Resolution (2026-08-12)

Fixed in `c2d1376`. The commit loop records each name a completed `mv` has
taken. On failure, a pending entry whose old name is in that set is the case
this issue describes — its on-disk copy has been overwritten and its staged file
is all that remains — so that file is **kept and named** rather than deleted.
Every other pending tmp never landed and is still discarded, so the disjoint
case is unchanged and strands nothing.

The message no longer asserts a guarantee the handler cannot make: the
"none has been lost" all-clear is now printed **only** when nothing was held,
and the held case instead names each staged path with the issue it belongs to.

Pinned by `case_issues_migrate_commit_failure_on_a_chain_holds_the_last_copy`,
whose fixture makes `aaa`'s rename target `bbb`'s current name and fails the
seam at `bbb`. Proven to go red with the chain-awareness neutered: the case
reports B's content absent from every file in the collection, dotfiles included,
while stderr carries the false all-clear. The pre-existing disjoint-shape case
passes with the guard neutered, which is what confirms the two cover different
shapes.
