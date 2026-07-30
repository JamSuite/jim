---
id: 20260730-harden-the-spec-realize-path-against-silent-failures
num: 151
title: "Harden the spec realize path against silent failures"
status: open
priority: low
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:15Z
updated: 2026-07-30T19:35:15Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

Four small defects on the spec realize path, each individually narrow, all
sharing one failure mode: something goes wrong and the run still reports
success. Batched because they are one afternoon together and eight separate
issues apart.

## 1. `mv` without `-T` can nest instead of refusing

Both `jimfile.sh cmd_mv_spec_id` and the shipped `cmd_mv_spec` omit
`-T`/`--no-target-directory`. If the target appears as a directory between the
`[[ -e "$target" ]]` check and the `mv`, the source is nested **inside** it and
the verb still prints the target and exits 0 — a silent wrong move.

Narrow single-developer race, and a pre-existing pattern rather than something
`sdlc/017` introduced. Fix: add `mv -T` to both.

## 2. An absolute specs dir passes the guard, then splits the behaviour

An absolute spelling of the configured specs directory passes
`reconcile.sh --apply`'s realpath guard. After that, **tracked** identities fail
loudly (`valid-relpath` rejects an absolute path) while **untracked** ones
succeed — the same run behaving two ways depending on git state. Fix: normalize
or reject at the guard, so one spelling cannot produce two behaviours.

## 3. The index regen swallows its exit code

`skills/spec/scripts/reconcile.sh:384` runs the issues-index regeneration as
`… >/dev/null 2>&1` with no status check, so a failed regen leaves a stale
`INDEX.md` and the run still returns 0.

This is the *same* defect already filed against the issue-side script as
[[20260728-reconcile-sh-swallows-the-index-regen-exit-code]] (there at
`skills/issue/scripts/reconcile.sh:202`), reproduced verbatim in the new
spec-side script. Fix both in one pass and the pattern stops spreading.

## 4. An uncommitted provisional spec's self-citations stay stale, silently

The citation sweep enumerates targets through `git ls-files`, so an untracked
spec directory's own files are invisible to it. A provisional spec that has not
been committed yet is realized and renamed while the citations **inside its own
body** still point at the provisional identity — with no warning.

Concrete rather than theoretical: `apply_pending` deliberately supports
untracked directories, so this is a supported flow, not an edge case. Fix:
include the realized directory's own files in the sweep regardless of git state,
or warn explicitly when the directory is untracked.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30), which recorded these as the batchable hardening residue.
