---
id: 20260731-normalize-the-citation-sweep-configured-roots
num: 173
title: "Normalize the citation sweep configured roots"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:38:25Z
updated: 2026-07-31T20:28:56Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

`sweep_citations` (`skills/spec/scripts/reconcile.sh:352`) consumes all four
content roots in their raw configured spelling, stripping only a trailing `/` and
a leading `./`:

    root="$(jc get "$key" 2>/dev/null)"; root="${root%/}"; root="${root#./}"

`git ls-files` emits repo-relative paths regardless of the pathspec spelling, so
`$f` is always relative. With an absolute `issues_path`, the trigger at `:467`

    test -n "$issues_root" && case "$f" in "$issues_root"/*) issue_touched=1 ;; esac

can never fire. Issue citations are rewritten on disk and `INDEX.md` is **never
regenerated** — silently, at exit 0.

## Why it matters

This is the exact failure mode the index-regeneration fix exists to prevent, and
the same defect class as the absolute-specs-dir split fixed one line earlier in
the same run. The `--apply` guard normalizes the specs dir; it stops short of the
sweep's own roots.

## Fix

Normalize the four roots the way `$dir` is now normalized — canonicalize and
derive the worktree-relative form before use.

Finding 3 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

Closed by the C′-fix build. Each of the four roots is now canonicalized and
reduced to its worktree-relative form once, at the point it is read, so the
trigger compares two paths written the same way.

**A second, larger failure closed with it.** The roots are passed to
`git ls-files` as one pathspec set. A configured root that resolves *outside* the
worktree makes git reject the entire set — so a single stray root silently
disabled the sweep for all four, not just its own. Such a root is now dropped
with a warning and the remaining three still sweep.

The `.`-valued edge (a root configured as the worktree top itself) is handled at
the trigger rather than left to a prefix match that cannot fire, since
`git ls-files` emits no leading `./`.

Fixtured with an absolute `issues_path`, asserting both halves — the citation
rewritten *and* `INDEX.md` regenerated — because the defect was precisely that
the first happened without the second.
