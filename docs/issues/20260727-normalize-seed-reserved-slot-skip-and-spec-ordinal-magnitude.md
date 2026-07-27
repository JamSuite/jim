---
id: 20260727-normalize-seed-reserved-slot-skip-and-spec-ordinal-magnitude
num: 121
title: "Normalize seed reserved-slot skip and spec-ordinal magnitude"
status: open
priority: medium
labels: [id-coordination, alloc, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T05:34:21Z
updated: 2026-07-27T05:34:21Z
origin: docs/specs/platform/008-registry-seed/review.md
---

## Description

## Description

Surfaced by the `platform/008` post-build review (review.md Finding 1; a
judge-confirmed `blueprint-slot-reserved` living-intent violation, in-change).

`alloc_seed_derive_specs` (`skills/file/scripts/jimalloc.sh`) recognizes the
reserved slot with a literal string test `[[ "$ord" == "000" ]]` (:373) and
bounds the spec ordinal with a value-only `(( 10#$ord > 999 ))` (:380), with no
digit-length cap. Two bounded consequences:

- A directory whose ordinal parses to `0` but is not literally `000` (`0-foo`,
  `00-foo`) bypasses the skip and emits `spec allocate <group>/000 …`, occupying
  the reserved coordinate — a breach of "emits no record for the reserved slot."
- A pathological ≥19-digit ordinal could overflow `intmax_t` and wrap past the
  `>999` guard.

Neither reissues a consumed id (id 0 never raises the next-id high-water; a
wrapped ordinal is rejected by the read-side `alloc_valid_specid` on replay) and
neither injects (the value is log content, never a git argument). The issue-num
path already does this correctly with a `${#num} > 15` length cap (:427).

## Fix

- Normalize the reserved-slot skip to `(( 10#$ord == 0 ))`.
- Add a digit-length cap on the spec ordinal, mirroring the issue-num path.
- Add fixtures for `0-foo` / `00-foo` and an over-long ordinal.
