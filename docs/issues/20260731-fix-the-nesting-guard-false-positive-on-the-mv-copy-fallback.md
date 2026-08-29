---
id: 20260731-fix-the-nesting-guard-false-positive-on-the-mv-copy-fallback
num: 171
title: "Fix the nesting guard false-positive on the mv copy fallback"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [file, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:38:10Z
updated: 2026-07-31T20:08:51Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`undo_nested_rename` (`skills/file/scripts/jimfile.sh:544-574`) decides whether a
rename landed by comparing the target's inode to the source's pre-move inode. Its
premise — "the rename landed only if `<target>` IS the directory that was at
`<src>`" — is false. `mv` guarantees the contents arrive, not the inode.

When `rename(2)` returns `EXDEV`, `mv` recursively copies and deletes: new inode,
exit 0, rename correct on disk. This is not reachable via mount points (both paths
share a parent, so that is `EBUSY` and `mv` fails first), but it **is** reachable
on overlayfs, where renaming a lower or merged directory returns `EXDEV` by
default absent `redirect_dir` — the kernel documentation names `mv(1)` recursively
copying as the expected handling. That is the normal filesystem in containers and
microVMs.

## Consequence

The guard fires on the inode mismatch, finds no `<target>/<basename>`, and takes
the `else` branch: it reports *"could not be restored — repair `<target>` by
hand"* and returns 1 while the tree is correct. Acting on that instruction is
itself the destructive step.

Downstream, `skills/spec/scripts/reconcile.sh:267-270` sets `failed=1; continue`,
skipping the frontmatter rewrite, the `REALIZED` emission, the citation sweep and
the `moved=` ledger record — with the registry ordinal already durably published.
A retry cannot recover, because the directory no longer wears its `P-` basename
for the pending scan to find. Half-applied and stranded.

## Fix

Make `<target>/<basename>` the primary tell rather than the inode: treat "target
inode differs AND `<target>/<basename>` absent" as *landed*. Detection of real
nesting is unaffected.

Two supporting defects in the same function:

- `[[ -n "$src_ino" ]] || return 0` (`:562`) silently downgrades both rename verbs
  to an unguarded `mv` whenever `dir_inode` yields empty. The check belongs
  *before* the move, where refusing costs nothing.
- The restore's own `mv` is unverified — an asymmetry inside a function whose
  entire threat model is a concurrent writer.

Test gap: neither guard fixture drives the code through `cmd_mv_spec` /
`cmd_mv_spec_id`, so the `src_ino` capture and the `|| return 1` wiring are
untested end to end, and this shape has no fixture at all.

Finding 1 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

All four parts closed in the C′-fix build
(`docs/notes/20260731-c-prime-fix-build-notes.md`).

**The premise is inverted and written down.** Inode identity is now treated as
sufficient to prove a rename landed and useless to disprove it, which is what
`mv` actually guarantees. `<target>/<basename>` is the second tell and the one
that holds on both kinds of filesystem: a rename that landed nested nothing. The
claim is stated in the function's own docstring rather than left implicit, since
its being unstated is why the false one shipped.

**The ambiguous case is resolved toward detection.** Where the move copied,
`<target>/<basename>` present with a third inode cannot be distinguished from a
race — no portable tell separates them. It restores and fails. The cost is a
directory that legitimately contains an entry named for its own former basename,
which would be a provisional spec directory nested inside another spec directory.
This narrows the stated intent of the existing "passes a real rename" fixture:
it still passes, exiting at the inode check, but its premise is now explicitly
conditional on the filesystem preserving inodes.

**The two supporting defects went with it.** The `src_ino` emptiness check moved
to both callers as a pre-move refusal, where refusing costs nothing; the function
degrades to the basename tell rather than passing everything through. The
restore's own `mv` is verified — the source must be back and must not have nested
in turn.

**The test gap is closed at the wiring, not just the function.** Four fixtures:
the copy-fallback shape staged as `cp -R` + `rm -rf`, the empty-inode
degradation, and — the ones that would have caught this — `mv-spec` and
`mv-spec-id` driven through their real command surface with `mv` shimmed to copy
and delete. Both wiring fixtures reproduced the defect before the fix, exercising
the `src_ino` capture and the `|| return 1` path that no fixture reached. Suite
954 → 958.
