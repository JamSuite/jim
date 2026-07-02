---
id: 20260702-tighten-update-guard-wording-and-checklist-gates
num: 30
title: "Tighten update-guard wording and checklist gates"
status: open
priority: low
labels: [000-blueprint, fold-back]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-02T09:30:15Z
updated: 2026-07-02T09:30:15Z
origin: docs/specs/jim/031-blueprint-update-guard/review.md
---

## Description

## Context

Spec 031's post-build review verified all ACs satisfied (verdict: aligned)
but surfaced three low-severity prompt-hardening gaps in
`skills/blueprint/SKILL.md` — review findings 1–3.

## What

Three one-line tightenings:

1. **Explicit resolution line in the divergence issue.** AC #3 lists "the
   chosen resolution" among the issue's recorded content; U3b's body spec
   names only the invariant and the change evidence, leaving the resolution
   implicit in the issue's framing. Add it to the body content list (e.g.
   `resolved: fix the code`).
2. **Checklist row for the per-issue confirmation.** U3b mandates "the
   developer confirms per issue — never file unattended," but no validation
   checklist row gates it, and the existing approval row ("Nothing was
   written without the developer's approval unless `auto_blueprint` is
   true") could be misread as permitting unattended filing under auto mode —
   scope that row to blueprint writes.
3. **Negative gate for the unanswered fork.** The checklist's outcome-kv row
   frames the requirement positively; extend it with the negative case — an
   unanswered fork records no `finished` and commits nothing.
