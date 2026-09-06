---
id: 20260812-cmd-begin-refuses-where-cmd-run-degrades-on-a-failed-reindex
num: 303
title: "cmd_begin refuses where cmd_run degrades on a failed reindex"
status: closed
priority: medium
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
created: 2026-08-12T03:41:49Z
updated: 2026-08-12T06:06:19Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The group chose one read-failure posture — serve, disclose, carry a non-zero
status — and applied it to one of the two placement read doors. `cmd_begin`
still refuses, and it is the door the `insights` verb opens.

## Mechanism

`skills/issue/scripts/place.sh:869`:

```
place_reindex "$handle/collection" || { rm -rf -- "$handle"; return 1; }
```

This runs for read handles too, so a two-phase read deletes the materialized
collection — which still carried the destination's own `INDEX.md` — and returns 1
having served nothing. `skills/issue/SKILL.md:259-273` opens exactly this door for
`insights`, so the verb produces no view at all.

The sibling door 620 lines below documents the opposite decision for the
identical failure (`place.sh:1488-1496`):

```
# A read can, because the materialized copy still carries the index the
# destination holds — so it degrades ... disclosed and carried in the status
# rather than refused.
```

Secondary, same door: `cmd_run:1475-1479` takes the `before` snapshot with
`|| return 1` on the read path too, so a read can fail on a snapshot it will
never publish.

## Proposed action

Apply the chosen posture to `cmd_begin`'s read path: keep the handle, disclose on
stderr, and carry the staleness in the exit status. Neither placement door's
reindex-failure branch has a test — add one per door.

## Origin

Post-build review of `issue/011`. The posture decision was taken during the
remediation and applied to `cmd_run` only; the second door was missed. Found
independently by the AC 6 investigator and the `staleness-gated-reads` judge.

## Resolution (2026-08-12)

Fixed in `8673d3c`. `cmd_begin`'s read path now takes the posture the group
chose and `cmd_run` already applied: the handle is kept, the materialized copy
is served carrying the index the destination holds, the degradation is disclosed
on stderr, and the staleness is carried in the exit status. A write still
refuses, since a collection whose index was never brought up to date is how the
destination acquires a stale one.

The secondary is closed too, on both doors: a read handle no longer snapshots a
base it can never publish. A read measures no changed set, so taking one was only
a way for it to fail on work it never uses.

**Not pinned by a case, deliberately.** The directory being reindexed is one
`place.sh` creates and owns, so the failure is unreachable without a production
test hook — the same conclusion WP13 reached for the sibling door's relaxation,
and this group avoids such hooks. Verified instead by forcing `place_reindex` to
fail and observing the result: `begin --read` returns 1 having printed its
handle, with the destination's own index in the served directory and the
disclosure on stderr, while `begin` for a write refuses with no handle.
