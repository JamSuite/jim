---
id: 20260823-conversion-preview-cannot-predict-a-structural-apply-failure
num: 366
title: "Conversion preview cannot predict a structural apply failure"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:29Z
updated: 2026-08-23T23:45:29Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

## Description

The collection conversion's preview classifies every issue as convert / skip /
unresolved, but it checks none of the structural anchors the apply step
requires. A run can preview cleanly and then fail part-way through.

## What happens

The preview derives a filer and an outcome per issue. The apply writes the new
fields with an awk pass that needs two anchors in the frontmatter — a `labels:`
line to insert the scalars before, and a `duplicates:` line under `relations:`
to insert the membership entry after — and refuses the file when either is
absent:

```
END { exit (scalars && member) ? 0 : 1 }
```

An issue missing either anchor is reported as `convert` in the preview and
fails at apply time with "has no place to put the new fields".

## Why it matters

The preview exists so an operator can approve a whole-collection change before
it runs. A structural failure that only surfaces mid-apply means the operator
approved a plan the tool already had enough information to know was wrong: the
anchors are in the same frontmatter the preview already parses.

The apply is per-file atomic, so nothing is corrupted — but the run stops with
part of the collection converted and part not, and the operator has to discover
which by reading the error.

## Direction

The preview can check for both anchors while it is already reading each file's
frontmatter, and classify a file that lacks them as unconvertible — the same
class as an unrecoverable filer, which the preview already reports and which
already refuses the whole run before writing anything.
