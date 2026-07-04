---
id: 20260704-complete-the-jim-verify-check-verb-test-matrix
num: 49
title: "Complete the /jim:verify check-verb test matrix"
status: open
priority: medium
labels: [verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T23:53:20Z
updated: 2026-07-04T23:53:20Z
origin: docs/specs/jim/035-verify-engine/review.md
---

## Description

## Context

From the spec 035 post-build review (`review.md` Finding 1). Plan Task 4
specified "must/must-not pattern pass+fail, structure exists/absent … negative
param cases", but the shipped `tests/jimverify.sh` covers only part of the
`check`-verb outcome matrix.

## What

Add the missing `check`-verb test cases:

- **pattern fail/pass directions:** `must` + required pattern *absent* -> `violated`;
  `must-not` + forbidden pattern *absent* -> `holds`. (Only `must`->holds and
  `must-not`->violated are covered today.)
- **structure violated direction:** `exists=<safe-but-missing-relpath>` -> `violated`;
  `absent=<glob-that-matches>` -> `violated`. (Only the holds direction is covered.)
- **param-gate completeness:** exercise the `..`-segment and leading-dash rejects on
  `exists` and `absent` (today only `scope` is tested for those; `exists` only for
  absolute; `absent` for none).
- **non-execution probe:** assert grep/find did NOT run with a tainted param (a
  side-effect probe), mirroring `tests/jimledger.sh:639-657` ("no command executed"),
  rather than relying on the `verdict=failed` label alone.

## Why

A mutation hardwiring a `must` check to never fire, or a `must-not` to always fire,
would pass CI today. The Finding-6 "never handed to grep/find" guarantee is
currently asserted only indirectly.

Extends the earlier follow-up "Add a dedicated test for the pattern count=
parameter" — that count= case belongs in the same matrix pass.
