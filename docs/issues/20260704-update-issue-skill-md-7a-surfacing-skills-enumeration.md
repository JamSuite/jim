---
id: 20260704-update-issue-skill-md-7a-surfacing-skills-enumeration
num: 45
title: "Update issue SKILL.md 7a surfacing-skills enumeration"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T11:07:13Z
updated: 2026-08-12T19:49:07Z
origin: docs/specs/blueprint/006-contract-graph/review.md
---

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

## Resolution (2026-08-12)

Fixed in `e7982b7`, taking this issue's own recommendation — **drop the fixed
count** — rather than correcting it to a new number.

Closed alongside `#317`, which filed three *other* stale rosters. Working them
together is what showed both were the same defect: `#317` treated § 7a's "ten
surfacing skills" as the canonical roster the other three should be corrected
*to*, but that roster was itself short by one. The consumer set derived
mechanically from the emitter grant is eleven — the ten plus `/jim:blueprint`,
exactly the surface this issue named a month earlier.

§ 7a now states the roster as a property with an illustrative list and no
count: a consumer accrues by gaining the `new.sh` grant. The auto-file rule
likewise binds "those that read `auto_issue_file`" rather than "the nine". The
same de-counting was applied to `new.sh`'s own header ("the seven surfacing
skills") and to § 7's untrusted-content roster, which had listed eight.

`case_docsurfaces_candidate_batch_roster_matches_the_grant` is what keeps it
true: it derives the consumer set from `grep -l 'scripts/new\.sh \*'` over every
`SKILL.md`, requires § 7a to name each member, and additionally fails if a fixed
count reappears in the roster prose. That is the mechanical answer to "stays
accurate as consumers accrue" — the next consumer to gain the grant fails this
case rather than silently widening the gap.
