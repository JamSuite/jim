---
id: 20260707-extend-the-gate-presentation-rule-beyond-the-blueprint-surface
num: 67
title: "Extend the gate-presentation rule beyond the blueprint surface"
status: open
priority: medium
labels: [gate-presentation, follow-up]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T20:55:43Z
updated: 2026-07-07T20:55:43Z
origin: docs/specs/jim/040-blueprint-gate-presentation/spec.md
---

## Description

The same "present X and wait for approval" exposure that spec 040 fixes on the
blueprint surface exists elsewhere in jim:

- The SDLC-stage gates — `/jim:spec`, `/jim:plan`, `/jim:review`, `/jim:build`,
  `/jim:debug`, `/jim:research`, `/jim:sec` — each say "present X and wait"
  without a defined format.
- The § 7a issue-edit inline flow ("present the full drafted issue inline")
  across the surfacing skills, which can exceed the render threshold for a long
  issue body.

Once spec 040 lands its canonical gate-presentation rule in a shared reference
doc, fold these remaining gate sites onto the same rule (reference by path,
same as the blueprint surface).

Explicitly deferred from spec 040 — see its Out of Scope section.
