---
id: 20260812-direct-arm-never-consults-the-remote-before-serving-a-read
num: 305
title: "Direct arm never consults the remote before serving a read"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:06Z
updated: 2026-08-12T03:42:06Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

When the destination branch is the checked-out one, reads never consult the
remote and never say so — so the freshness guarantee does not hold on that arm.

## Mechanism

`skills/issue/scripts/place.sh:595-612` (`place_direct`) and `:810-821`
(`cmd_begin`'s direct arm) contain no `place_remote` / `place_remote_tip` call:
no `ls-remote`, no fetch, no `unreachable` flag, no disclosure. The only
freshness work is `place_disclose_rewrite`, which compares HEAD against this
clone's own bookmark and says nothing about the remote.

The in-code justification — "its tip is HEAD and no fetch is needed to know it"
— is true of the *local* tip only. The remote is a live participant on this arm:
`place_direct_publish` pushes to it.

So a read under, say, `issue_placement = "main"` with `main` checked out serves a
checkout that may be arbitrarily behind `origin/main`, silently. The spec's
freshness criterion is conditioned on "when a remote exists", which holds here.

## Proposed action

Decide whether the direct arm owes the same freshness guarantee. If it does,
consult the remote before serving and disclose when it cannot be reached. If it
does not — a defensible position, since the developer's own git flow governs
their checkout — say so in the criterion and in the code, rather than leaving the
asymmetry unstated.

## Origin

Post-build review of `issue/011`, AC 6.
