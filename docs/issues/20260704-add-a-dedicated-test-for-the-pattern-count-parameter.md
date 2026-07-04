---
id: 20260704-add-a-dedicated-test-for-the-pattern-count-parameter
num: 47
title: "Add a dedicated test for the pattern count parameter"
status: open
priority: low
labels: [verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T23:41:11Z
updated: 2026-07-04T23:41:11Z
origin: docs/specs/jim/035-verify-engine/plan.md
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
