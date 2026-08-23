---
id: 20260812-direct-arm-raises-a-false-rewrite-alarm-on-a-stale-checkout
num: 306
title: "Direct arm raises a false rewrite alarm on a stale checkout"
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
created: 2026-08-12T03:41:51Z
updated: 2026-08-12T07:32:50Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

On the checked-out arm, a routine stale checkout produces a false "destination
branch was rewritten" alarm on every read until the developer pulls.

## Mechanism

`skills/issue/scripts/place.sh:601` compares the bookmark against local HEAD with
no fetch — deliberate, since on that arm HEAD is the destination's tip. But the
bookmark can hold a **remote-observed** tip written by an earlier routed run
(`place_check_rewrite:1073` records the tip just observed on the remote).

Reproduction with `issue_placement = "main"`:

1. From a feature branch, run any read verb. The routed path fetches, records
   origin's `main` tip R in the bookmark, and leaves `refs/heads/main` at the
   older C1 — `place_remote_tip`'s fetch does not move the local head.
2. `git checkout main` without pulling.
3. Any read: `place_disclose_rewrite` computes `is-ancestor(R, C1)` → rc 1 →
   "destination branch 'main' was rewritten … Mutations published before the
   rewrite may no longer be there."

It repeats on every direct read, and survives a rejected direct push, until the
developer pulls.

This is the same comparison shape — the bookmark against a ref only a publish
advances — that the closed
`20260807-placement-bookmark-produces-false-rewrite-alarms` removed from the
offline plumbing path, reappearing on the direct arm when disclosure was added
there.

A precision defect, not a false negative: no rewrite goes undetected.

## Proposed action

On the direct arm, compare against a tip of the same provenance — either skip
disclosure when the bookmark was recorded from a remote this arm did not consult,
or record provenance alongside the bookmark value. No test mixes a routed run
and a direct run in one clone; add one.

## Origin

Post-build review of `issue/011`, AC 12.

## Resolution (2026-08-12)

Fixed in `fb6864e`, by the first of the finding's two options — comparing against a
tip of the same provenance — rather than by recording provenance alongside the
bookmark value.

The arm now probes the destination's owner, so the tip it compares against is the
one the bookmark records: what the destination was last seen holding at its
owner. With a remote configured and reachable that is the remote's tip; with no
remote configured the local branch *is* the destination, so HEAD is authoritative
exactly as before; and an unreachable remote is not authoritative, so the run
neither compares nor records — the same rule the plumbing arm follows.

Pinned by `case_place_direct_read_does_not_alarm_after_a_routed_read`, which
builds the finding's own reproduction: a routed read from a feature branch
records the remote's tip, the developer checks the destination out without
pulling, and the direct read must report the real condition — the checkout is
behind — rather than a rewrite. Proven to go red when the comparison reverts to
bookmark-against-HEAD.
