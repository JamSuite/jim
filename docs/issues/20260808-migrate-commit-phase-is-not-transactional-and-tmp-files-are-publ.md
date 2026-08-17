---
id: 20260808-migrate-commit-phase-is-not-transactional-and-tmp-files-are-publ
num: 288
title: "migrate commit phase is not transactional and tmp files are publishable"
status: closed
priority: medium
labels: [issue, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:49:42Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The `atomic-index-write` invariant (medium) is judged **violated** on two counts.
Clause 1 (tmp+mv atomicity) holds at all seven writer sites; clause 2 ("a failed
run leaves the previous file untouched") does not.

## 1. `migrate.sh`'s commit phase is not transactional

`skills/issue/scripts/migrate.sh:225-233` deletes every old name **before** it
renames any staged tmp:

```bash
for i in "${!s_tmp[@]}"; do
  [[ "${s_old[$i]}" != "${s_new[$i]}" ]] && rm -f "${s_old[$i]}"
done
for i in "${!s_tmp[@]}"; do
  if ! mv "${s_tmp[$i]}" "${s_new[$i]}"; then
    ...
    echo "error: commit failed at ${s_new[$i]} — the collection is PARTIALLY migrated; ..."
```

An `mv` failure at index *k* leaves issues *k..n* with neither their old name nor
their new one — their only copy is a `.migrate.tmp.XXXXXX` the return path does
not clean up. The script's own message concedes it and defers recovery to git.

It is a deliberate, documented limitation rather than an oversight, but it is the
one site in the group where the invariant's second clause does not hold, and it
is **untested**: only the staging phase has fault injection
(`tests/issues.sh:2077-2111`); nothing matches `PARTIALLY`, `commit failed`, or
`migrate.tmp`.

## 2. `place_snapshot` is the only enumerator that publishes the tmp namespace

`skills/issue/scripts/place.sh:908`:

```bash
done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
```

No `-name` filter, no dotfile exclusion. Every sibling enumerator excludes the
tmp namespace — `index.sh:306,311` (`*.md` glob plus an explicit `.*` skip),
`render.sh:79`, `migrate.sh:202`, `backfill.sh:115,166`. `place_snapshot` is the
exception, and it is the one whose output becomes tree entries via
`git hash-object -w` (`:906`).

`place_materialize`'s four gates all admit `.INDEX.md.tmp.abc123`, so once
published it is re-materialized on every run, sits unchanged in both `before` and
`after`, and never appears in `INDEX.md` — durable and invisible. The direct-mode
analogue is `git add -- "$prefix"` (`:480`), which stages dotfiles too. No
`.gitignore` entry covers the namespace.

Not reachable on any rc-0 emitter path traced: every emitter removes its tmp on
failure and returns non-zero, and `cmd_run` aborts before the `after` snapshot.
Two residual routes remain — a tmp stranded in a two-phase handle across a crash
(which `place.sh:505-506` explicitly anticipates), and a concurrent session's
mid-flight tmp in direct mode.

## Proposed action

- `place.sh`: add a name filter to `place_snapshot`'s `find`, or a name gate in
  `place_materialize`. One line makes the invariant self-enforcing rather than
  dependent on every emitter's cleanup being crash-proof.
- `migrate.sh`: interleave the rename with the delete per file, or stage into a
  sibling directory and swap — plus a fault-injection case for the commit loop.

## Resolution (2026-08-11)

Fixed in `cfe4e5a`. Staged files are renamed into place before any old name is
retired, so the worst a mid-commit failure can leave is an issue present under
both names rather than under neither. Old names are retired in a second pass
that skips any name another issue was just renamed onto — a chain or swap makes
one file's old name another's new one, and the delete-first ordering existed to
handle exactly that.

Separately, the collection snapshot excludes the dotfile namespace its atomic
writers stage through; it was the one enumerator admitting it and the one whose
output becomes tree entries.

The chain guard is defensive and unpinned: under the prefix migration a chain
appears unreachable, since a re-derived target conforms by construction and the
collision resolver discriminates instead. It is kept because the rename-first
ordering depends on it for correctness under any map.
