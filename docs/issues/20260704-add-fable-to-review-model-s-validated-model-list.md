---
id: 20260704-add-fable-to-review-model-s-validated-model-list
num: 46
title: "Add fable to review_model's validated model list"
status: closed
priority: low
labels: [review, config]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T22:05:36Z
updated: 2026-07-09T07:06:49Z
origin: docs/specs/jim/035-verify-engine/plan.md
---

## Description

## Context

Surfaced while planning spec 035 (`/jim:verify`): the new `verify_model`
knob validates against `inherit|sonnet|opus|haiku|fable`, but the
`review_model` mechanism it mirrors (spec 027) predates `fable` — Claude
Code now supports Anthropic's newest model tier under that name.

## What

Add `fable` to `review_model`'s validated model list so review
investigators can run on it:

- `skills/review/SKILL.md` — the Step 4a validation ("validate
  `review_model` against `inherit` / `sonnet` / `opus` / `haiku` — treat
  anything else as `inherit`") gains `fable`.
- `jimconf.toml.example` — the `review_model` valid-values comment gains
  `fable`.
- Keep the `review_model` and `verify_model` (spec 035) enums aligned —
  they implement the same per-spawn Agent `model` mechanism.

## Resolution (2026-07-09)

Shipped. `fable` added to `review_model`'s validated list; both enums
re-ordered to the canonical `inherit | haiku | sonnet | opus | fable`
(size/cost ascending, `fable` last) so `review_model` and `verify_model` read
identically. Edits: `skills/review/SKILL.md` (Step 4a validation + the 4c
fan-out tier list), `skills/verify/SKILL.md` (the two `verify_model` tier
lists), and both `jimconf.toml.example` valid-values comments. Validation is
LLM-side in the SKILL prose — `jimconf.sh` only returns the `inherit` default,
so no script change was needed.
