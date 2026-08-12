---
id: 20260812-citation-sweep-drops-containment-on-the-checked-out-arm
num: 326
title: "Citation sweep drops containment on the checked-out arm"
status: open
priority: critical
labels: [spec, security, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:20Z
updated: 2026-08-12T21:53:20Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`sweep_citations` runs a relpath + worktree-containment loop over its enumerated
targets at `skills/spec/scripts/reconcile.sh:625-632`, then appends the placement
handle's entries **after** it, at `:644-648`:

    for entry in "$place_dir"/*.md; do
      [[ -f "$entry" ]] || continue
      [[ "$(basename "$entry")" == "INDEX.md" ]] && continue
      files+=("$entry")
    done

The comment at `:617-624` justifies the ordering: handle entries "live in a temp
directory outside the worktree by construction", and "place.sh materializes each
entry as a regular file with a plain name resolving inside the collection".

That is true of the **plumbing** arm only.

`place.sh cmd_mode` (`skills/issue/scripts/place.sh:1608-1632`) has no HEAD check,
so it prints `route` even when the destination branch is the one currently checked
out. `cmd_begin` then takes the direct-handle arm (`place.sh:956-974` →
`place_direct_handle:919-933`) and hands back `<token>\t<prefix>` where `<prefix>`
is the **working tree's own collection**. Nothing materialized those entries;
`place_materialize`'s mode / plain-name / containment gates never ran on them.

`[[ -f "$entry" ]]` is true for a symlink to a regular file, so the entry is
appended past the guard, and the rewrite at `:738` (`cat -- "$tmp_out" > "$f"`)
follows it out of the worktree.

Trigger: `issue_placement = "main"` — a configuration `skills/issue/SKILL.md:17`
explicitly recommends — with `main` checked out, and a committed symlink in the
collection. A committed symlink clears `place_dirty_guard`.

The same function rejects exactly this in its two sibling enumerations
(`:563-574` untracked, `:595-601` own-dirs), and
`case_specreconcile_untracked_symlink_escape_refused` proves the project treats it
as a live threat.

**Introduced by the review-remediation round**, in the new code written to close
the AC 3 routing bypass. The routing itself is correct — nothing is misrouted.

`tests/specreconcile.sh` has exactly one placement case (`:298`), which exercises
the plumbing arm only. The `route`-plus-checked-out-destination arm is covered
nowhere.

## Action

Apply the same `-L` rejection plus `jf valid-relpath` and worktree-containment
check to the `:644-648` loop whenever `place_dir` resolves inside the worktree —
or have `place.sh begin` report which arm it took, so the sweep can exempt only
the plumbing arm.

Add `case_specreconcile_sweeps_the_collection_with_the_destination_checked_out`
with a committed symlink in the collection, asserting rc 1 and nothing written
outside the worktree.
