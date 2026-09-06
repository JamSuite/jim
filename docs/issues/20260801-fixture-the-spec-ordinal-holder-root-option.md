---
id: 20260801-fixture-the-spec-ordinal-holder-root-option
num: 184
title: "Fixture the spec-ordinal-holder --root option"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [platform, file, scripts, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T00:22:46Z
updated: 2026-08-01T00:22:46Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

`cmd_spec_ordinal_holder` gained a `--root <dir>` option
(`skills/file/scripts/jimfile.sh:528-568`) so a caller carrying its own specs dir
can gate against the tree it is actually guarding rather than the configured one.
`jimledger.sh cmd_move_spec_dir` is its only consumer.

No fixture exercises it. `tests/jimfile.sh`'s `spec-ordinal-holder` cases all run
against the configured dir, and the `move-spec-dir` cases reach `--root`
indirectly, through the sibling script, so nothing pins the option's own
behavior: that it takes the next argument as a value, that it overrides the
configured dir, that a missing value is a usage error, and that the predicate's
rc contract is unchanged under it.

## Why it matters

The option exists precisely so a gate never reads a different tree than the one
it guards. That property is currently asserted by nothing — and the guard it
serves already shipped one defect (the exclusion carried across parents) that its
own fixtures did not cover.

## Fix

Fixture `--root` directly: an override against a non-configured tree, the
missing-value usage error, and rc 0 / 1 / 2 under the override.

Surfaced by a `/jim:verify --since` judge on the `relpath-validation` invariant
during the C′-fix build, which recorded the absence as a bound on its own verdict.
