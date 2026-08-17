---
id: 20260801-two-test-files-are-claimed-by-no-group-s-territory
num: 189
title: "Two test files are claimed by no group's territory"
status: closed
priority: medium
labels: [blueprint, 000-blueprint, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T00:28:40Z
updated: 2026-08-02T07:23:52Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

Two test files are claimed by **no group's** declared territory in `BLUEPRINT.md`:

| File | Tests | Claimed by |
| :--- | :--- | :--- |
| `tests/scripthygiene.sh` | the corpus-wide script-preamble sweep | *nothing* |
| `tests/specreconcile.sh` | `skills/spec/scripts/reconcile.sh` (sdlc) | *nothing* |

Every other `tests/*.sh` resolves to exactly one group.

`tests/scripthygiene.sh` is the sharper case: the **platform blueprint's own
Structure section names it** (`docs/specs/platform/000-blueprint/spec.md:137` —
"the corpus-wide script-preamble hygiene sweep"), so the group blueprint and the
map disagree about whether platform owns it.

## Why it matters

Territory is what scopes verification. A file no group declares is:

- **never scanned** by a territory-scoped `/jim:verify` floor — so the invariants
  that bind these tests are checked against everything except them;
- **reported as a stray every run**, since it falls in the map's set difference
  forever, adding permanent noise to the exception list that is supposed to
  surface real misplacement.

## The ownership question is real for one of them

`tests/specreconcile.sh` is mechanical — it belongs to `sdlc`, alongside the
script it tests.

`tests/scripthygiene.sh` is not. It is a **corpus-wide** sweep asserting a
project-wide script rule across every group's scripts, so declaring it under
`platform` gives platform's territory a file whose subject is other groups' code.
That is defensible (platform holds the project-wide script rules — the
`no-third-party-deps` invariant already works this way, binding every group while
platform holds the check) but it should be decided rather than defaulted. The
alternative is to treat corpus-wide checks as a declared exception the map
records explicitly.

## Fix

Declare `tests/specreconcile.sh` under `sdlc`. Decide `tests/scripthygiene.sh`
deliberately — platform (consistent with how project-wide script rules already
sit there) or a recorded map-level exception — and make the platform blueprint's
Structure section agree with whatever the map says.

## Provenance

Surfaced by the `/jim:verify --since platform` territory-conformance floor during
the C′-fix build. One instance of this same gap — `tests/jimalloc.sh`, likewise
named in platform's Structure and absent from its territory — was found and
repaired in the map during that build. The remaining two were **mis-triaged as
belonging to other groups' territory without checking**, so the class was left
half-swept. Recording that, because fixing one instance and leaving its twins is
the exact pattern this cluster keeps paying for.

## Resolution (2026-08-02)

Both files declared through the project-tier map update (`e2a5635`), closing
the class this issue recorded as half-swept:

- `tests/specreconcile.sh` → `sdlc`, alongside the script it tests — the
  mechanical half.
- `tests/scripthygiene.sh` → `platform`, decided deliberately over the
  recorded-exception alternative: a corpus-wide check whose rule the platform
  group already holds project-wide (the `no-third-party-deps` precedent), and
  the platform blueprint's Structure section already names it — so the map now
  agrees with the group blueprint, which is what this issue's sharper case
  demanded.

The reconcile pass ran on the write: 22 edges, zero findings, and the two
files left the territory-conformance stray set.
