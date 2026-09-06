---
id: 20260723-add-deps-command-absence-build-gate-test
num: 91
title: "Add deps_command absence build-gate test"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition, meta-test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T19:29:53Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/023-partition-ref-sweep/plan.md
---

## Discovery

ARCHITECTURE.md's "Partition extraction core" description asserts a mechanical
enforcement that does not exist:

> The script **never** resolves or executes a `deps_command_<name>` value —
> `jimconf.sh` resolves the family, the model runs each command via Bash — a
> build-gate grep enforces the family name's absence from the script.

No such build-gate grep exists. `grep -rn deps_command` across `tests/`,
`skills/meta-test/`, `.github/`, and the nix build finds only config-resolution
cases in `tests/jimconf.sh` and fixture data in `tests/jimpartition.sh` —
nothing asserts the `deps_command` family name is absent from
`skills/partition/scripts/jimpartition.sh`'s executable body.

The invariant is security-relevant (the script must never resolve or execute an
untrusted `deps_command` value — that is `jimconf.sh`'s job, with the model
running each command via Bash), and jim's doctrine prefers mechanical
enforcement over discipline where a deterministic path exists.

## Suggested action

Either:

1. Add a build-gate test (a `case_` in `tests/jimpartition.sh` or a meta-test)
   asserting the `deps_command` family name is absent from the script's
   executable body — mechanically enforcing the claimed invariant, mirroring the
   prose-pin pattern; or
2. Soften the ARCHITECTURE.md claim to describe the boundary as a design
   discipline rather than a build-gate-enforced one.

Option 1 is the mechanical-floor-consistent fix.

## Origin

Surfaced while building the partition ref-sweep fix: the prose-pin test case was
justified as a per-script-charter stretch precisely because this claimed
build-gate-grep precedent turned out not to exist.
