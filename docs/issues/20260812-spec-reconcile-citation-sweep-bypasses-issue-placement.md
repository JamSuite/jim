---
id: 20260812-spec-reconcile-citation-sweep-bypasses-issue-placement
num: 316
title: "Spec reconcile citation sweep bypasses issue placement"
status: open
priority: high
labels: [issue, placement, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:31Z
updated: 2026-08-12T03:41:31Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`/jim:spec reconcile --apply`'s citation sweep edits issue files without routing
through `place.sh`, so under a branch placement it writes to the wrong branch or
silently does nothing.

## Mechanism

`skills/spec/scripts/reconcile.sh:461-684`. `sweep_citations` builds its target
set from the configured `issues` root, enumerates it with
`git --literal-pathspecs ls-files` plus untracked files — i.e. the **working
checkout** — and rewrites each matching file in place. It then regenerates the
index at `:682` with `bash "$HERE/../../issue/scripts/index.sh" "$issues_root"`.
That explicit directory argument is exactly `index.sh`'s routing opt-out
(`index.sh:284`), so the regeneration cannot route either.

Under a branch placement this gives one of two wrong outcomes:

- the working branch carries a copy of the collection, so issue-body edits **and**
  `INDEX.md` land on the working branch — the outcome AC 3 forbids; or
- it does not, so the destination's issue bodies keep citing the retired
  provisional identity, the sweep counts zero touched files, and it exits clean
  with nothing reported.

`skills/spec/SKILL.md` mentions placement only in its candidate-batch lines;
nothing in the spec group references `place.sh`.

## Proposed action

Route the sweep and its index regeneration through `place.sh` — either by
wrapping the rewrite in a `run --verb edit` invocation, or by using the two-phase
`begin`/`commit` door since the sweep is a multi-file edit with no single
wrappable command. Either way the spec skill needs a `place.sh` grant it does not
currently have.

## Origin

Post-build review of `issue/011`; found by tracing AC 3's "every collection
write" against the tree rather than the diff.
