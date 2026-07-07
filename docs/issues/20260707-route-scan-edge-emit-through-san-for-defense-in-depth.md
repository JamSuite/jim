---
id: 20260707-route-scan-edge-emit-through-san-for-defense-in-depth
num: 65
title: "route scan EDGE emit through san() for defense-in-depth"
status: open
priority: low
labels: [partition, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-07T11:03:53Z
updated: 2026-07-07T11:03:53Z
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
