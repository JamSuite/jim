---
id: 20260812-commit-routed-arm-re-establishes-neither-the-gate-nor-head
num: 304
title: "commit routed arm re-establishes neither the gate nor HEAD"
status: closed
priority: medium
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T03:41:50Z
updated: 2026-08-12T06:06:19Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The routed arm of `place.sh commit` publishes to a destination read back from
handle state without re-establishing the placement gate — while the direct arm
re-proves exactly those facts and documents why.

## Mechanism

`skills/issue/scripts/place.sh:958-975`. The arm reads `dest` and `prefix` from
`<git-dir>/jim-place/<token>/state` and hands them to `place_commit_changes` →
`place_build_commit` (`update-index … "$prefix/$name"`) and `place_land`
(`refs/heads/$dest`), reaching `git push`, `git update-ref`, `git ls-remote` and
`git fetch` with no `place_valid_branch`, no coordination-branch refusal, and no
`place_prefix` in that process.

The direct arm at `:926-951` does the opposite, with the reasoning stated inline:
"everything that made publishing them safe was established at `begin`, and each
of those facts can have changed since." It re-runs `place_destination` and
`place_prefix` and refuses on drift of destination, prefix, or checked-out
branch.

Also missing on this arm: any HEAD check. `begin` on a feature branch mints a
plumbing handle; if the developer checks out the destination before `commit`,
`place_land` moves `refs/heads/<dest>` by `update-ref`, which has no
checked-out-branch protection — the ref moves under the developer's index and
working tree, leaving the collection reading as deleted. The direct arm guards
this exact transition and has a test; the plumbing arm has neither.

Severity is bounded: the value did clear the gate in the `begin` process, the
handle root is containment-checked, the token is charset-gated, and every call
site carries `--end-of-options`. The reachable case is configuration drift
between the two steps — for example `id_coordination_branch` retargeted onto the
in-flight destination, which `place_destination` would have refused.

## Proposed action

Re-run `place_destination` and `place_prefix` on the routed arm and refuse on
drift, mirroring `:932-944`; add a HEAD check refusing when the destination
became the checked-out branch. Add drift cases for the routed arm — the three
existing ones exercise the direct arm only.

## Origin

Post-build review of `issue/011`; found by the trust-boundary investigator, the
two-phase region investigator, and the `placement-gate-before-git` judge
independently.

## Resolution (2026-08-12)

Fixed in `8673d3c`. The destination-and-prefix re-proof the checked-out arm
carried inline was lifted into `place_handle_drift` and is now run by both arms
before either reaches git with a value read back out of handle state — so the
coordination-branch refusal and the branch-name gate are re-established on this
side of that read, not merely recorded on the other side of it.

Each arm keeps its own side of the checked-out test, which is the half that
differs: the checked-out arm refuses when HEAD is no longer the destination, and
the routed arm refuses when it has *become* the destination, because `update-ref`
has no checked-out-branch protection and would move the ref under the
developer's index and working tree.

Pinned by four cases —
`case_place_commit_refuses_a_retargeted_destination`,
`…_a_destination_that_became_the_coordination_branch`,
`…_a_moved_collection_path` and
`…_when_the_destination_became_checked_out` — each proven to go red with its
guard removed. The coordination case is the reachable one the finding named.
