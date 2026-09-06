---
id: 20260808-placed-reads-hard-fail-where-the-group-read-path-is-tolerant
num: 291
title: "Placed reads hard-fail where the group read path is tolerant"
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
created: 2026-08-08T18:39:50Z
updated: 2026-08-11T11:05:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

A placed read now hard-fails when index regeneration fails, where the issue
group's own read path deliberately tolerates the same failure. The divergence
was introduced as a side effect rather than decided.

## Mechanism

`skills/issue/scripts/place.sh:1199`:

```bash
place_reindex "$PLACE_COLL" || return 1
```

`skills/issue/scripts/render.sh:89-95` (`ensure_index`), commented "tolerant of
failure":

```bash
bash "$INDEX_SCRIPT" "$dir" >/dev/null 2>&1 || true
```

`index.sh` returns 1 on an unwritable directory, a failed `mktemp`, a short
compose, or a failed rename. On the placement path any of those now turns a read
that would previously have served the destination's existing index into rc 1 with
"could not regenerate the collection index".

## Both positions are defensible

Strict is arguably right for the materialized copy: the run is about to serve a
view, and the alternative is serving one whose index it knows nothing about.
`reconcile.sh:246-249` also treats the same failure as loud.

Tolerant is right for `render.sh`: a stale-but-valid prior `INDEX.md` is a
reasonable fallback on the real collection, and a read verb failing outright is
worse than a slightly stale list.

The problem is that the two now differ without anyone having chosen, and the
placement path is the one users hit under a branch placement.

## Proposed action

Decide it deliberately and make the two agree, or document why they differ. If
strict is kept, note it in the group blueprint's read-path guarantee, since
"reads never fail" is currently implied by `render.sh`'s posture.

## Test

Not covered. A case with an unwritable materialized collection would pin
whichever behavior is chosen.

## Resolution (2026-08-11)

Fixed in `5a5c83d`, as one decision with
[[20260808-render-sh-swallows-a-regeneration-failure-and-serves-a-stale-ind]]
rather than as two independent fixes — which is what this issue asked for.

The group's rule is now that **a view known to be stale is never reported as
success, and never published.** That resolves the divergence by posture, not by
making the two calls identical:

- `place.sh`'s **read** path no longer hard-fails. The materialized copy still
  carries the index the destination holds, so the run degrades to what a reader
  in the working tree gets — served, disclosed on stderr, and carried in the
  exit status.
- `place.sh`'s **write** path still refuses. There the stale index is precisely
  what would reach the shared branch, and refusing is not a failure to disclose.

The read relaxation is **not pinned by a test.** The collection it reindexes is
a temp directory `place.sh` creates and owns, so the failure is unreachable
without injecting a hook into production code, which this group avoids. It was
verified by neutering `place_reindex` against a seeded placement fixture: before
the change a placed read returned rc 1 with empty stdout; after it, rc 1 with
the destination's own `INDEX.md` on stdout and the disclosure on stderr, while a
placed write still refused and published nothing. The reachable half of this
issue — an unwritable collection in a developer's checkout, which is also what
the direct arm serves reads from — is pinned through `render.sh`.
