---
id: 20260801-reconcile-literal-pathspec-use-between-the-commit-and-rename-ver
num: 186
title: "Reconcile literal-pathspec use between the commit and rename verb families"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [platform, ledger, scripts, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T00:22:45Z
updated: 2026-08-01T00:22:45Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

The two git-mv primitives hand every path to git under `--literal-pathspecs`
(`skills/ledger/scripts/jimledger.sh:307`, `:313` for `rename-tracked`; `:608`,
`:637` for `move-spec-dir`), so a `valid-relpath`'d path's pathspec magic is
never interpreted.

The seven path-scoped commit verbs do not. They stage with `--` plus
`valid-relpath` and worktree containment (`:235`, `:438`, `:537` among others),
but without `--literal-pathspecs`.

## Why it matters

`--` stops *option* parsing; it does not stop git from interpreting **pathspec
magic**. `valid-relpath` rejects an empty path, an absolute path, and a `..`
segment — it does not reject a leading `:`, so a path shaped like
`:(glob)docs/**` or `:/` clears the boundary and would be read as magic by the
commit verbs while the rename verbs would take it literally.

Reachability is the open question and should be settled before deciding the fix:
the commit verbs' path arguments are largely config-derived or composed from
already-gated tokens rather than free-form input, so there may be no live path
that carries magic. That is worth establishing rather than assuming — the
`relpath-validation` invariant names literal-pathspec semantics for the git-mv
primitives specifically, which reads as a deliberate scope, but the asymmetry is
undocumented.

## Fix

Either extend `--literal-pathspecs` to the commit family for uniformity, or add
the leading-`:` rejection to `valid-relpath` and record why the commit family is
scoped out.

Surfaced by a `/jim:verify --since` judge on the `ref-validation` invariant
during the C′-fix build.
