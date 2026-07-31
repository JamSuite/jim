---
id: 20260730-spec-reconcile-scan-and-id-rewrite-anchor-to-different-regions
num: 158
title: "Spec reconcile scan and id rewrite anchor to different regions"
status: closed
priority: medium
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:09Z
updated: 2026-07-31T12:40:00Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

In `skills/spec/scripts/reconcile.sh`, detection and rewrite are anchored to
different regions of the file:

- `field_value` (the scan) anchors on the whole file's **first `^id:` line**,
  anywhere in the file;
- `rewrite_id` (the write) anchors **inside the first `---` block**.

So a `spec.md` with no frontmatter at all — or with CRLF `---\r` — whose *body*
carries a line `id: P-<date>-<slug>` matching its directory passes the scan, gets
renamed, and then the awk rewrite does nothing. The result is a realized
directory holding a file that still claims the provisional identity, at
**exit 0**: rewrite success is never verified.

The mirror case also holds: a file with no frontmatter but a body `---` sets the
block counter mid-body, so a later body `id:` line *is* rewritten.

## Fix

- Require a real **leading** frontmatter block during the scan, so detection and
  rewrite cover the same region by construction.
- Verify the rewrite actually changed the field before reporting success.

## Related

This is the same class as
[[20260728-reconcile-sh-provisional-detection-not-fence-bounded]], which records
the identical detection/rewrite region mismatch in the **issue-side**
`reconcile.sh` (`scan_pending` vs `rewrite_num`). That one is filed and still
open; this is the same mistake reproduced in the new spec-side script. Worth
fixing together — and worth asking whether the shared shape belongs in one
helper rather than two scripts that each get it wrong independently.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
