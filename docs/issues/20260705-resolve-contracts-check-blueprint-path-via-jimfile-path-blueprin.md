---
id: 20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin
num: 62
title: "Resolve contracts-check blueprint path via jimfile path blueprint"
status: open
priority: high
labels: [000-blueprint, drift, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:47:39Z
updated: 2026-07-05T22:47:39Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

The spec 037 post-build living-intent sensor flagged an **in-change** violation
of jim's `blueprint-slot-reserved` invariant:

> The `000-blueprint` slot … is resolved only via `jimfile.sh path blueprint
> <group>`.

`cmd_contracts_check` (`skills/verify/scripts/jimverify.sh:778`, `:816`) derives
the group blueprint path by hand — `$specs_root/$g/000-blueprint/spec.md` — for
each mapped group, duplicating the `000-blueprint` slot convention in a second
place. The pre-037 `cmd_check` respects the invariant (it takes `<blueprint-dir>`
as a skill-resolved argument); the new cross-group verb introduced a path that
hardcodes the convention.

**Resolution: fix the code** (the invariant stands — the derivation should route
through the single resolver).

**Proposed fix:** in `cmd_contracts_check`, resolve each group's blueprint via
`jimfile.sh path blueprint <group>` (the script already shells out to `jimfile.sh`
for `valid-relpath`, so the per-group call is consistent) rather than composing
`$specs_root/$g/000-blueprint/spec.md` directly. This keeps the slot convention
in one place, so a future change to the slot name or layout is picked up
automatically.

Surfaced by the spec 037 post-build review's living-intent sensor
(`docs/specs/jim/037-verify-contracts/review.md` → Living intent) and forked at
the blueprint update.

resolved: fix the code
