---
id: 20260726-declare-tests-scripthygiene-sh-in-platform-territory
num: 110
title: "Declare tests/scripthygiene.sh in platform territory"
status: open
priority: low
labels: [partition, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T08:40:11Z
updated: 2026-07-26T08:40:11Z
origin: docs/specs/platform/006-script-preamble-conformance/plan.md
---

## Description

## Description

`tests/scripthygiene.sh` was added by the platform script-preamble conformance work (the corpus-wide preamble hygiene sweep) but is not listed in any group's declared territory in `BLUEPRINT.md`. Platform's territory enumerates specific test files (`tests/jimconf.sh`, `tests/jimfile.sh`, `tests/jimledger.sh`, `tests/metatest.sh`); the new sweep belongs to platform (it owns the meta-test framework and holds the check for project-wide script rules) but is not declared there.

Group-tier `/jim:blueprint platform` — the generate that restored the invariant — updates the group's `000-blueprint`, not the project-tier map's territory list, so the file stays unattributed until a project-tier map update runs.

Proposed action: run project-tier `/jim:blueprint` to add `tests/scripthygiene.sh` to platform's territory in `BLUEPRINT.md`, so a future `/jim:verify` file-level territory check does not flag it as an unattributed tracked file. While there, consider also declaring the other currently-unlisted textual-invariant tests (`tests/gatepresentation.sh`, `tests/presenttense.sh`, `tests/provenance.sh`) if they are similarly undeclared.
