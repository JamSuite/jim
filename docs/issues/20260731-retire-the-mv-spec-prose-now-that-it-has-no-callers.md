---
id: 20260731-retire-the-mv-spec-prose-now-that-it-has-no-callers
num: 183
title: "Retire the mv-spec prose now that it has no callers"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:39:39Z
updated: 2026-07-31T23:45:13Z
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

## Resolution (2026-07-31) — retired, not just re-described

Closed by the C′-fix build. The decision the issue posed was taken as **retire**,
and the prose sites were corrected as part of removing the verb rather than
around it.

**The no-callers claim was confirmed exhaustively before deleting anything.**
`cmd_mv_spec` had exactly one call site — its own dispatch entry. No internal
caller, no skill body, no agent, no sibling script; all three CLIs dispatch
through a literal `case`, so no constructed-verb path could have hidden one, and
non-ASCII hyphen spellings were checked too. Only its own fixtures exercised it.

**`mv-spec-id` subsumes it.** It takes its source by explicit basename rather
than resolving it by ordinal glob, which is what made the ambiguous-match and
missing-source failure modes `mv-spec` carried its own guards for.

Removed: the verb, its dispatch, its CLI summary and `usage()` entries, and ten
fixtures (suite 978 → 968). Corrected at their own surfaces rather than by hand:

- the `platform` blueprint's Provides face, through `/jim:blueprint platform
  --since` — which also picked up `mv-spec-id` and `spec-ordinal-holder`, absent
  from that enumeration since they shipped;
- `ARCHITECTURE.md`'s three sites, through `/jim:arch`.

**One thing worth keeping.** The retirement forced a Provides-face edit, so the
grounding run's **breaking** detector was exactly the check that would fire if a
consumer had depended on the verb. It reported zero — independent corroboration
of the caller sweep, from a mechanism that had no knowledge of it.
