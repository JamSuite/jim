---
id: 20260812-migration-destroys-an-issue-on-the-success-path-at-rc-0
num: 336
title: "Migration destroys an issue on the success path at rc 0"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, data-loss, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:19Z
updated: 2026-08-13T08:48:12Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`migrate.sh`'s plan builder reserves the old id of every row that is not a
`rename`, at `skills/issue/scripts/migrate.sh:126-130`:

    [[ "$action" == rename ]] || taken["$old"]=1

That correctly covers the three build-phase skips. But a **fourth** downgrade
happens later, inside the assignment loop, at `migrate.sh:144-148`:

    if ! jf valid-id "$new" >/dev/null 2>&1; then
      printf '%s\t%s\t%s\t%s\n' "skip-unmigratable" "$old" "" \
        "discriminated id failed validation"
      continue
    fi

The `continue` skips `taken["$new"]=1` at `:150` and never sets `taken["$old"]`.
The row entered as a `rename`, so the reservation loop deliberately left its old
name free — a licence that is only sound when the file actually moves away. Here
it does not: the file stays at `$old.md` while `$old` remains assignable.

The full trace, all deterministic in glob order:

- `:135` — a later row's derived `new == $old` is not in `taken`, so no
  discriminator fires; it is emitted as a plain `rename`.
- `:239-240` — the downgraded row is absent from the mapfile (only
  `rename`/`collision-resolved` rows are written there, `:219`), so `finalid="$id"`
  and its `s_new` is `$dir/$old.md` — the same path as the later row's `s_new`.
  Two staging entries now share one target and nothing checks for it.
- `:267-271` — both `mv`s run; the second silently overwrites the first.
- `:305-309` — the retire loop then removes the later row's own old name, deleting
  the surviving duplicate.
- `:325-326` — the run exits **0**, printing `N renamed …, 1 skipped`.

One issue is gone. No error, no warning, no held staged file, no index warning.
The preview shows both a `rename … -> X` and a `skip X` but flags no overlap.

The precondition is already an exercised path: a `-2` discriminator pushing an id
past the 128-character cap. `tests/issues.sh:2087-2108` builds exactly that with a
119-character slug and asserts the refusal — but nothing covers what the refused
row's name is then free to collide with.

**Introduced by the review-remediation round's own discriminator fix.** The
chain-aware commit-failure handler shipped in the same round is logically correct
and its held branch is pinned; this defect sits beside it, on the success path.

Found by the `migrate.sh` region investigator and independently confirmed by the
`atomic-index-write` judge during the fourth review.

## Action

Set `taken["$old"]=1` on the discriminated-validation-failure branch at
`migrate.sh:145-147`, before `continue`.

Pin it with a three-file fixture under `issue_id_prefix = "date"`: two files whose
re-derived ids collide such that the second discriminates past the cap and is
skipped, plus a third whose re-derived id equals the skipped file's existing name.
Assert all three issues still exist after apply.

## Resolution

**2026-08-13.** Fixed in `562ec34`, as the action specifies: `taken["$old"]=1`
on the discriminated-validation-failure branch, before the `continue`.

Reproduced before fixing, and the trace matched this issue exactly — three
issues in, two out, `rename … -> X` and `skip X` both in the preview, rc 0.

**Pinned by** `case_issues_migrate_downgraded_row_keeps_its_name_reserved`, the
three-file fixture this issue describes. It asserts on the surviving **titles**
rather than on a file count: the defect renames one file over another, so the
count stays at three while one issue's content is gone. Proven by neutering the
one line and watching it go red with `expected [A B C], got [A C]`.

**One detail the fixture turns on, which this issue does not name.** The
downgraded row must be processed *before* the row that claims its name.
Reserving on downgrade protects rows processed later; a claimant processed
earlier has already taken the name, and the reservation comes too late to matter.
The fixture is ordered so the downgrade comes first, which is the reachable case
under the plan builder's glob ordering. Read the fix as closing that case rather
than as a general guarantee that two rows can never contend for one name.

**The knock-on is disclosed, not silent.** With the name held, the later row
discriminates, fails the same 128-character cap, and is reported as its own
`skip … (un-migratable: discriminated id failed validation)`. The preview now
shows three skips and no rename, instead of a rename onto an occupied file.

**The three sibling downgrades were checked and need nothing.** All three emit
their rows during the build phase, so the reservation loop at `:129`
(`[[ "$action" == rename ]] || taken["$old"]=1`) already covers them. Only the
fourth sits inside the assignment loop, past that loop — which is the shape the
previous round's lesson describes, a downgrade moved past the guard its siblings
sit inside.

**The rename-chain path was re-read and is unaffected.** A chain (A→B, B→C) is
kept correct by two existing mechanisms: every issue is copied to a staged tmp
before any `mv` runs, so a completed rename cannot destroy a pending issue's only
copy; and the retire loop skips any old name another issue was renamed onto.
Reserving a downgraded row's own name introduces no chain and disturbs neither.

Suite **1383 → 1384**.
