---
id: 20260626-add-frontmatter-body-count-consistency-check-to-jim-review-valid
num: 17
title: "Add frontmatter-body count consistency check to /jim:review validation"
status: closed
priority: low
labels: [review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-26T06:43:41Z
updated: 2026-06-27T05:04:33Z
origin: docs/specs/jim/027-review-depth/spec.md
---

## Description

`plan_deviations` and `security_regressions` are reviewer-judged counts in
`review.md` frontmatter, but nothing cross-checks them against the
Findings / Alignment body items, so the mineable frontmatter can silently
diverge from the narrative.

Add a `/jim:review` validation-checklist line — "frontmatter counts match the
body items" — to keep the mined data honest.

Surfaced during scoping of spec 027 (depth-aware review).
