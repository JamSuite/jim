---
id: 20260701-add-diff-range-belt-tests-for-command-sub-and-trailing-slash-ref
num: 26
title: "Add diff-range belt tests for command-sub and trailing-slash refs"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [test-infra, jimledger, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-01T21:48:42Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/002-blueprint-update/review.md
---

## Context

Surfaced by the spec 030 post-build review (Finding 5). Low risk — the allowlist
forecloses these inputs uniformly — but `valid_git_ref` is the *sole* security
boundary for the ad-hoc `diff-range` ref, so a belt test hardens it against
future edits.

## Gap

The `diff-range` rejection tests (`tests/jimledger.sh`) exercise `--output=`, `;`,
space, `~`, `^`, `:`, `..`, and `/leading`, and prove the `--output=` no-file-write
foreclosure. They do NOT individually assert:

- glob metacharacters (`* ? [ ]`)
- a backtick / command-substitution-shaped ref (e.g. `` a`touch x` ``)
- a trailing-slash ref (e.g. `foo/`)
- a newline-bearing ref

## Proposed fix

Add cases for a command-substitution-shaped ref and a trailing-`/` ref (the
strongest belt tests, since `valid_git_ref` is the only boundary).

## Relates to

spec 030 security Finding 5; `tests/jimledger.sh` diff-range cases.

## Resolution

Closed the enumerated gap in `tests/jimledger.sh`:

- Extended `case_jimledger_diff_range_rejects_bad_refs` with the trailing-slash
  ref (`trailing/`), glob metacharacters (`a*b`, `a?b`, `a[b]c`), and a
  newline-bearing ref (`$'a\nb'`) — each asserted rc 1 with no diff output.
- Added `case_jimledger_diff_range_command_sub_no_exec` — the strongest belt,
  mirroring the existing `option_injection_no_write` case: a backtick
  command-substitution-shaped ref (`` x`touch <marker>` ``) is rejected rc 1
  and the marker is never created, proving the ref never reaches a shell.

Confirmed each new ref is rejected by `valid_git_ref` itself ("invalid git
ref"), i.e. at the security boundary, not git's downstream unresolvable path.
Suite green (45/45).
