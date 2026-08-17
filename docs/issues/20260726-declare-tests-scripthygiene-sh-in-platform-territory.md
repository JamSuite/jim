---
id: 20260726-declare-tests-scripthygiene-sh-in-platform-territory
num: 110
title: "Declare tests/scripthygiene.sh in platform territory"
status: closed
priority: low
labels: [partition, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T08:40:11Z
updated: 2026-08-02T07:23:52Z
origin: docs/specs/platform/006-script-preamble-conformance/plan.md
---

## Description

## Description

`tests/scripthygiene.sh` was added by the platform script-preamble conformance work (the corpus-wide preamble hygiene sweep) but is not listed in any group's declared territory in `BLUEPRINT.md`. Platform's territory enumerates specific test files (`tests/jimconf.sh`, `tests/jimfile.sh`, `tests/jimledger.sh`, `tests/metatest.sh`); the new sweep belongs to platform (it owns the meta-test framework and holds the check for project-wide script rules) but is not declared there.

Group-tier `/jim:blueprint platform` — the generate that restored the invariant — updates the group's `000-blueprint`, not the project-tier map's territory list, so the file stays unattributed until a project-tier map update runs.

Proposed action: run project-tier `/jim:blueprint` to add `tests/scripthygiene.sh` to platform's territory in `BLUEPRINT.md`, so a future `/jim:verify` file-level territory check does not flag it as an unattributed tracked file. While there, consider also declaring the other currently-unlisted textual-invariant tests (`tests/gatepresentation.sh`, `tests/presenttense.sh`, `tests/provenance.sh`) if they are similarly undeclared.

## Resolution (2026-08-02)

Done as proposed, through the project-tier map update (`e2a5635`):
`tests/scripthygiene.sh` is declared in platform's territory, decided
deliberately over the recorded-exception alternative — the file asserts a
project-wide script rule, and platform already holds that pattern (the
`no-third-party-deps` invariant binds every group while platform holds the
check); the platform blueprint's Structure section already names the file, so
map and group blueprint agree. The "while there" trio was already declared
under the blueprint group's territory. The sibling gap
([[20260801-two-test-files-are-claimed-by-no-group-s-territory]]) closed in
the same pass.
