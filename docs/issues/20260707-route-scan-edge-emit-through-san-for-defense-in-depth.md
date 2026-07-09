---
id: 20260707-route-scan-edge-emit-through-san-for-defense-in-depth
num: 65
title: "route scan EDGE emit through san() for defense-in-depth"
status: closed
priority: low
labels: [partition, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T11:03:53Z
updated: 2026-07-09T10:24:34Z
origin: docs/specs/jim/038-partition-migration/review.md
---

## Description

The `scan` verb's EDGE lines are emitted directly by the `scan_*` helpers via
`printf` (`skills/partition/scripts/jimpartition.sh:410,467,540,595,749`), not
through the `san()` control-strip/length-cap that the ingest, coverage, and
aggregate verbs apply to their path fields.

This is **not exploitable as shipped**: scan endpoints are tracked-by-construction
(the source comes from `git ls-files`, the target is verified `in TRACKED` /
`in HASDIR`), and `git ls-files` C-escapes control characters (tab, newline,
0x01–0x1F) regardless of `core.quotePath` — so no raw control byte can reach the
output to shift TSV columns, and a quoted filename fails `classify_ext` and never
becomes a scan candidate.

It is a defense-in-depth / consistency gap: `scan` relies on git's escaping
guarantee rather than the explicit `san()` belt the other three verbs use, so a
future refactor that piped non-git data through scan's emit path would lack the
guard.

**Suggestion:** route scan's EDGE fields through `san()` too, or add a comment on
the emit path pinning the git-escaping guarantee it depends on.

Relates to AC #2/#17 and the "fields sanitized" Interface Contract note. Surfaced
by the spec 038 post-build review (finding 1).

## Resolution (2026-07-09)

Took the **wrap** fork, not the comment fork. The deciding factor: the script
header (`jimpartition.sh:24`) states a **blanket, unconditional** contract — "All
output is TAB-separated and field-sanitized (control-stripped, length-capped)" —
and scan's EDGE emit was the sole output that didn't pass the belt. Wrapping makes
that contract literally true everywhere; the comment fork would have left it true
only via git's C-escaping and required *also* softening the header to stay honest.

Grounding shaped the implementation:

- **`san()` is an awk function**, not a shared shell helper — it's inlined in
  three separate awk programs (coverage `:138`, ingest `:201`, aggregate `:780`).
  So "route through `san()`" meant a fourth inline copy, applied in an awk pass.
- **Single choke point.** All five languages' EDGE lines funnel through one
  `printf … | grep -v '^$' | sort -u` emit (`cmd_scan`, formerly `:361`). Inserted
  the awk `san()` pass there — one place covers every scanner — sanitizing only
  the two endpoint path fields (`$2`/`$3`), leaving the `EDGE`/`imports` literals
  untouched. That matches the codebase's actual granularity: it sans path-bearing
  fields, not fixed literals or trusted group names (e.g. GEDGE group names at
  `:804` are not sanned).

Verified: control bytes stripped and >512 paths capped on a crafted EDGE line
(standalone awk check); the full partition suite stays green at 35 (the belt is
transparent to legitimate git-derived paths — a no-op for already control-free
input). No new test: the belt is unreachable via the normal input path (git
ls-files C-escapes control bytes before they can reach the emit), so its value is
local-obviousness + refactor-safety, not a testable behavior change — the
regression suite confirming transparency is the right coverage.

Honest cost noted: this adds a **fourth** inline copy of the `san()` awk function.
Pre-existing DRY smell (inherent to awk's per-program function scoping), not
structurally worsened — a shared-helper refactor would be its own change.
