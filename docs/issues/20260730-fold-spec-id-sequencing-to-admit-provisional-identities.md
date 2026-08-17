---
id: 20260730-fold-spec-id-sequencing-to-admit-provisional-identities
num: 149
title: "Fold spec-id-sequencing to admit provisional identities"
status: closed
priority: critical
labels: [id-coordination, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:00Z
updated: 2026-08-02T06:52:07Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`sdlc/017` (coordinated spec identity) contradicts the high-criticality
invariant `spec-id-sequencing`, declared in two blueprints and folded into
neither:

- `docs/specs/sdlc/000-blueprint/spec.md:100`
- `docs/specs/jim/000-blueprint/spec.md:233`

Both declare: "Spec IDs are 3-digit zero-padded and sequential within the group;
… (the minting mechanism is the platform group's `next-id`)". Both halves are
now false **by design**, not by accident:

- a provisional identity is `P-<date>-<slug>` — not three digits, and not
  sequential — for the whole offline window before realization;
- the minting mechanism is the coordination allocator, and the spec deliberately
  strands `next-id` for spec creation.

## Why it matters

The next `/jim:verify` of either group has to score every pending provisional
spec a violation, or silently reinterpret its own invariant. Neither is a real
answer: the declaration no longer describes the system, so the sensor can only
produce noise or a false pass. An invariant that must be mentally excepted has
stopped being an invariant.

It also went unrecorded, which is the second half of the problem — the
living-intent sensor is exactly the mechanism that exists to refuse to let this
pass silently, and it did not run during the build's review. The contradiction
was found by an omission sweep instead.

## Fix

Fold both declarations through the blueprint surface — never a hand edit:

- `sdlc`: `/jim:blueprint --from-review docs/specs/sdlc/017-coordinated-spec-identity`
- `jim`: its own pass; the `jim` group is outside `sdlc/017`'s review scope.

Restate the invariant so it covers **both** identity states a bound spec can
legitimately be in (reserved provisional, and realized `NNN`), and name the
allocator as the minting mechanism rather than `next-id`.

Worth doing in the same pass: run
`/jim:verify --from-review docs/specs/sdlc/017-coordinated-spec-identity sdlc`.
The group's other invariants are currently **unmeasured, not sound** — the
review's living-intent section counts only what the omission sweep evidenced.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30), which recorded it as the single evidenced invariant violation.

## Resolution (2026-08-02)

Closed as discharged on both halves; the body above predates the drop decision
and this note is the correction.

- **The `sdlc` half landed** with `sdlc/018`'s completion gate, folded through
  `/jim:blueprint --from-review` at an explicit violation fork. The invariant
  now reads: "Spec IDs are minted by the coordination allocator — either a
  3-digit zero-padded ordinal unique within its group, or a reserved
  provisional token pending realization"
  (`docs/specs/sdlc/000-blueprint/spec.md:100`) — both identity states, and
  the allocator named as the minting mechanism. Verified live this date; the
  residual `partial` a verify judge scores on this invariant is its unrelated
  approved-before-plan clause.
- **The `jim` half was deliberately dropped**, not forgotten: the group is
  retired (`docs/specs/jim/000-blueprint/spec.md`, `status: retired`), absent
  from the map, excluded from reconcile and the contract graph — editing it
  would make a superseded document look maintained while staying outside
  every mechanism that keeps documents current. Its stale invariant text is
  part of the retired-group end-of-life question tracked on
  [[20260725-give-retired-group-directories-a-sanctioned-end-of-life]].
