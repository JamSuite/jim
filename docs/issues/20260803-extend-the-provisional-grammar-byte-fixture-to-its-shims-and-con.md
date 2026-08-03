---
id: 20260803-extend-the-provisional-grammar-byte-fixture-to-its-shims-and-con
num: P-20260803-extend-the-provisional-grammar-byte-fixture-to-its-shims-and-con
title: "Extend the provisional-grammar byte fixture to its shims and constants"
status: open
priority: medium
labels: [id-coordination, test-integrity, sync-discipline]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:30Z
updated: 2026-08-03T05:50:30Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

The provisional identity grammar is single-sourced under the `is_valid_id`
discipline: `is_prov_token`'s body is byte-identical across `jimalloc.sh:194`,
`jimfile.sh:343` and `reconcile.sh:121`, each carrying a `SYNC:` comment naming
its copies, with a fixture asserting the three agree.

The fixture covers the **body only**. Each copy additionally supplies its own
`PROV_PREFIX` constant and its own `prov_id_boundary` shim — and the shim is
where the rule's entire security content lives, since the shared body delegates
every charset decision to it. Loosening one shim in one file leaves the fixture
green while widening what that file admits into a filesystem path or a git
argument.

That is the failure the SYNC discipline exists to prevent, relocated one level
down: the part that was hard to keep in agreement is pinned, and the part that
decides the boundary is not.

## Proposed action

Extend the byte-agreement fixture to cover the three `prov_id_boundary`
definitions and the three `PROV_PREFIX` values. Then mutation-test it — loosen
one shim and confirm the fixture fails. A fixture written for a sync contract
that has never been observed failing is a claim, not a measurement.

## Related

[[20260725-formalize-the-is-valid-id-lockstep-contract-between-platform-and]]
asks the same question of the older `is_valid_id` triple; both may want one
answer.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 20e), and the residue of
[[20260730-single-source-the-provisional-identity-grammar]]. Not filed alongside
that review's other follow-ons.
