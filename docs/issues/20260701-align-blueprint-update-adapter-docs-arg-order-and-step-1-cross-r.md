---
id: 20260701-align-blueprint-update-adapter-docs-arg-order-and-step-1-cross-r
num: 25
title: "Align blueprint-update adapter docs (arg-order and Step-1 cross-ref)"
status: open
priority: low
labels: [blueprint, review, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-01T21:48:41Z
updated: 2026-07-01T21:48:41Z
origin: docs/specs/jim/030-blueprint-update/review.md
---

## Description

## Context

Surfaced by the spec 030 post-build review (Findings 2 and 3). Both are cosmetic
documentation inconsistencies with no functional impact — the adapter parses
correctly either way — bundled here.

## Arg-order inconsistency (Finding 2)

`/jim:review` Step 10 invokes `/jim:blueprint` with `"<group> --from-review <spec-dir>"`
(group-first), while `/jim:blueprint`'s `argument-hint` and routing table document
flag-first `--from-review <spec-dir> <group>`. Both parse correctly (the flag
carries its own value, so stripping is position-independent), but the two skills
state the order differently. Pick one order and make both match.

## Step-1 cross-reference (Finding 3)

`/jim:review` Step 10 says the group was "loaded in Step 1", but Step 1 only calls
out reading the ACs and `type`. `spec.md` is read whole (so `group` is available),
but the parenthetical is imprecise. Adjust it, or name `group` in Step 1.

## Relates to

spec 030 DD1; `skills/review/SKILL.md` Step 10; `skills/blueprint/SKILL.md` lines 13, 33.
