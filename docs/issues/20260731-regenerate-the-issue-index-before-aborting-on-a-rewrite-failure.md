---
id: 20260731-regenerate-the-issue-index-before-aborting-on-a-rewrite-failure
num: 174
title: "Regenerate the issue index before aborting on a rewrite failure"
status: open
priority: high
labels: [issue, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:33Z
updated: 2026-07-31T12:38:33Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`rewrite_num` now exits non-zero when it replaces nothing. The issue realizer
handles that with `return 1` (`skills/issue/scripts/reconcile.sh:182-186`), which
aborts `apply_pending` and returns before the `index.sh` call at `:229` — even
though earlier files in the batch were already rewritten atomically.

Result: realized ordinals on disk, stale `INDEX.md`, no regeneration attempted.
That is the failure mode the regen-exit-status fix exists to prevent, now
reachable through the door the verified-rewrite change opened.

## Related asymmetry

The spec realizer handles the same non-zero rc differently
(`skills/spec/scripts/reconcile.sh:278-284`: `failed=1; continue`), which leaves a
different residue — the directory is already renamed at that point, so the
identity is omitted from `applied` and therefore from the remap: moved directory,
still-provisional frontmatter, un-swept citations, no ledger row, rc 1.

The two scripts are documented as mirrors and should agree on this path.

## Fix

Regenerate the index before returning on the failure path (or accumulate the
failure and regenerate once at the end, matching the spec side's batch
semantics), and reconcile the two scripts' handling of the rc.

Finding 4 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
