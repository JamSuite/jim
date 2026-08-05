---
id: 20260805-teach-both-single-source-guards-in-jimfile-tests-the-spellings-a
num: P-20260805-teach-both-single-source-guards-in-jimfile-tests-the-spellings-a
title: "Teach both single-source guards in jimfile tests the spellings and copies they miss"
status: open
priority: medium
labels: [test-coverage, test, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:29Z
updated: 2026-08-05T22:20:29Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

Two single-source guards sit twenty lines apart in `tests/jimfile.sh`. One closes
the omission class with a repo-wide sweep; the other does not — and the one that
does still misses the spellings that caused the drift it exists to catch.

**The ordinal-width guard** (`:1598-1630`) keys on *naming the bound*, so it
catches conformant restatements and misses non-conformant caps. Planted in an
unaccounted script, each of these passes:

```
(( ${#1} > 15 ))       <- the HOUSE spelling; alloc_valid_ord uses it verbatim
${#SEQ} > 15           <- variable-name class is [a-z_]+, jim's globals are uppercase
awk length(myVar)      <- same
(( n > 999 ))          <- one of the two gates the build called "the dangerous ones"
${bn:0:3}              <- the other one
[0-9]{3,}              <- extraction at :1599 requires digits after the comma
[0-9][0-9][0-9]
```

`(( ${#1} > 15 ))` is the exact fifth mutation issue 222's Resolution says now
fails ("Five of the six reported-blind mutations now fail, and the sixth with
them"), and it is the spelling of the canonical predicate:

```
alloc_valid_ord() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  (( ${#1} <= ALLOC_MAX_ORD_DIGITS ))
}
```

The new `scripts/` root also has no enumeration guard, unlike the sibling sweep in
`tests/scripthygiene.sh` which added one for the same root: `mv scripts /tmp/` and
the case still passes.

**The provisional-grammar pin** (`:729-757`) has the opposite problem. Every
assertion discriminates — all six drifts issue 224 named go red, as do all three
branches of 226's disjunction — but its corpus is three hardcoded paths with no
sweep. Giving `jimpartition.sh` a fourth `PROV_PREFIX`, its own
`prov_id_boundary() { return 0; }` and a loosened `is_prov_token` leaves the suite
at 1182/1182. Both its patterns are `^`-anchored, so an *indented* copy is
invisible to the fail-closed count as well as to the value assertion — which
contradicts commit `2beee89`'s claim that "a line that is missed cannot read as
clean". And `skills/spec/scripts/reconcile.sh:722` restates the whole grammar
inline without going through `is_prov_token`; widening its date class leaves all
73 specreconcile cases green.

## Proposed action

Width guard: widen the variable-name class to `[A-Za-z_][A-Za-z0-9_]*`, add the
positional form `${#N}`, match a bare numeric ceiling (`999`) and a fixed slice
(`${x:0:N}`), and accept `[0-9]{N,}` in the extraction. Add the missing
enumeration guard on the `scripts/` root.

Provisional pin: give it the repo-wide sweep its neighbour already has — no
script outside the accounted paths may spell `PROV_PREFIX`, define
`prov_id_boundary`, or restate the grammar — and drop the `^` anchor so an
indented copy is seen.
