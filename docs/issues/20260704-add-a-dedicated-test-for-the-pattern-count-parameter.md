---
id: 20260704-add-a-dedicated-test-for-the-pattern-count-parameter
num: 47
title: "Add a dedicated test for the pattern count parameter"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T23:41:11Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/007-verify-engine/plan.md
---

## Description

## Context

Surfaced during the spec 035 build (`/jim:verify`). `jimverify.sh`'s
`check_pattern` implements the optional `count=<n>` parameter with
exact-match semantics (holds iff the match count equals `n`, overriding
polarity), but no named `tests/jimverify.sh` case exercises it — the
polarity / scope / regex paths are covered, `count` is not.

## What

Add a `tests/jimverify.sh` case (or two) asserting the `count=` behavior:

- a `pattern` check with `count=<n>` that matches exactly `n` times -> `holds`
- the same with a mismatching actual count -> `violated`
- (optionally) a non-numeric `count=` value -> `failed` (the malformed-param path)

## Why

`count=` is documented in the plan's Interface Contract and in
`check-authoring.md`, so it is part of the check-data grammar users may
author. Untested behavior can silently regress.

## Resolution (2026-07-09)

Shipped. Added `case_jimverify_check_pattern_count` (and a `verify_repo_count`
fixture) to `tests/jimverify.sh`, asserting all three `count=` facets against
the real `check_pattern`: an exact match → `holds` (`matched 3 (expected 3)`),
a mismatching count → `violated` (`matched 3, expected 5`), and a non-numeric
`count=` → `failed` (`invalid count parameter`). The evidence strings are
asserted too, so a regression in either the outcome or the message is caught.
Suite green: 71 passed, 0 failed.
