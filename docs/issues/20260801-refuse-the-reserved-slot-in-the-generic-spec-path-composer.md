---
id: 20260801-refuse-the-reserved-slot-in-the-generic-spec-path-composer
num: 187
title: "Refuse the reserved slot in the generic spec path composer"
status: open
priority: low
labels: [platform, file, scripts, 000-blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T00:22:47Z
updated: 2026-08-01T00:22:47Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

The reserved `000-blueprint` slot has a dedicated resolver arm —
`path blueprint <group>` (`skills/file/scripts/jimfile.sh:961`) — and the
`blueprint-slot-reserved` invariant states the slot is resolved *only* through
it.

The generic composer does not enforce that: `path spec <group> 000 <name>`
(`:937`) accepts `000` as an ordinal, since its gate is `^[0-9]{3,15}$`, and
would compose a `000-<name>` directory path inside the group.

## Assessment

Latent. No caller passes `000` to the generic arm, and the occupancy predicate
refuses a rename onto the slot, so nothing reaches it today. The reserved-slot
guarantee therefore holds in practice while resting on caller discipline at this
one site rather than on the resolver.

Worth noting the adjacent behavior is already correct: `next-id` folds `000` to
`0` and never raises the high-water, so the slot stays ignored rather than
counted.

## Fix

Either refuse `000` in the generic `path spec|plan|research` arm (pointing the
caller at `path blueprint <group>`), or record explicitly that the slot's
resolution guarantee is scoped to the dedicated arm and the generic composer is
caller-disciplined.

Surfaced by a `/jim:verify --since` judge on the `blueprint-slot-reserved`
invariant during the C′-fix build, recorded as a latent note rather than a breach.
