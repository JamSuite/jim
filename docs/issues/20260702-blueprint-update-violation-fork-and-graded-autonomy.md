---
id: 20260702-blueprint-update-violation-fork-and-graded-autonomy
num: 28
title: "Add violation-vs-fold fork and criticality-graded autonomy to blueprint update"
status: open
priority: medium
labels: [000-blueprint, fold-back]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-02T07:16:19Z
updated: 2026-07-02T07:18:55Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

## Description

## Context

Spec 030's update mode folds unconditionally: it treats the change diff as
fact and updates the blueprint to match. Nothing instructs it to check the
diff *against* the blueprint's current invariant table first, so a change that
violates a recorded invariant is absorbed rather than flagged — and under
`auto_blueprint`, a regression can be silently laundered into the
authoritative intent, eroding the blueprint's authority (the property the
whole initiative rests on). The originating brainstorm called telling "code is
wrong, fix it" apart from "intent was wrong, fold it" the heart of the
fold-back loop; that judgment has no home in the shipped flow. Its planned
mitigation — criticality-graded autonomy — also did not ship: `auto_blueprint`
is binary.

## What

Two prompt-level changes to `/jim:blueprint` update mode, likely one small
spec:

1. **Violation-vs-fold fork.** Before proposing the section-diff, check the
   change against the blueprint's invariants. A violated invariant is never
   silently rewritten — present the divergence with its two resolutions (fix
   the code / fold the intent) and require an explicit choice.
2. **Criticality-graded autonomy.** Under `auto_blueprint`, additive and
   low-criticality edits write unattended; weakening or removing a
   `critical` / `high` invariant always prompts. One criticality vocabulary
   then drives both fold-back autonomy and, later, verification appetite
   ([[20260630-build-the-invariant-verification-engine]]).

Together these make `auto_blueprint` safe enough to actually enable — which
the blueprint's "stays current" promise depends on.

See also [[20260630-wire-the-000-blueprint-fold-back-loop-into-review]].
