---
id: 20260805-pin-the-locale-at-the-three-locale-sensitive-test-sites
num: P-20260805-pin-the-locale-at-the-three-locale-sensitive-test-sites
title: "Pin the locale at the three locale-sensitive test sites"
status: open
priority: high
labels: [000-blueprint, verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T02:19:10Z
updated: 2026-08-05T02:19:10Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

The `script-preamble` invariant says every script sets `set -uo pipefail`
directly and that **locale-sensitive scripts also `export LC_ALL=C`**. Clause one
holds without exception across the territory. Clause two breaches in three test
files, all of which this change touched.

| site | construct | risk |
| :--- | :--- | :--- |
| `tests/jimfile.sh:744` | `\| sed 's/^readonly //' \| sort -u` | collation-dependent dedupe |
| `tests/jimalloc.sh:3975` | `tr -d 'A-Za-z0-9 ()/:.,_@-'` | collation range |
| `tests/jimledger.sh:196` (also `:302`, `:1096`) | `grep -cvE '^[a-z_]+=[A-Za-z0-9._-]*$'` | character class |

`tests/jimfile.sh:744` is the sharpest: under a UTF-8 locale, lines that collate
equal but differ bytewise can be silently merged by `sort -u`, turning a genuine
three-copy mismatch into a passing assertion. That is the *same line* whose
`sort -u` set-compare is already blind to a deleted or re-quoted copy — two
independent weaknesses in one assertion, found from opposite directions.

The authors clearly treat these constructs as locale-sensitive, because the same
files pin the locale per command elsewhere — `tests/jimalloc.sh:1084`
(`\| LC_ALL=C sort`) and `:2242` (`find docs \| LC_ALL=C sort`). The treatment is
inconsistent, not a considered exemption.

**The literal remedy would be wrong here.** `run.sh` sources every test file into
one shell, so a top-level `export LC_ALL=C` in a test file would leak into every
other fixture — the exact regression the framework exemption at
`tests/scripthygiene.sh:20-26` guards, pinned by
`case_scripthygiene_framework_imposes_no_locale`. So the fix is per-command pins,
not a preamble line.

**Nothing mechanises the rule where it broke.** `tests/scripthygiene.sh:90-101`
sweeps `LC_ALL` only under `skills/*/scripts/*.sh`. It is uniform and deliberately
over-strict there, and entirely silent for `tests/*.sh` and `scripts/*.sh` — which
is where every divergence above lives.

## Proposed action

Add per-command `LC_ALL=C` pins at the sites above (`LC_ALL=C sort -u`,
`LC_ALL=C tr`, `LC_ALL=C grep`), matching the pattern the same files already use.
Do not add a top-level export to any file the runner sources.

Then decide whether `scripthygiene.sh`'s locale sweep should extend to `tests/`
and `scripts/` with a per-file locale-sensitivity judgment, or whether the
invariant's text should state the scope it actually mechanises. Today the rule
says "project-wide" and the check covers one third of the corpus.

## Provenance

`/jim:verify --since 175047c platform` — `script-preamble` (high), judged
`violated`, `channel=in-change`. Resolved **fix** at the blueprint update's
violation fork.
