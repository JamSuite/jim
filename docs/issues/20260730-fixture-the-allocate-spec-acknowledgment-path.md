---
id: 20260730-fixture-the-allocate-spec-acknowledgment-path
num: 140
title: "Fixture the allocate spec acknowledgment path"
status: open
priority: medium
labels: [id-coordination, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T01:09:07Z
updated: 2026-07-30T01:09:07Z
origin: docs/specs/platform/011-rename-path-correctness/review.md
---

## Description

Surfaced by the post-build review of `platform/011` (rename-path correctness).

`platform/011` made `alloc_next_id_spec` refuse a group that has been renamed
away, naming the redirect, until the caller acknowledges it with
`--follow-redirect`. The acknowledgment is threaded through **both** CLI paths —
`peek spec` and `allocate spec`.

Only the `peek spec` half is fixtured (`tests/jimalloc.sh`,
`case_jimalloc_peek_spec_group_alias_follow_redirect`).

## Why the unfixtured half is the one that matters

`peek` is advisory and binds nothing. `allocate spec` is where the consent gate
actually governs an allocation: the redirect check runs *inside* the CAS builder,
against the log the attempt is about to land on, so a rename arriving mid-retry
is caught rather than missed by an earlier read. That in-loop placement is the
part with no test.

It is also the security-motivated half. The refusal exists because naming a
redirect on stderr informs only whoever reads stderr — a program capturing
stdout can honor the notice's existence and still get a different group than it
asked for. The whole point is that the *machine* contract is not silent, and the
machine contract is the one exercised through `allocate`.

## Verified working by hand

Against a real repo with a `group rename` appended to the local coordination
branch:

```
allocate spec dashboard "three"
  → error: group renamed — 'dashboard' is now 'ui'; ask under that name,
    or pass --follow-redirect to accept the redirect
  → rc 1

allocate spec dashboard "three" --follow-redirect
  → ui/003
  → log gains:  group allocate ui …
                spec allocate ui/003 three …
```

So this is a coverage gap, not a defect. The behavior is right; nothing pins it.

## What the fixture needs

A `run_jimalloc_in` case over `alloc_new_repo` (the heavier real-git style the
file already uses for allocation paths, not the piped-log style used for folds):

- allocate two ids under a group, append a `group rename` to the coordination
  branch, then assert the refusal (rc 1, stderr names the target, no stdout).
- assert the acknowledged call returns the id under the **current** group.
- assert the landed records include a `group allocate` for the current group —
  the builder re-derives the group from the returned id, and that re-derivation
  is what makes the record name `ui` rather than `dashboard`.

## Why medium

Unreachable today: the live registry holds zero rename records, and nothing in
production calls `allocate spec` at all — the spec-side consumer is unwired. But
this is exactly the path that consumer will take, and the ordering guarantee
inside the CAS loop is the kind of thing that breaks silently under a later
refactor.
