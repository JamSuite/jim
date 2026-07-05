---
id: 20260705-wire-the-group-territory-floor-strength-label-in-contract-mode
num: 60
title: "Wire the group_territory floor-strength label in contract mode"
status: open
priority: low
labels: [verify, contract-graph]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T22:44:12Z
updated: 2026-07-05T22:44:12Z
origin: docs/specs/jim/037-verify-contracts/review.md
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

Surfaced by the spec 037 post-build review (`docs/specs/jim/037-verify-contracts/review.md`, Finding 4).
