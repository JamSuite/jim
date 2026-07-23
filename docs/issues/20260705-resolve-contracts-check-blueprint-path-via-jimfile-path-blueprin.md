---
id: 20260705-resolve-contracts-check-blueprint-path-via-jimfile-path-blueprin
num: 62
title: "Harden contracts-check: blueprint-path resolver + self-edge guard + edge tests"
status: closed
priority: high
labels: [000-blueprint, drift, verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:47:39Z
updated: 2026-07-23T06:15:05Z
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

Issues #58, #59, and #61 were folded into this umbrella, plus the self-loop face
of #64 (2026-07-09). The concerns cluster in `cmd_contracts_check` /
`contract_ref_check` — and, once the self-edge guard's layer is decided, reach
the shared `cmd_edges` root and `cmd_health` (`skills/verify/scripts/jimverify.sh`)
— landing in one hardening pass:

- [x] **Blueprint-path resolver** (this issue, high) — resolve each group's
  blueprint via `jimfile.sh path blueprint <group>` instead of hand-deriving
  `$specs_root/$g/000-blueprint/spec.md` (the `blueprint-slot-reserved` fix above).
- [x] **Self-edge guard** (was #61, low) — skip self-pairs (`consumer ==
  provider`) so a self-edge never reads as a cross-group contract, mirroring the
  existing CROSS-REF self-pair skip. **Layer decision (surfaced by folding #64's
  health face, below):** placing the guard at the shared `cmd_edges` root — not
  only in `cmd_contracts_check`'s edge-outcome loop — makes both the outcome loop
  and `cmd_health` inherit it, and may make a per-loop
  `[[ "$C" == "$P" ]] && continue` redundant. If dropped at `cmd_edges`, surface
  it as a `HYGIENE` row, never a silent vanish (verify's name-every-degradation
  doctrine).
- [x] **Health self-loop semantics** (from #64, low) — `cmd_health` currently
  treats a surviving self-loop (`a→a`) as a 1-node cycle cluster; `cmd_edges` has
  no self-guard, so it reaches health today. This is the health-side face of the
  self-edge doctrine above: decide it here, consistently with the guard's layer,
  and pin the resulting `cmd_health` behavior with a test. (The duplicate-row half
  of #64's original combined bullet stayed in #64 — it is untouched by the
  self-edge doctrine.)
- [x] **consumer-ref abstain test** (was #58, medium) — add a `contracts_repo`
  variant whose consumer lacks the declared usage; assert the consumer side emits
  **no** edge record (not `violated`/`failed`).
- [x] **edge-outcome location-only test** (was #59, medium) — assert the edge
  outcome evidence is `file:line`-only (e.g. `grep -c 'function'` / `'getIdentity'`
  == 0), closing the exfiltration-guard coverage gap `CROSS-REF` already has.

## Resolution

Resolved 2026-07-23 by spec `jim/049` (`049-contracts-check-hardening`). All five
folded items shipped: the blueprint-path resolver routes all three sites (widened
to include `cmd_faces_aggregate`) through `jimfile.sh path blueprint`, dropping the
now-redundant `<specs-root>` arg; the self-edge guard lives at the shared
`cmd_edges` root (`&& c1 != c3` → HYGIENE row), so the edge-outcome loop and
`cmd_health` both inherit the exclusion; and the health self-loop, consumer-abstain,
and location-only behaviors are pinned by tests. The post-build living-intent sensor
confirmed `blueprint-slot-reserved` now holds. The duplicate-row concern remains
tracked separately in its own issue.
