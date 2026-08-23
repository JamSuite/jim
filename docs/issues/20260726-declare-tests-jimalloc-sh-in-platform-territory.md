---
id: 20260726-declare-tests-jimalloc-sh-in-platform-territory
num: 120
title: "Declare tests/jimalloc.sh in platform territory"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T22:39:36Z
updated: 2026-08-02T06:52:07Z
origin: docs/specs/platform/007-id-coordination-allocator/review.md
---

## Description

Finding 4 from the platform/007 review (living-intent sensor — in-change
territory violation).

The build added `tests/jimalloc.sh`, which falls outside platform's declared
territory in BLUEPRINT.md because that territory cell enumerates test files
individually (tests/jimconf.sh, tests/jimfile.sh, tests/jimledger.sh,
tests/metatest.sh) and the new test file was not added. The platform group's
other new code (skills/file/scripts/jimalloc.sh) is covered by the `skills/file`
directory entry; only the test file is a stray.

This directly parallels open issue #110 (declare tests/scripthygiene.sh in
platform territory) — both are the same class of "the territory cell is missing
a test file". A map reconcile / partition update that refreshes platform's
territory would resolve both.

Action: add `tests/jimalloc.sh` to platform's territory in BLUEPRINT.md (a map
edit, not a code change), ideally folded into #110's fix.

Location: BLUEPRINT.md (platform territory row).

## Resolution (2026-08-02)

Already satisfied: `tests/jimalloc.sh` is declared in platform's territory
(`BLUEPRINT.md:85`) — the map was repaired through the blueprint surface
during the C′-fix build's territory pass. Closed on verification, no change
owed. The sibling class this issue pointed at (#110,
`tests/scripthygiene.sh`) remains open and travels with the
[[20260801-two-test-files-are-claimed-by-no-group-s-territory]] map pass.
