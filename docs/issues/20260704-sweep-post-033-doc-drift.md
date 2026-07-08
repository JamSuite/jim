---
id: 20260704-sweep-post-033-doc-drift
num: 36
title: "Sweep post-033 doc drift"
status: open
priority: low
labels: [docs, workflow, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T00:22:57Z
updated: 2026-07-08T19:13:35Z
origin: docs/specs/jim/033-context-map/review.md
---

## Description

Surfaced by the 033 post-build review (origin) as a sweep of low-impact
documentation drift. The substantive items are now resolved; only cosmetic
residual remains.

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

## Remaining (cosmetic, optional)

- `skills/blueprint/SKILL.md` cites "methodology § Scrub"; the actual heading
  is "Scrub reminder (canonical text)" in `map-methodology.md`. `§ Scrub`
  reads as a fair shorthand — align only if literal exactness is wanted.
- The map banner tail ("…preserve the partition's coherence.") differs from
  ARCHITECTURE.md's ("…preserve consistency."). Plausibly intentional across
  two distinct documents — align only if a single house phrasing is wanted.

The original "`map-methodology.md` is the only `references/` file with a
literal `${CLAUDE_PLUGIN_ROOT}`" bullet is dropped: three references files now
carry it, and it is correct usage in skill-content (where the variable
substitutes), not a defect.

## Why low

No behavioral impact — comment/illustration drift only. Review findings
2, 4, 5 of [[20260703-build-intelligence-for-context-aware-spec-group-definition]]'s
build review.
