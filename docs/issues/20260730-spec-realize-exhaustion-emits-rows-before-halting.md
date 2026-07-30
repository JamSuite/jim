---
id: 20260730-spec-realize-exhaustion-emits-rows-before-halting
num: 157
title: "Spec realize exhaustion emits rows before halting"
status: open
priority: medium
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:09Z
updated: 2026-07-30T19:35:09Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`alloc_reconcile_realize_spec` puts its ordinal-exhaustion guard **inside** the
emit loop, so a batch prints its earlier rows and then returns 1. Its own
docstring claims the opposite — that it "halts (rc 1) before emitting anything".
`alloc_next_id_spec` does check before printing, so the two allocator paths
disagree about their own contract.

## Why it is currently harmless, and why that is not enough

The only consumer today discards the mapping on non-zero rc, so nothing acts on
the partial output. But:

- the contract is simply false for any other consumer, and the docstring is what
  a future caller will trust;
- the preview path pipes realize straight to stdout, so partial rows are
  developer-visible output that looks like a plan and is not one;
- **no test exercises exhaustion in any allocator path**, so nothing would
  notice if the behaviour drifted further.

## Fix

Compute the whole batch before emitting any row — or, if partial emission is
actually wanted, fix the docstring to say so and make the consumer contract
explicit. The first is the smaller change and matches the sibling path.

Add an exhaustion fixture for the realize path. Note
[[20260730-fixture-the-terminal-exhaustion-refusal-in-next-id]] tracks the same
gap for `next-id`; both are the same missing-coverage story and are best closed
together. [[20260729-provide-a-recovery-path-for-a-group-that-exhausts-its-ordinal-sp]]
is the separate question of what a developer does once a group is genuinely
exhausted.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
