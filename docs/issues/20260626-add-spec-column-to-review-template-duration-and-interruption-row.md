---
id: 20260626-add-spec-column-to-review-template-duration-and-interruption-row
num: 16
title: "Add spec column to review-template duration and interruption rows"
status: open
priority: low
labels: [review, template]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-26T06:43:40Z
updated: 2026-06-26T06:43:40Z
origin: docs/specs/jim/027-review-depth/spec.md
---

## Description

`review-template.md`'s body Metrics table lists
`Stage runs (spec·research·plan·sec·build)` but
`Stage durations (research·plan·sec·build)` and
`Interruptions (research·plan·sec·build)` omit `spec` — even though
`jimledger.sh` now instruments the spec stage and the frontmatter carries
`spec_runs` / `spec_interruptions` / `spec_duration_seconds`.

Add `spec` to both the durations and interruptions rows so the body table
matches the emitted metrics and the frontmatter.

Surfaced during scoping of spec 027 (depth-aware review).
