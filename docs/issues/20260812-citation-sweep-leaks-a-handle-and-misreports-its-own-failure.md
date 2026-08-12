---
id: 20260812-citation-sweep-leaks-a-handle-and-misreports-its-own-failure
num: P-20260812-citation-sweep-leaks-a-handle-and-misreports-its-own-failure
title: "Citation sweep leaks a handle and misreports its own failure"
status: open
priority: medium
labels: [spec, placement, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:56Z
updated: 2026-08-12T21:53:56Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Three hygiene defects in `sweep_citations`, the routed citation sweep added in the
review-remediation round. None misroutes a write; all three are recoverability and
honesty problems. (The containment defect in the same function is filed
separately.)

## 1. A handle leak on the one uncovered error path

`skills/spec/scripts/reconcile.sh:659-661`:

    if ! swtmp="$(mktemp -d 2>/dev/null)"; then
      echo "error: citation sweep — cannot create temp dir" >&2; return 1
    fi

Returns with `place_token` live and no `abort`, leaving
`.git/jim-place/handle.XXXXXXXX` stranded with a full materialized copy of the
collection and no token disclosed to the operator.

Every other post-`begin` exit is clean: `:653-656` aborts on an empty file set,
`:772` aborts when nothing was touched, and `:762-770` deliberately *keeps* the
handle on a refused publish while naming the token and both remedies — that one is
correct and should stay.

There is also no `trap` in `reconcile.sh`, so an interrupt mid-sweep strands the
handle the same way. Nothing enumerates `<git-dir>/jim-place`, so a stranded
handle is neither reported nor reclaimed — and `place.sh:804-805`'s header claims
otherwise ("A crash between the two steps strands one directory there, which
`commit` reports and `abort` removes"); `place_handle_dir:862` only reports a token
you already hold.

## 2. The `begin`-failure message states a rewrite that has not happened

`skills/spec/scripts/reconcile.sh:636-641` reports that "the spec-side citations
are rewritten and the issue-side ones are not". But `begin` is called at `:636` and
the rewrite loop does not start until `:664` — nothing has been swept, spec-side or
issue-side.

It is reachable on a real refusal: on the direct-handle arm `cmd_begin` runs
`place_dirty_guard`, so any developer with an uncommitted edit in the collection
gets this rc-2 refusal and is told to reconcile a half-applied state that does not
exist. Meanwhile `apply_pending` has already renamed the directories and
`record_realized` still runs (`:919-920`), so the realization *is* durable with
every citation stale — which is the true state and is not what the message says.

## 3. A nested configured root re-enumerates the collection

`:520-523` drops the issues root from the `git ls-files` pathspec under `route`.
But `git ls-files -- docs` still lists `docs/issues/*.md`, so if another configured
root (`specs`, `brainstorms`, `debug`) is an ancestor of the issues root — or is
`.` — the worktree fork is enumerated and rewritten *as well as* the destination.

Worse, `issues_root` is `""` under `route`, so the guard at `:746-748` cannot fire,
`issue_touched` stays unset for the worktree copy, and its `INDEX.md` is never
regenerated.

## Action

1. Abort `$place_token` before the `return 1` at `:661`, as the empty-set branch
   three lines above already does; name the token in the message.
2. Reword `:637-641` to say what has actually happened at that point — spec
   directories renamed and frontmatter realized, no citation swept.
3. Under `route`, drop from `files` any enumerated path that prefix-matches the
   resolved issues root, rather than relying on the pathspec alone.
4. Either add an age-based sweep of `<git-dir>/jim-place` on `begin`, or correct
   `place.sh:804-805` to say stranded handles are neither reported nor reclaimed.

Coverage note: `tests/specreconcile.sh` has one placement case (`:298`), the
plumbing happy path. Unpinned: the `issue_touched == 0` abort, the `commit`-failure
disclosure, the handle-leak path, and `place.sh mode` failing.
