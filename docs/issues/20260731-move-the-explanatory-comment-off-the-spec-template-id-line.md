---
id: 20260731-move-the-explanatory-comment-off-the-spec-template-id-line
num: 179
title: "Move the explanatory comment off the spec template id line"
status: open
priority: medium
labels: [spec, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:09Z
updated: 2026-07-31T12:39:09Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`skills/spec/assets/spec-template.md:5` now ships as:

    id: "{id}"                        # the bound identity: a 3-digit ordinal, or a P-{date}-{slug} token

An author who fills the value but leaves the trailing comment produces a
frontmatter `id` that does not equal the directory basename. `field_value` returns
the comment along with the value, the corroboration check fails, and the spec is
silently treated as **not pending** — a warning and a skip in
`skills/spec/scripts/reconcile.sh:151`.

Not a regression: the previous whole-file parser behaved identically on that
input. But the comment was added by the coordinated-identity remediation, so the
shipped template is now one editing slip from the trap it did not previously
invite. `skills/plan/assets/plan-template.md` carries the same shape.

## Fix

Move the explanatory text out of the value line — a comment on its own line above
the field, or into the template's prose — so a left-in comment cannot merge into
the parsed value.

Finding 9 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
