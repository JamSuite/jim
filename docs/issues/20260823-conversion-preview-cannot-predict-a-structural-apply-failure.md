---
id: 20260823-conversion-preview-cannot-predict-a-structural-apply-failure
num: 366
title: "Conversion preview cannot predict a structural apply failure"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, migration]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:29Z
updated: 2026-08-25T07:08:39Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

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

## Resolution (2026-08-25)

Fixed in `73acbdb`. The preview reads both anchors from the frontmatter it was already parsing, and
classifies a record the rewrite has nowhere to write into as `unconvertible`.

`schema_anchored` asks the two questions the awk pass asks — a top-level
`labels:` line and a `duplicates:` relations child — over the region the rewrite
writes, so the preview cannot promise a conversion the apply refuses. The apply
keeps its own `END { exit (scalars && member) ? 0 : 1 }` guard: it is the
last-resort check for a collection that changed after the preview, which is what
`--expect` exists to notice and this guard exists to survive.

**Both obstacle classes now refuse together.** The unrecoverable-filer refusal
already named every affected issue at once, on the stated reasoning that fixing
them one run at a time takes as many runs as there are problems. That reasoning
applies across the two classes as well, so the pre-flight collects both and the
refusal names all of them before anything is written.

**Census.** Every previewed migration in the group was checked for the same
split between what the preview promises and what the apply requires:

| migration | apply's requirement | predicted by its preview |
| :--- | :--- | :--- |
| `schema` | `labels:` + `relations:` `duplicates:` anchors | not until now |
| `identity` | the `filed-by:` / `claimed-by:` line it rewrites | yes — a plan row exists only where `fm_field` found the field, in the same region |
| `reconcile` | `num:` inside the leading frontmatter | yes — detection reads the region the rewrite writes |
| `prefix` | no must-find beyond the file itself | n/a |

`reconcile.sh` is the precedent rather than a coincidence: its detection was
widened to the whole file once, which marked files pending that the rewrite
could not touch, and the fix was to read exactly the region the rewrite writes.
This is the same defect in the one place that had not learned it.

**Fixtures.** Four preview cases described a legacy issue as `title` / `status`
/ `priority` alone — a record the conversion could never have completed, standing
in for the ordinary case. They now use `schema_legacy`, which carries the shape
the real corpus has, and the unanchored shape appears only in the case that is
about it. `case_migrate_schema_preview_names_an_unconvertible_record` pins the
classification, the joint refusal, and that a sound issue beside the bad one is
left byte-unchanged; mutating the guard out turns it red.
