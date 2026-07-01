---
id: 20260701-add-diff-range-belt-tests-for-command-sub-and-trailing-slash-ref
num: 26
title: "Add diff-range belt tests for command-sub and trailing-slash refs"
status: open
priority: low
labels: [test-infra, jimledger, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-01T21:48:42Z
updated: 2026-07-01T21:48:42Z
origin: docs/specs/jim/030-blueprint-update/review.md
---

## Description

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
