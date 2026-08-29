---
id: 20260725-formalize-the-is-valid-id-lockstep-contract-between-platform-and
num: 98
title: "formalize the is-valid-id lockstep contract between platform and issue"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-25T08:04:40Z
updated: 2026-07-25T08:04:40Z
origin: BLUEPRINT.md
---

## Description

The `is_valid_id` validator exists as three byte-identical copies: the canonical in skills/file/scripts/jimfile.sh and two copies in skills/issue/scripts/{index,render}.sh, enforced only by tests/jimfile.sh byte-identity assertions (SYNC comments both sides). Post-split this is a cross-group contract (platform ↔ issue) recorded as the validator-lockstep edge.

Formalize it: either record per-side invariants referencing the lockstep in both blueprints, or eliminate the copies (issue scripts call jimfile.sh valid-id) and retire the edge.
