---
num: 9
id: 20260620-commit-planning-artifacts-before-the-build-phase
title: "Commit planning artifacts before the build phase"
status: open
priority: medium
labels: [workflow, enhancement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-20T11:07:00Z
updated: 2026-06-20T11:07:00Z
origin: conversation
---

## Description

Across the jim SDLC chain (spec → research → sec → plan), the planning artifacts
(`spec.md`, `research.md`, `security.md`, `plan.md`) and any issues filed during the
run accumulate **uncommitted**. Before `/jim:build` runs — which makes its own
TDD / Tidy-First implementation commits — these should be committed so the planning
record lands as a clean commit separate from the implementation diff. Today this is
a manual, easy-to-forget step, and it recurs on every spec.

Make it part of the workflow: e.g. `/jim:plan`'s approval step, or a gate at the
start of `/jim:build`, commits the approved planning artifacts (or prompts to) with
the appropriate `Spec:` / `Issue:` trailers. Decisions to make: the exact home
(end-of-plan vs start-of-build), and whether it auto-commits or prompts (the bare-name
"human-in-the-loop default" convention suggests prompting unless a new `auto_*` knob
opts in).

Surfaced repeatedly during jim SDLC runs; flagged during spec 024 work.
