---
id: 20260803-restore-the-id-boundary-memo-s-cross-pass-warmth-in-the-sweep
num: 218
title: "Restore the id-boundary memo's cross-pass warmth in the sweep"
status: open
priority: medium
labels: [id-coordination, performance]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:29Z
updated: 2026-08-03T05:50:29Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

The registry-integrity spec added an in-run memo on `alloc_valid_token` so the
sweep would stop re-forking the id boundary per record. The emission build's
extraction moved record-side validation into subshells, so the memo no longer
warms across passes: the sweep validates rename sides roughly twice, each time
against a cold cache.

This is a regression against the measured intent of that memoization, not a
newly-discovered inefficiency — which is why it stands on its own rather than
folding into either neighbouring cost issue.

Two neighbours, and closing one must not close another:

- [[20260730-memoize-the-id-validation-boundary-in-the-allocator-read-path]] is
  the memo itself. This issue is about the memo losing effect at a call site.
- [[20260802-cut-the-per-file-frontmatter-cost-the-registry-sweep-pays]] is the
  sweep's dominant cost — about 6.9 s of a ~14 s sweep, in per-file frontmatter
  forks in the seed derivation. Fixing either leaves the other untouched.

## Proposed action

Measure first: count the per-pass forks on the live logs before changing
anything. The cost may be immaterial next to the frontmatter derivation, in
which case the right outcome is to record the double-validation as deliberate
and say why. If it is material, hoist the validation back out of the subshells.

The plan-time lesson this build already produced applies here too: a
performance premise is a hypothesis until it is profiled.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 20a). Not filed alongside that review's other follow-ons.
