---
id: 20260704-update-issue-skill-md-7a-surfacing-skills-enumeration
num: 45
title: "Update issue SKILL.md 7a surfacing-skills enumeration"
status: open
priority: low
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T11:07:13Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/006-contract-graph/review.md
---

## Description

## Context

`skills/issue/SKILL.md` § 7a (Candidate-batch contract) enumerates "the
seven surfacing skills" as the contract's consumers. Since then the
blueprint surface also files through it: the spec 031 divergence-issue
offer and the spec 034 reconcile finding-issue batch both render per § 7a
and emit through `new.sh`. The canonical list undercounts its consumers.

Surfaced by the 034 post-build review (review.md Finding 2).

## What

Reword § 7a's enumeration so it stays accurate as consumers accrue —
either include the blueprint surfaces explicitly or drop the fixed count
("the surfacing skills" / "every skill that files through this contract").
Check the seven skills' own restatement lines for the same fixed-count
phrasing while there.

## Why

§ 7a is the single-sourced contract the restatements point at; a stale
consumer list in the canonical text is exactly the drift the
single-sourcing was meant to prevent.
