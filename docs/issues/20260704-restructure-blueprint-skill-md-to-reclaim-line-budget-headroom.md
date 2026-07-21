---
id: 20260704-restructure-blueprint-skill-md-to-reclaim-line-budget-headroom
num: 43
title: "Restructure blueprint SKILL.md to reclaim line-budget headroom"
status: open
priority: medium
labels: [000-blueprint, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T09:23:23Z
updated: 2026-07-21T21:22:29Z
origin: docs/specs/jim/034-contract-graph/plan.md
---

## Update (2026-07-21) — spec 047 hit it again; gatherer.md now over budget

The `/jim:partition split` build (spec 047) is another instance of the ceiling
forcing an unplanned extraction mid-build: blueprint SKILL.md was at
**498/500**, so the new `--split` arm could only land by extracting **both**
migrate arms' protocols to a new `references/migrate-arms.md` — and the body is
**back at 500/500**. Still the targeted-lever pattern, not the durable
§ Update mode / § Project tier → references restructure this issue asks for.

`agents/gatherer.md` worsened too: the split dispatch-role paragraph took it
from ~798 to **905 words**, past its own progressive-disclosure budget. The
`skill-budget` invariant that would flag it is `registry:skill-line-budget` and
currently **unconfigured**, so nothing caught it during the 047 review. Both
progressive-disclosure surfaces this issue names are now at/over the ceiling —
the durable restructure is overdue.

## Reopened (2026-07-11) — the fix did not hold

Spec 036's extraction restored ~45 lines of slack, but that headroom is
gone again. The `--retire` superseded-set naming work refilled the body to
**500/500**, and the spec-043 `/jim:partition rename` build hit the ceiling
mid-task — exactly the "hitting it mid-spec forces an unplanned restructure
inside an unrelated build" scenario the *Why* below warns about.

That build spent the **first** lever this issue named ("consolidate the
validation checklist"): the Update-mode / project-tier / reconcile bullets
were merged by theme, 20 → 9, to fit the new `--rename` arm under the
ceiling (all check clauses preserved). The **second, durable** lever
remains undone and is now the whole ask:

- Push the § Update mode / § Project tier (and any remaining fork) prose
  into the existing references (`map-methodology.md`,
  `reconcile-methodology.md`, `fork-grounding.md`), keeping only dispatch +
  process skeletons in the body — the 033/034/036 precedent.

`agents/gatherer.md` shows the same symptom at its own tier (**798/800**
words after the spec-043 charter line), so the restructure should reclaim
headroom in both progressive-disclosure surfaces. Priority raised low →
medium: the ceiling now actively blocks feature work on contact.

## Prior resolution (spec 036 — superseded by the reopen above)

Closed by spec 036 (Task 5). The blueprint SKILL.md's violation-fork
detail (U3a presentation, U3b issue offer) was extracted to
`skills/blueprint/references/fork-grounding.md`, taking the body from
497 to 440 lines; the subsequent 036 behavioral wiring left it at 455,
with ~45 lines of headroom under the 500-line ceiling.

## Description

## Context

Spec 034's reconcile arm brought `skills/blueprint/SKILL.md` to 497/500
lines (ARCHITECTURE.md's progressive-disclosure ceiling). The 034 plan's
pre-identified fallback was already applied — per-mode commit choreography
lives in `references/reconcile-methodology.md` — so the next
blueprint-touching spec has ~3 lines of slack and will bust the budget on
contact.

## What

Restructure the SKILL.md body to reclaim headroom before the next feature
needs it. Candidate levers:

- Push more of the § Update mode / § Project tier prose into the existing
  references (`map-methodology.md`, `reconcile-methodology.md`), keeping
  dispatch + process skeletons in the body (the 033/034 precedent).
- Consolidate the validation checklist's per-mode items.

## Why

The 500-line ceiling is a locked ARCHITECTURE.md constraint; hitting it
mid-spec forces an unplanned restructure inside an unrelated build.
