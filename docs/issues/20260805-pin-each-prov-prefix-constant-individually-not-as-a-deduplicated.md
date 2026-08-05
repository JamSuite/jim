---
id: 20260805-pin-each-prov-prefix-constant-individually-not-as-a-deduplicated
num: P-20260805-pin-each-prov-prefix-constant-individually-not-as-a-deduplicated
title: "Pin each PROV_PREFIX constant individually, not as a deduplicated set"
status: open
priority: medium
labels: [id-coordination, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:45Z
updated: 2026-08-05T01:53:45Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

The provisional-grammar fixture pins the three `prov_id_boundary` shims verbatim
and correctly. Its `PROV_PREFIX` half does not pin anything per-site.

`tests/jimfile.sh:739-745`:

```bash
p="$(grep -h 'PROV_PREFIX="' \
     "$REPO_ROOT/skills/file/scripts/jimfile.sh" \
     "$REPO_ROOT/skills/file/scripts/jimalloc.sh" \
     "$REPO_ROOT/skills/spec/scripts/reconcile.sh" \
     | sed 's/^readonly //' | sort -u)"
assert_eq "one prefix value across the three copies" 'PROV_PREFIX="P-"' "$p"
```

`sort -u` asserts *"the distinct values I managed to find agree"* — not *"there
are three, and each is `P-`"*. Two drifts are therefore invisible:

- **Delete a copy outright** — fewer matches, the survivors still reduce to one
  line, assertion passes.
- **Re-spell it `PROV_PREFIX='Q-'`** — the grep pattern is quote-literal, so the
  drifted line is not matched at all; the survivors still reduce to
  `PROV_PREFIX="P-"` and the assertion passes with the constant genuinely
  changed.

Both were mutation-confirmed at all three sites (6 of 6 green when they should be
red). The drift is caught eventually by *other* files' fixtures —
`tests/specreconcile.sh` drops to 16/53 under a combined drift — but not by the
fixture that exists to catch it.

The shim half is sound: each of the three is a full-line `assert_eq` against a
literal, all three mutation-discriminating, and each site's legitimate difference
has a stated in-file rationale (`jimfile.sh:329-331`, `jimalloc.sh:225-227`,
`reconcile.sh:108-110`). Not drift wearing a pin.

Worth recording *which* half was measured: issue #215 asked to "mutation-test it —
loosen one shim and confirm the fixture fails", and that was done and passes. The
constants half was never mutation-tested, and it is the half that is blind. The
issue's own closing line applies to its own fixture: *a fixture written for a sync
contract that has never been observed failing is a claim, not a measurement* —
per assertion, not per fixture.

## Proposed action

Assert each of the three constants individually and by path, so a deleted copy is
a failure rather than a smaller set. Match both quote spellings, or normalize
before comparing.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 8).
