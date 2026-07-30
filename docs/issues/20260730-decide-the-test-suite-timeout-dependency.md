---
id: 20260730-decide-the-test-suite-timeout-dependency
num: 139
title: "Decide the test suite timeout dependency"
status: open
priority: low
labels: [testing, portability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T01:09:09Z
updated: 2026-07-30T01:09:09Z
origin: docs/specs/platform/011-rename-path-correctness/review.md
---

## Description

Surfaced by the post-build review of `platform/011` (rename-path correctness).

`tests/jimalloc.sh` now calls `timeout 10` in two cases — the group-rename cycle
fixtures for `alloc_group_alias_map` and `alloc_next_id_spec`. Before
`platform/011`, no file under `tests/` used `timeout` anywhere.

`timeout` is GNU coreutils. It is not in POSIX.

## Why it was used

The invariant under test is *termination*. A group-rename cycle (`A→B`, `B→A`)
must not spin. A non-terminating walk has no error message and no output — it
simply hangs every allocation. `platform/011`'s Design Decision 4 made the
point explicitly: a passing test is the only evidence the rule was implemented.

Without a bound, a regression here would hang the whole suite rather than fail
one case, which is strictly worse for diagnosis: an unbounded hang looks like an
environment problem, not a broken invariant.

## Why it is worth a decision rather than silence

The project's stated posture is bash + POSIX only, no third-party dependencies.
The `platform` blueprint's `no-third-party-deps` invariant scopes its mechanical
check to `skills/` and names `jq|yq|bats`, so this use is outside both the scope
and the pattern — the invariant **holds** mechanically, and the review recorded
no violation. But the invariant's prose ("scripts use bash + POSIX only") is the
kind of rule that erodes by accumulating individually-justified exceptions
nobody wrote down.

The point is not that `timeout` is a bad choice here. It is that the choice is
currently invisible: nothing in the repo records that the test suite now needs a
non-POSIX tool, or why.

## Options

1. **Accept it explicitly.** A line in `tests/jimalloc.sh`'s header noting the
   `timeout` dependency and the reason (a hang has no failure signal). Cheapest,
   and makes the exception legible to the next reader.
2. **Widen the invariant deliberately.** If POSIX-only is meant to bind `skills/`
   and not `tests/`, say so in the blueprint's invariant prose so the scope is a
   decision rather than an artifact of the pattern's `scope=` field.
3. **Bound the walk in-process.** Drop the external dependency by having the
   fixture assert termination some other way. Likely more complexity than the
   problem deserves, but it is the option that keeps the posture absolute.

## Why low

`timeout` is present on every platform jim realistically runs on (coreutils,
busybox, and macOS via coreutils). This is about keeping a stated constraint
honest, not about a portability failure anyone will hit soon.
