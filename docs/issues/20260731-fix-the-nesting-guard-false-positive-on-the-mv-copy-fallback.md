---
id: 20260731-fix-the-nesting-guard-false-positive-on-the-mv-copy-fallback
num: 171
title: "Fix the nesting guard false-positive on the mv copy fallback"
status: open
priority: critical
labels: [file, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:10Z
updated: 2026-07-31T12:38:10Z
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
