---
id: 20260705-wire-the-group-territory-floor-strength-label-in-contract-mode
num: 60
title: "Wire the group_territory floor-strength label in contract mode"
status: closed
priority: low
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:12Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/009-verify-contracts/review.md
---

## Description

Spec 037 AC #5 asks the contract-mode report to name the cross-reference floor's
strength by `group_territory` mode (`directory` strongest, `declared-paths` mid,
`none` leaves only the judge). The report shape prints `territory: <mode>`
(`skills/verify/references/contracts-methodology.md`), but the C1 process never
resolves the `group_territory` config key, so the `directory`-vs-`declared-paths`
distinction is never actually surfaced. Only the `none` degradation is observable
(via the script's `UNSCOPED-GROUP` record).

**Proposed action (one of):** resolve `group_territory` in the contract-mode C1
step and print the concrete mode, **or** drop the `<mode>` placeholder from the
report shape so it does not imply a floor-strength distinction the run does not
make.

Low priority — the `none` case (the one with real verification-strength impact)
is already surfaced; this is about honest reporting of the mid/strong tiers.

Surfaced by the spec 037 post-build review (`docs/specs/blueprint/009-verify-contracts/review.md`, Finding 4).

## Resolution (2026-07-09)

Took the **resolve-and-print** fork, not the drop-the-placeholder fork — it is
the smaller edit *and* the honest closure of AC #5 (drop would have to also
unwind the check-ladder prose at `contracts-methodology.md:37-39`, which already
commits to naming the mode, and would leave the AC formally unmet).

Grounding that sharpened the fix: `jimverify.sh contracts-check` derives every
territory from the **map's own declarations** (`cmd_territory`) and never reads
`group_territory` — the knob is consumed at map-*build* time (`/jim:partition`,
`/jim:blueprint`), not at verify time. So the header names the *configured
doctrine the map was built under* (`directory`/`declared-paths`/`none`), which is
the baseline the reader needs to interpret the per-group `UNSCOPED-GROUP` records
that already surface the realized `none`. Naming it as a measured per-run
strength would over-claim; naming it as the configured mode is exact.

Changes (both in `skills/verify/references/contracts-methodology.md`, the single
home of the contract report shape):

1. **C1** now resolves the mode via `jimconf.sh get group_territory` (default
   `declared-paths`; unrecognized value → named config fallback, matching the
   skill's appetite/model discipline), with the configured-vs-realized distinction
   spelled out so the header is never mistaken for a floor-scan re-read.
2. The report header placeholder `territory: <mode>` → `territory: <group_territory>`,
   self-documenting its source. The closing degradation-naming paragraph already
   covers "any config fallback," so a junk knob is surfaced there.

No script or test change: the report shape is skill-process prose, and the floor
script's behavior is unchanged (it already ignores the knob by design).
