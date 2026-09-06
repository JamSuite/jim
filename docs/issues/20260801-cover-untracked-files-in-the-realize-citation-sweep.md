---
id: 20260801-cover-untracked-files-in-the-realize-citation-sweep
num: 197
title: "Cover untracked files in the realize citation sweep"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [sdlc, spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T21:23:36Z
updated: 2026-08-02T06:52:07Z
origin: conversation
---

## Description

The spec realizer's citation sweep enumerates its four content roots via
`git --literal-pathspecs ls-files` (`skills/spec/scripts/reconcile.sh:425`),
plus the realized directories' own markdown. Tracked files only: an untracked
file that cites the provisional identity is invisible to the sweep, and the
exclusion is named nowhere in the report.

## Observed (first production spec-side realize, 2026-08-01)

Realizing `platform/P-20260801-registry-integrity-and-drift` → `platform/012`:

- An untracked issue file created in the same offline session kept both of its
  `P-` citations (frontmatter `origin:` and a body path).
- The sweep *did* rewrite `INDEX.md`'s copy of that origin (reported
  `REWROTE docs/issues/INDEX.md 197 path`), and the post-sweep index
  regeneration then rebuilt INDEX.md from the unrewritten issue file —
  resurrecting the stale citation. The run's own REWROTE report described a
  state its next step destroyed.
- The dangling path surfaced only through the index integrity warning
  ("origin path does not resolve"), and was repaired by hand.

Same class as the dropped-root finding fixed earlier (a partial sweep reading
as clean); new instance, one enumeration source over.

## Proposed action

Enumerate untracked-but-not-ignored files too (`git ls-files --others
--exclude-standard` alongside the tracked set), or name the untracked
exclusion in the report as explicit non-coverage. Either way, the regen must
not be able to resurrect a citation the same run just rewrote — covering the
untracked source closes that hole at the root.

The window is the normal offline workflow itself: artifacts created while the
coordination point is unreachable are exactly the files most likely to be
uncommitted when a realize-before-commit ordering is chosen.

## Resolution (2026-08-02)

Fixed in the pre-B build (`929e9eb`). The sweep enumerates
untracked-but-not-ignored markdown alongside the tracked set in every content
root, under the same symlink discipline as the realized-directory enumeration
— an in-worktree symlink is skipped, one that escapes the worktree refuses the
sweep before any temp state exists. The index regeneration now rebuilds from
rewritten sources, which closes the resurrection hole at the root rather than
naming the exclusion. Fixtured end to end, including the INDEX.md readback the
production instance corrupted.
