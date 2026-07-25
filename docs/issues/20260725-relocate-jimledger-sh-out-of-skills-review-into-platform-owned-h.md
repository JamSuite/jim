---
id: 20260725-relocate-jimledger-sh-out-of-skills-review-into-platform-owned-h
num: 102
title: "relocate jimledger.sh out of skills/review into platform-owned home"
status: open
priority: medium
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:45Z
updated: 2026-07-25T08:04:45Z
origin: BLUEPRINT.md
---

## Description

jimledger.sh is platform-owned via a file-level territory carve-out but resides at skills/review/scripts/jimledger.sh (sdlc territory's directory). The review skill addresses it with the own-skill sigil; every other consumer uses the cross-skill path; jimfile.sh and verify/partition hard-code the location. The name-mismatch is permanent until a code move.

Relocate to a platform-owned home (e.g. a ledger skill dir or skills/file/scripts/) through spec → plan → build: touches 8+ allowed-tools lines, 3 BASH_SOURCE resolvers, review's own-skill call sites, and tests. Update the platform territory declaration and blueprint Structure afterward.
