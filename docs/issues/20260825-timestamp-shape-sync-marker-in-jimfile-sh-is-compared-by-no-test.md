---
id: 20260825-timestamp-shape-sync-marker-in-jimfile-sh-is-compared-by-no-test
num: 372
title: "Timestamp-shape sync marker in jimfile.sh is compared by no test"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [test, scripts, platform]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T05:00:25Z
updated: 2026-08-25T05:00:25Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## Description

`skills/file/scripts/jimfile.sh:781` carries a `SYNC(ts-shape)` marker declaring
that the timestamp-shape pattern it uses is the same one three issue-group
guards carry. No test compares it against them.

## The state

Four copies of the marker exist, and all four currently agree:

- `skills/issue/scripts/index.sh:469`
- `skills/issue/scripts/render.sh:181`
- `skills/issue/scripts/backfill.sh:80`
- `skills/file/scripts/jimfile.sh:781`

`case_issues_timestamp_shape_triplicate_identical` (`tests/issues.sh:1887`)
compares the first three against each other. The fourth is unguarded, and the
case's name says three where the marker set is four.

## Why it matters

`jimfile.sh now` is what produces the timestamps those three guards judge. If
the producer's shape and the readers' shape diverge, the readers degrade values
the producer considers well-formed — the failure surfaces as timestamps
rendering as `-` or falling back to day-start, not as a test going red. The
guard set exists precisely to make that class of drift loud.

The sibling coupling in the same family is guarded on both sides:
`case_place_valid_branch_agrees_with_the_allocator_copy` compares
`place_valid_branch` against `alloc_valid_branch` across this same group
boundary. Nothing in either marker says the asymmetry is deliberate.

## Direction

Extend the comparison to the fourth copy. Placing it in `tests/jimfile.sh`
alongside `case_jimfile_is_valid_id_triplicate_identical` matches where the
other cross-boundary comparison already lives, and keeps the platform-side copy
guarded from the platform's own test file; extending the existing issue-side
case is the alternative. Either way the case name should stop saying three.

Surfaced while regenerating the `issue` group's blueprint, which records the
byte-identity rule these markers implement as an invariant.
