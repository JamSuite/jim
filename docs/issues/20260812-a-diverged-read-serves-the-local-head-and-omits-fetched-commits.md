---
id: 20260812-a-diverged-read-serves-the-local-head-and-omits-fetched-commits
num: 298
title: "A diverged read serves the local head and omits fetched commits"
status: open
priority: medium
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:42:05Z
updated: 2026-08-12T03:42:05Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

A read on a clone whose destination has diverged serves the local head and
silently omits the commits the same run just fetched.

## Mechanism

`skills/issue/scripts/place.sh:493-496`. In the `diverged` state
`place_resolve_tips` sets `PLACE_WORK_TIP` to this clone's own head, and both read
doors materialize `PLACE_WORK_TIP` (`cmd_run:1473`, `cmd_begin:853`). So a read
that successfully reached the remote serves a collection missing every issue the
destination gained since the fork.

The only disclosure for that state, `place_disclose_unpublished`, is gated to
writes on both doors (`:1471`, `:845`), so the reader is told nothing — even
though the run *knows* the destination moved, having just fetched it.

Reachable after any offline write followed by a teammate publishing. Under
`ahead` no content is lost, since the head descends from the remote tip;
`diverged` is the composition that loses visibility.

The spec's freshness criterion requires reads to "consult the freshest reachable
state of the destination branch before serving", and the user story says a reader
should "never act on a stale or partial view".

## Proposed action

Either serve the merge of both sides on a read, or disclose on the read path that
the view omits published commits this clone has not merged. No test drives a read
in the `diverged` state.

## Origin

Post-build review of `issue/011`, AC 6; found independently by the AC 6
investigator and the publish-engine investigator.
