---
id: 20260808-tests-place-sh-sits-outside-every-declared-territory
num: 296
title: "tests/place.sh sits outside every declared territory"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [blueprint, territory]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:40:09Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

`tests/place.sh` — 1400 lines, the `issue` group's largest test file — is not
inside any group's declared territory in `BLUEPRINT.md`.

## Evidence

`BLUEPRINT.md:70` declares the `issue` territory as `skills/issue`,
`agents/issue-analyst.md`, `tests/issues.sh`.

Every other group enumerates its test files individually: `sdlc` names
`tests/specreconcile.sh`, `blueprint` names five, `platform` names eight.
Counting across the repo, 15 of 16 `tests/*.sh` files are claimed by some group
and `tests/place.sh` is the **only** unclaimed one — so this is an omission, not
a convention difference.

The group's own blueprint already names it twice
(`docs/specs/issue/000-blueprint/spec.md:79`, `:92`), so the two documents
disagree.

## Consequence

With `group_territory = "declared-paths"`, a change to this file maps to no
group. It is therefore invisible to blast-radius attribution and to
`/jim:verify`'s group scoping, and it counts toward the partition-health
`uncovered` signal.

It also showed up as the single stray in this review's territory-conformance
attribution, against ~796 files correctly bucketed as other groups' territory or
scaffolding.

## Proposed action

Add `tests/place.sh` to the `issue` group's territory in `BLUEPRINT.md`, through
the blueprint surface rather than by hand.

## Resolution (2026-08-11)

Fixed in `a2e3490`. `tests/place.sh` is inside the `issue` group's declared
territory in the project map, written through the blueprint surface. Confirmed
mechanically: `tests/` no longer appears in the health verb's `UNCOVERED_DIR`
output at all.
