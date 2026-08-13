---
id: 20260812-citation-sweep-drops-containment-on-the-checked-out-arm
num: 326
title: "Citation sweep drops containment on the checked-out arm"
status: closed
priority: critical
labels: [spec, security, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:20Z
updated: 2026-08-13T10:27:58Z
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

## Resolution

**2026-08-13.** Fixed in `sweep_citations`. Containment is now a property of the
**enumeration** rather than a claim about the provider: every target clears the
boundary of the root it came from — worktree paths inside the worktree, handle
entries inside the directory `begin` handed back — with the same symlink
discipline the function's three other enumerations already carry. A contained
symlink is skipped (a symlink is never a citation's home, and `>` follows it to a
file the enumeration never selected); one that escapes refuses the run before any
rewrite, and the handle goes back with the refusal.

The wording this issue proposes — check "whenever `place_dir` resolves inside the
worktree" — was **not** taken. It asks which arm `begin` took, and that coupling
is what caused this. On the arm that materializes, the new check is redundant
because `place.sh` has already established the same property; that redundancy is
the point, and it costs three lines.

The other half of the Action — having `begin` report its arm — is correct in
principle and closes the class rather than this instance, but `begin`'s output is
`<token>\t<dir>` and every consumer parses two fields, so a third is breaking, and
it moves the `place.sh` Provides face and both placement contract edges with it.
Filed separately as `20260813-begin-does-not-report-which-arm-it-took`, which is
where that decision belongs.

Two smaller reaches came out of writing the guard. `realpath -m` is asked for
first and `-f` second, so a **dangling** symlink is containment-checked rather
than passed over as "not a regular file" — `>` creates what it points at. And an
`INDEX.md` entry is dropped *after* containment, so a hostile one is refused
rather than silently skipped.

Pinned by `case_specreconcile_sweeps_the_collection_with_the_destination_checked_out`
(the issue's own reproduction: a committed symlink, the destination checked out,
rc 1, nothing outside the worktree written, no handle stranded), with
`..._sweep_refuses_a_dangling_escape_in_the_collection`,
`..._sweep_skips_a_symlinked_collection_entry`, and
`..._sweep_skips_a_tracked_symlink` for the neighbouring reaches, and
`..._sweeps_the_checked_out_collection` for the arm's happy path — which had no
coverage at all before this, on either half.

Every guard was proved by neutering it and watching its case go red. One did not
at first: the symlinked-collection-entry case passed with its guard removed,
because the link sorted *after* its target, so by the time the rewrite followed
it the target was already swept and there was nothing left to do. The fixture now
names the link so it sorts first.

**One guard in this fix ships pinned by nothing.** `begin` printing an empty
directory at rc 0 cannot be driven from outside, but the resolution check in
front of the enumeration catches it — and it has to, because `for entry in
""/*.md` globs the filesystem root. `realpath -m -- ""` fails, which is what
makes the check fire. It holds the posture `place.sh`'s own comment names: a
refusal reported as success hands back an empty dir that resolves to wherever
the caller happens to be standing.

## Correction

**2026-08-13.** The resolution above says the fix applies "the same symlink
discipline the function's three other enumerations already carry". That is
wrong, and it undersells what the fix changed.

Two of the four enumerations carried the discipline, not three: the
untracked-files pass and the realized-directories pass each tested `-L`
explicitly, skipping a contained symlink and refusing an escaping one. The
handle enumeration carried neither half. And the **tracked** enumeration carried
only one half, by accident rather than by design: its containment check resolves
symlinks, so an escaping one was refused — but a *contained* one passed every
gate and was swept **through**, rewriting a file the enumeration never selected.

So the fix did not bring a fourth enumeration into line with three. It brought
two into line with two, and one of those two is a **behavior change on the
tracked path**: a contained tracked symlink used to be rewritten through and is
now skipped. It is pinned by
`case_specreconcile_sweep_skips_a_tracked_symlink`, which was written for it —
but it belonged in the resolution's own words, not folded into a count.

The same sentence is in `remediation.md` § The sweep round and in commit
`cb17771`'s body. The record is corrected; the commit body is not rewritten,
because five `## Resolution` sections in this collection already cite shas in
this range.
