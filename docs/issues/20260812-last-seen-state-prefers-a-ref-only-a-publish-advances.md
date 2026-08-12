---
id: 20260812-last-seen-state-prefers-a-ref-only-a-publish-advances
num: 312
title: "Last-seen state prefers a ref only a publish advances"
status: open
priority: high
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:35Z
updated: 2026-08-12T03:41:35Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

An offline read can serve a commit *older* than the one the clone last saw, while
printing "serving the last-seen state".

## Mechanism

`skills/issue/scripts/place.sh:411-420`. `place_local_tip` consults
`refs/heads/<dest>` first and falls back to the bookmark
`refs/jim/issue-placement/<dest>` **only when that head is absent**.

The two refs are advanced by different events:

- `refs/heads/<dest>` moves only on a successful publish (`place_land:1255`, or
  the direct-mode commit).
- the bookmark advances on every authoritative read
  (`place_check_rewrite` → `place_advance_bookmark`).

So for a clone that has published once and later read online while a teammate
published: bookmark = the teammate's tip Y (objects fetched and local),
`refs/heads/<dest>` = this clone's older commit X. The next offline read takes
the `[[ -z "$tip" ]]` branch as false and serves **X**, announcing it as the
last-seen state — strictly less than what the clone last saw.

`refs/remotes/<remote>/<dest>`, which the fetch opportunistically updates, is
never consulted anywhere in the file.

This is the same class as the closed
`20260807-offline-placed-read-serves-an-empty-collection`, one branch over.

## Test blind spot

`place_seed_collection` always creates `refs/heads/<branch>` in the same repo,
and the one clone-based offline case asserts "still no local head" — so every
fixture has either a head or a bookmark, never a head that is *behind* a
bookmark.

## Proposed action

Serve the newest of the local head and the bookmark rather than preferring the
head, or consult the remote-tracking ref. Add a fixture whose head is behind its
bookmark.

## Origin

Post-build review of `issue/011`, AC 6.
