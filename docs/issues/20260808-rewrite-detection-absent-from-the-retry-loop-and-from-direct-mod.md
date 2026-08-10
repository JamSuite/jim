---
id: 20260808-rewrite-detection-absent-from-the-retry-loop-and-from-direct-mod
num: 295
title: "Rewrite detection absent from the retry loop and from direct mode"
status: closed
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:51Z
updated: 2026-08-10T23:00:55Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Spec AC #12 says a non-fast-forward destination tip "is detected and disclosed by
the read verbs". Two paths never check at all.

## Gap 1 — the retry loop

`place_commit_changes` re-reads the tip on every retry
(`skills/issue/scripts/place.sh:1279-1284`) and calls `place_check_rewrite`
nowhere in the loop body. If the rejection that triggered the retry was caused by
a force-push, the run regrafts onto the rewritten tip, lands, and then
`place_advance_bookmark` (`:1268`) records a commit built on the rewritten
history.

So the rewrite is neither disclosed nor detectable afterwards — the run erases
its own evidence. Narrow (it needs a lost race concurrent with a rewrite), but
the erasure is the part that matters: a later read cannot recover the signal.

## Gap 2 — direct mode

`cmd_run` routes to `place_direct` (`:1154-1157`) and `cmd_begin` returns early
(`:608-618`); neither path reaches `place_check_rewrite`. A read verb run from a
checkout of the destination branch performs no ancestry check whatsoever.

This is the common case for a project whose `issue_placement` names the branch
developers actually work on (e.g. `main`).

## Proposed action

- Call `place_check_rewrite` after each tip re-read inside the retry loop, with
  `authoritative` set from the tier the re-read used.
- Decide whether direct mode should check. It has no bookmark discipline today
  (`place_direct_publish` advances the bookmark before the push and never rolls
  back — see the related open issue), so this may be better sequenced after that
  is settled.

## Test

`tests/place.sh:995-1081` covers the reachable-tier true positive and the
fast-forward true negative only. Nothing covers the retry path, direct mode, or
the rewind shape (a force-push to an *ancestor* of the seen tip — the ancestry
direction is correct in the code, but unexercised).
