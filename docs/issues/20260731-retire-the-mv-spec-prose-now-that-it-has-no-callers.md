---
id: 20260731-retire-the-mv-spec-prose-now-that-it-has-no-callers
num: 183
title: "Retire the mv-spec prose now that it has no callers"
status: open
priority: low
labels: [docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:39Z
updated: 2026-07-31T12:39:39Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`mv-spec` has **zero** production callers. `/jim:spec` migrated to `mv-spec-id`
(`skills/spec/SKILL.md:216`), and the partition operations rename spec directories
through `jimledger.sh rename-tracked` / `move-spec-dir`. The only remaining
references are tests, the script's own usage text, and prose.

Four documentation sites still describe it as the live placeholder-rename verb:

- `ARCHITECTURE.md:258` and `:390`
- the `cmd_mv_spec` docstring, `skills/file/scripts/jimfile.sh:367-369`
- a comment in `skills/ledger/scripts/jimledger.sh:811`

The two `ARCHITECTURE.md` sites survived the `/jim:arch` refresh run at the
`sdlc/018` completion gate, which edited both of those sections for other reasons.

## Fix

Correct the four sites to name `mv-spec-id`, and decide whether `mv-spec` itself
should stay as a supported verb (it is tested and correct, just uncalled) or be
retired.

Finding 13 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.
