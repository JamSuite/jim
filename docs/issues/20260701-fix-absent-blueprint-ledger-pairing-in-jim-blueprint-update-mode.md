---
id: 20260701-fix-absent-blueprint-ledger-pairing-in-jim-blueprint-update-mode
num: 24
title: "Fix absent-blueprint ledger pairing in /jim:blueprint update mode"
status: open
priority: medium
labels: [blueprint, ledger, 000-blueprint]
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

Surfaced by the spec 030 post-build review (`docs/specs/jim/030-blueprint-update/review.md`, Finding 1) — caught by an independent review investigator.

## The bug

In `skills/blueprint/SKILL.md` Update mode, U1 records `blueprint started` on the
ledger **unconditionally, before** the U2 absent-blueprint check. On the
first-time path (the group has no `000-blueprint` yet), U2 routes a successful
generate to Step 5 — not U4 — so `blueprint finished` is never recorded and
`commit-blueprint` never runs.

`phase_event_metrics` (`skills/review/scripts/jimledger.sh`) computes
`interruptions = started - finished`, so a legitimately-completed first generate
surfaces as `blueprint_interruptions=1` — a completed run mis-recorded as
interrupted. It also muddies the `require_blueprint` "an interrupted update holds
the gate" signal.

## Proposed fix

In U2, record `blueprint finished` (and stop) after the Step-5 generate write, OR
defer the `blueprint started` event until **after** the absence check.

## Relates to

spec 030 AC8/AC10, plan DD4; `skills/blueprint/SKILL.md` U1-U2.
