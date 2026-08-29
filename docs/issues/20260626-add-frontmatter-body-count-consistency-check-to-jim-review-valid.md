---
id: 20260626-add-frontmatter-body-count-consistency-check-to-jim-review-valid
num: 17
title: "Add frontmatter-body count consistency check to /jim:review validation"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-26T06:43:41Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/sdlc/015-review-depth/spec.md
---

## Description

`plan_deviations` and `security_regressions` are reviewer-judged counts in
`review.md` frontmatter, but nothing cross-checks them against the
Findings / Alignment body items, so the mineable frontmatter can silently
diverge from the narrative.

Add a `/jim:review` validation-checklist line — "frontmatter counts match the
body items" — to keep the mined data honest.

Surfaced during scoping of spec 027 (depth-aware review).
