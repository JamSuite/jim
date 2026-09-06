---
id: 20260826-spec-and-finding-ids-in-comments-outside-the-issue-group
num: 401
title: "spec and finding ids in comments outside the issue group"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [hygiene, conventions, tooling]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T10:25:25Z
updated: 2026-08-26T10:25:25Z
origin: "docs/specs/issue/014-read-view-filter-composition/remediation.md"
---

## Description

The convention forbidding spec / AC / Finding / DD citations in bash comments is
project-wide — it governs every script under `skills/*/scripts/`, and it gives
the reason: `rename` and `split` renumber the very specs an id points at, so the
reference rots the moment the thing it names moves. The `issue` group's scripts
are now clean. Three scripts in two other groups are not.

## Census

Comment lines carrying a citation, counted with
`spec[- ]NNN | security[- ]NNN | AC[ -]?#?N | AC-<letter> | Finding[s] N | DD[ -]?#?N`
over comment lines only:

```
skills/verify/scripts/jimverify.sh   46   (blueprint group)
skills/conf/scripts/jimconf.sh       11   (platform group)
skills/file/scripts/jimalloc.sh       1   (platform group)
```

`jimverify.sh` carries most of them in its usage header, where each verb is
attributed to the spec that introduced it — `check … (spec 035 Task 4)`,
`scope-census … (spec 041)`, `faces … (spec 037)`, `edges … (spec 037)`,
`contracts-check … (spec 037)`, and a section banner reading
`faces-aggregate — deterministic reconcile counters (spec 045)`. `jimconf.sh`
concentrates its in a single knob-taxonomy comment that attributes each config
family to the spec that added it, plus two security notes. `jimalloc.sh` has one
(`per AC 6`).

## Why the header form is the worst case

A usage block is what a reader consults first and what a `--help` reviewer
copies from. Attributing a verb to `spec 035 Task 4` tells a reader nothing
about what the verb does and everything about an ordinal that a group rename or
split will move. The behaviour is the part that earns its place in the comment;
the attribution is what the convention says does not.

## Fix shape

Delete the parenthetical from each, keeping the sentence — the same edit the
`issue` group took. Where a citation is doing real work (the `jimconf.sh` knob
taxonomy uses spec numbers to group families), name the family rather than the
spec: the families have names.

## The durable half

Nothing checks this, which is how ~90 citations accumulated across five groups
before anyone counted. A textual sweep in `tests/scripthygiene.sh` — the file
that already asserts textual invariants over the whole first-party script corpus
— would close it. The pattern above produced zero false positives across the
`issue` group once two shapes were excluded:

- `\bF[0-9]\b` matches `cut -f1` / `cut -f2-`. Drop it; `security F2` is rare
  enough to catch by the `Finding` spelling.
- A bare `#[0-9]` matches the prose example `"close issue #5"` in `place.sh` and
  the legitimate `settled #N` in `render.sh`. Do not match bare hash-numbers.

Adding the check requires the sweep above to land first, or it fails on arrival.

## Coverage

`tests/scripthygiene.sh` sweeps `skills/*/scripts/*.sh`, `tests/*.sh` and
`scripts/*.sh` for the `set -uo pipefail` and `export LC_ALL=C` preambles, and
is fail-closed on an empty glob. It is the natural home: the invariant here is
textual over the same corpus, and per-file judgment about whether a given
citation is "harmless" is exactly the question a mechanical check answers better
than a reviewer.
