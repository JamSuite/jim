---
id: 20260727-add-tests-jimalloc-sh-to-platform-map-territory
num: 125
title: "Add tests/jimalloc.sh to platform map territory"
status: open
priority: low
labels: [blueprint, territory]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T11:03:18Z
updated: 2026-07-27T11:03:18Z
origin: docs/specs/platform/009-provisional-reconcile/review.md
---

## Description

## Problem

`BLUEPRINT.md`'s `platform` group territory lists the sibling test files but
omits `tests/jimalloc.sh`:

```
Territory: skills/conf, skills/file, skills/ledger, skills/meta-test,
           tests/jimconf.sh, tests/jimfile.sh, tests/jimledger.sh, tests/metatest.sh
```

`tests/jimalloc.sh` is the test file for `skills/file/scripts/jimalloc.sh` (a
platform script under the in-territory `skills/file`), so it is platform-group
code. Because it is not declared, `/jim:verify`'s territory-conformance check
reports it as a stray for the platform group.

## Impact

Cosmetic / map-completeness only — the test still runs via the `tests/*.sh` glob,
and ids/tests carry no authority. But the territory declaration is inconsistent:
four sibling platform test files are listed and this one is not, so every
territory-conformance run (e.g. the living-intent sensor at review time) flags it.

## Suggested fix

Add `tests/jimalloc.sh` to the `platform` territory in `BLUEPRINT.md` (via
`/jim:blueprint` or `/jim:partition`), so platform's territory lists all of its
tests uniformly and the stray clears.

Surfaced by the platform/009 post-build review (living-intent territory
conformance).
