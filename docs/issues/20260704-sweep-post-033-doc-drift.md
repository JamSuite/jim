---
id: 20260704-sweep-post-033-doc-drift
num: 36
title: "Sweep post-033 doc drift"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [docs, workflow, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T00:22:57Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/005-context-map/review.md
---

## Description

Surfaced by the 033 post-build review (origin) as a sweep of low-impact
documentation drift. Closed as substantially shipped: the substantive items
are resolved, and the two cosmetic residuals were reviewed and accepted
as-is.

## Resolved

- `WORKFLOW.md` illustrative sections — the architect Agent ↔ Skill example
  now carries `blueprint`, the pm example now lists `spec-check` + `issue`,
  the Agents table lists `/jim:blueprint` on architect's row, and the plugin
  directory tree is current (blueprint/partition/verify plus the read-only
  subagents). Fixed incidentally by the blueprint/partition doc sweeps, plus
  the pm-example correction in this sweep.
- `skills/file/scripts/jimfile.sh` `cmd_path` header comment — now names both
  `debug` and `blueprint` as the KINDS∩KEYS overlaps (was "the only overlap
  is `debug`", stale since spec 033 made `blueprint` both a KIND and a KEY).

## Reviewed, accepted as-is (won't fix)

- `skills/blueprint/SKILL.md` cites "methodology § Scrub". `§ Scrub` is the
  established short-form for the `map-methodology.md` section — it matches the
  file's sibling citations (`§ Blast radius`, `§ Update flow`, `§ Graph
  health`), and the partition skill bakes the same form into its own heading.
  The section is a scrub *reminder*, not PII-specific: "scrub" spans secrets,
  internal names, and attack vectors, of which PII is only one slice (PII is a
  distinct `/jim:sec` LINDDUN concern). Correct as written.
- The map banner tail ("…preserve the partition's coherence.") differs from
  ARCHITECTURE.md's ("…preserve consistency."). Each names the property its
  own doc most needs protected — a deliberate, doc-specific choice, not drift.

The original "`map-methodology.md` is the only `references/` file with a
literal `${CLAUDE_PLUGIN_ROOT}`" bullet was dropped earlier in the sweep:
three references files now carry it, and it is correct usage in skill content.

## Why low

No behavioral impact — comment/illustration drift only. Review findings
2, 4, 5 of [[20260703-build-intelligence-for-context-aware-spec-group-definition]]'s
build review.
