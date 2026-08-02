---
id: 20260802-close-the-ac-16-17-18-residuals-of-rename-redirect-emission
num: P-20260802-close-the-ac-16-17-18-residuals-of-rename-redirect-emission
title: "Close the AC 16 17 18 residuals of rename redirect emission"
status: open
priority: medium
labels: [id-coordination, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T21:35:14Z
updated: 2026-08-02T21:35:14Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

## Description

Three acceptance criteria of blueprint/025 shipped partially satisfied. Each is
small on its own; together they are one cleanup pass.

**AC 16 — a retryable refusal reported in terminal language.** When the *source*
group was renamed concurrently — the exact shape a split faces, where every
source shares one group — the live-claim set holds post-rename names, so
`alloc_partition_spec_publish_builder:3235` refuses with "the registry holds no
live claim on it (never allocated, or already moved away)". That message carries
no `group renamed` marker and names no redirect, so the consumer
(`skills/partition/SKILL.md:387-389`) is instructed to report rather than retry
— even though re-running against the current group name is exactly the remedy.
AC 16 asks that the retryable and terminal refusals be distinguishable.

Separately, the **spec-mode** redirect path is unfixtured: every AC-16 test
covers group mode. And the destination-redirect message says "re-run the batch
against that name", but a destination-group redirect actually requires rewriting
the `<new-id>` column of every row, not just re-running.

**AC 17 — the width bounds agree on the ceiling, not the floor.**
`jimledger.sh:689`'s `isord` admits 3–15 digits. The registry has no lower bound
(`alloc_valid_specid` is `^[0-9]+$`, printed `%03d`), so `old/01` and `old/7` are
ids the registry represents but the ledger parser silently drops. The direction
is fail-closed, and the 3-digit floor matches the *tree* path bound — but AC 17
names the registry, so the criterion holds only on the upper bound.

Note this also makes `jimledger.sh:689` a **third** hand-synced copy of the
ordinal width bound. The existing follow-on issue on single-sourcing that bound
says it is "decided in two places", which is now an understatement — that issue
should be updated rather than a fourth filed.

**AC 18 — one new output path echoes an ungated token.** `reconcile.sh:305`
prints `$newgroup` raw on the branch that fires *because* `$newgroup` just
failed `jf valid-id`. The value is registry-derived, and `reconcile.sh` has no
sanitizer at all — no `san_field`, no `alloc_display_field` equivalent.
Reachability is currently nil (the mapping's group is always alias-resolved
through gated rows), but the branch's entire purpose is "this token failed its
gate", which makes the omission substantive rather than theoretical.

Adjacent, not a defect: `alloc_lift_states`' `case` at `:3537-3566` has no `*)`
arm, so an unrecognised kind falls through to a printf that emits `$kind`,
`$src` and `$dst` raw. Unreachable today — `cmd_pair_events` emits only three
literal kinds with charset-gated sides — but it is inconsistent with the comment
three lines above, which justifies re-gating the date because that is "the
discipline every other field on this path already follows".

## Proposed action

- Carry the `group renamed` marker (and the redirect) into the source-side
  refusal when the source group has an alias; fixture the spec-mode redirect.
- Either lower the ledger parser's ordinal floor to match the registry, or
  record the 3-digit floor as a deliberate tree-shape bound in AC 17's terms —
  and fold `jimledger.sh:689` into the existing width-bound single-sourcing
  issue.
- Give `reconcile.sh` a sanitizer and use it at `:305`; add a `*)` arm to the
  lift's kind `case`.

Surfaced by the post-build review of blueprint/025 (findings 8, 9, 12).
