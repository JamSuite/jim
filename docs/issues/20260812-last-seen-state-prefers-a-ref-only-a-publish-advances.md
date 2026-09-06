---
id: 20260812-last-seen-state-prefers-a-ref-only-a-publish-advances
num: 312
title: "Last-seen state prefers a ref only a publish advances"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:35Z
updated: 2026-08-12T06:30:53Z
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

## Resolution (2026-08-12)

Fixed in `49b7921`. `place_local_tip` no longer prefers either ref. Whichever of
`refs/heads/<dest>` and the bookmark descends from the other is the newer and is
taken; when they are unrelated the head wins, because it carries this clone's own
unpublished commits and only the origin tier has the machinery to reconcile the
two sides.

Pinned by an extension to `case_place_offline_read_does_not_rewind_the_bookmark`,
which is already the fixture that puts a clone's head behind its bookmark — it now
also reads offline and asserts the teammate's issue is in the view. Proven to go
red with the descendant test removed.

The finding's note that `refs/remotes/<remote>/<dest>` is never consulted stands
and was not taken: the bookmark already records what the last authoritative run
saw, which is the same fact with an explicit write behind it rather than one
fetch's side effect.
