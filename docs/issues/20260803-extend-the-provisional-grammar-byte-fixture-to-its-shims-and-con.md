---
id: 20260803-extend-the-provisional-grammar-byte-fixture-to-its-shims-and-con
num: 215
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
updated: 2026-08-05T02:25:13Z
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

## Partially delivered (2026-08-05)

The shim half is done and done well; the constants half is not pinned. Staying
open.

**Delivered.** All three `prov_id_boundary` shims are pinned verbatim — full-line
`assert_eq` against a literal — and each is mutation-discriminating: loosening
any one of the three to `return 0` turns the case red. Each site's legitimate
difference has a stated in-file rationale (`jimfile.sh:329-331`,
`jimalloc.sh:225-227`, `reconcile.sh:108-110`), so they are deliberate variation,
not drift wearing a pin. The mutation test this issue asked for was run, and it
passes for what it covers.

**Not delivered.** The three `PROV_PREFIX` values are not pinned per site:

```bash
p="$(grep -h 'PROV_PREFIX="' <3 files> | sed 's/^readonly //' | sort -u)"
assert_eq "one prefix value across the three copies" 'PROV_PREFIX="P-"' "$p"
```

`sort -u` asserts "the distinct values I managed to find agree" — not "there are
three, and each is `P-`". Two drifts pass it, both mutation-confirmed at all three
sites: **delete a copy outright** (fewer matches, survivors still reduce to one
line), or **re-spell it `PROV_PREFIX='Q-'`** (the grep pattern is quote-literal,
so the drifted line is not matched at all and the survivors still reduce to
`PROV_PREFIX="P-"`).

This issue's own closing line applies to its own fixture: *a fixture written for a
sync contract that has never been observed failing is a claim, not a measurement.*
It holds per assertion, not per fixture — the half that was measured works, and
the half that was not is blind.

Separately, `tests/jimfile.sh:744`'s `sort -u` is also locale-unpinned, so it can
merge lines that collate equal but differ bytewise. Two independent weaknesses in
one line; the locale half is tracked separately.

Source: post-build review of the B-prime cluster,
`docs/notes/20260805-b-prime-review.md` (Finding 8).
