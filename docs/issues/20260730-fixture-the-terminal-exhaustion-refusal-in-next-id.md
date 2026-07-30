---
id: 20260730-fixture-the-terminal-exhaustion-refusal-in-next-id
num: P-20260730-fixture-the-terminal-exhaustion-refusal-in-next-id
title: "Fixture the terminal exhaustion refusal in next-id"
status: open
priority: medium
labels: [id-coordination, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T00:49:54Z
updated: 2026-07-30T00:49:54Z
origin: docs/specs/platform/011-rename-path-correctness/plan.md
---

## Description

Surfaced while building `platform/011` (rename-path correctness).

`alloc_next_id_spec` acquired two documented failure modes, and only one of
them is fixtured.

The **retryable** refusal — the queried group has been renamed away and the
caller has not acknowledged the redirect — is covered three ways: at the
function level, at the `peek spec` CLI level, and on the acknowledged
`--follow-redirect` path.

The **terminal** refusal is not covered at all. `alloc_next_id_spec` refuses
when `max + 1` would be wider than `ALLOC_MAX_ORD_DIGITS`, because an ordinal
that wide could never be read back by the registry's own bootstrap. No fixture
drives a group's high-water to that limit, so the branch ships untested.

## What the fixture needs

One record reaches it — a 15-digit ordinal is inside the fold's legality gate,
so it counts, and the increment then falls outside:

```
spec allocate core/999999999999999 x 20260726 x
→ alloc_next_id_spec core   # rc 1, "group exhausted", no stdout
```

Worth asserting alongside it that the refusal is *terminal* in the way the
Interface Contract claims: passing `--follow-redirect` must not change the
outcome, since acknowledging a redirect has no bearing on exhaustion. That
distinction is the whole reason the two failure modes are documented
separately — a consumer that collapses them treats a recoverable case as
fatal, or retries a hopeless one forever.

## Why medium

The branch is unreachable through normal use: it needs an ordinal at the width
limit, which only a crafted or absurd record produces. So this is an untested
error path rather than an untested behavior — real, but not urgent. It was left
out deliberately rather than missed: the plan's task list was complete, and
adding un-planned fixtures at the completion gate is scope drift.
