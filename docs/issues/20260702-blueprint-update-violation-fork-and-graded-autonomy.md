---
id: 20260702-blueprint-update-violation-fork-and-graded-autonomy
num: 28
title: "Add violation-vs-fold fork and criticality-graded autonomy to blueprint update"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, fold-back]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-02T07:16:19Z
updated: 2026-07-25T07:49:14Z
origin: docs/brainstorms/20260630-000-current-spec.md
---

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

## Resolution

Shipped as spec `blueprint/003` (Blueprint update guard), whose `origin` is this
issue. Both halves landed: the violation-vs-fold fork (spec ACs #1–3) and
criticality-graded `auto_blueprint` autonomy (spec AC #4). The build reviewed
`aligned` with all 8 ACs met over commits `09304e0..e694517`. Residual
hardening from that review was spun out separately (#30, #31).
