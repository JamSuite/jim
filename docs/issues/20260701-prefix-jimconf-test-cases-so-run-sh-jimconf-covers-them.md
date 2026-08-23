---
id: 20260701-prefix-jimconf-test-cases-so-run-sh-jimconf-covers-them
num: 23
title: "Prefix jimconf test cases so run.sh jimconf covers them"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [test-infra, meta-test, jimconf]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-01T06:28:22Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/001-blueprint-spec/plan.md
---

## Description

## What

`run.sh <filter>` matches case *names* by substring; the convention is that each
test file prefixes its cases with the script under test (`tests/jimfile.sh` →
`case_jimfile_*`, so `run.sh jimfile` runs all of them). `tests/jimconf.sh`
breaks it — its cases use bare descriptive names (`case_no_config_*`,
`case_list_*`, `case_keys_*`, `case_malformed_lines_are_ignored`, …), none
containing "jimconf". So `run.sh jimconf` matches only 2 of 63 cases and
silently skips the rest.

## Why it matters

`run.sh jimconf` reports a green "2 passed" while running almost nothing; a
regression in `list` / `keys` / defaults / parsing would go uncaught. It is a
false-coverage trap. Surfaced in spec 029 Task 3, whose plan `Verify` was
`run.sh jimconf` — the enumeration changes were only genuinely verified by
running `bash tests/jimconf.sh` (63/63).

## Fix

Rename the ~13 `tests/jimconf.sh` cases to the `case_jimconf_*` prefix (e.g.
`case_jimconf_no_config_returns_defaults`), matching every other test file.
Mechanical and low-risk; the runner and other test files already conform. (A
weaker alternative is documenting the substring-filter gotcha, but the rename is
the real fix.)

## Scope

`tests/jimconf.sh` only — ~13 case renames.
