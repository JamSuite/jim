---
id: 20260725-relocate-jimledger-sh-out-of-skills-review-into-platform-owned-h
num: 102
title: "relocate jimledger.sh out of skills/review into platform-owned home"
status: closed
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:45Z
updated: 2026-07-25T21:04:12Z
origin: BLUEPRINT.md
---

## Description

jimledger.sh is platform-owned via a file-level territory carve-out but resides at skills/review/scripts/jimledger.sh (sdlc territory's directory). The review skill addresses it with the own-skill sigil; every other consumer uses the cross-skill path; jimfile.sh and verify/partition hard-code the location. The name-mismatch is permanent until a code move.

Relocate to a platform-owned home (e.g. a ledger skill dir or skills/file/scripts/) through spec → plan → build: touches 8+ allowed-tools lines, 3 BASH_SOURCE resolvers, review's own-skill call sites, and tests. Update the platform territory declaration and blueprint Structure afterward.

## Resolution

Shipped as spec `platform/004-jimledger-home` (full spec → research → sec → plan → build → review chain; review verdict `aligned`, 0 invariant/contract violations).

`jimledger.sh` now lives at `skills/ledger/scripts/jimledger.sh` in a dedicated platform-owned skill dir, fronted by a read-only `/jim:ledger` inspector (verb-scoped `allowed-tools`, no mutating verbs). The file-level carve-out is gone from `BLUEPRINT.md` and both the platform and sdlc `000-blueprint`s; `skills/ledger` is declared wholesale platform territory. Every live consumer (allowed-tools, body call sites, the two `BASH_SOURCE` resolvers, both test path constants, the current blueprints, and user-facing docs) resolves the new home; frozen historical artifacts and `ARCHITECTURE.md` were handled per the live-vs-frozen boundary (the latter via `/jim:arch`). The CLI's behavior is unchanged (additive-only diff; a new read-only `events` verb backs the inspector's stage-events view).
