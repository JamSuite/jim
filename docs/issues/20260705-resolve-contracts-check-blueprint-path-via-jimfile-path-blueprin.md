---
id: 20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin
num: 62
title: "Harden contracts-check: blueprint-path resolver + self-edge guard + edge tests"
status: open
priority: high
labels: [000-blueprint, drift, verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:47:39Z
updated: 2026-07-05T22:55:35Z
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

## Bundled follow-ups (folded 2026-07-05)

Issues #58, #59, and #61 were folded into this umbrella — all four concerns live
in `cmd_contracts_check` / `contract_ref_check` (`skills/verify/scripts/jimverify.sh`)
and land in one hardening pass:

- [ ] **Blueprint-path resolver** (this issue, high) — resolve each group's
  blueprint via `jimfile.sh path blueprint <group>` instead of hand-deriving
  `$specs_root/$g/000-blueprint/spec.md` (the `blueprint-slot-reserved` fix above).
- [ ] **Self-edge guard** (was #61, low) — add `[[ "$C" == "$P" ]] && continue`
  to the edge-outcome loop, mirroring the existing CROSS-REF self-pair skip.
- [ ] **consumer-ref abstain test** (was #58, medium) — add a `contracts_repo`
  variant whose consumer lacks the declared usage; assert the consumer side emits
  **no** edge record (not `violated`/`failed`).
- [ ] **edge-outcome location-only test** (was #59, medium) — assert the edge
  outcome evidence is `file:line`-only (e.g. `grep -c 'function'` / `'getIdentity'`
  == 0), closing the exfiltration-guard coverage gap `CROSS-REF` already has.
