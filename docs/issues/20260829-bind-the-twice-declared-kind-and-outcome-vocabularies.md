---
id: 20260829-bind-the-twice-declared-kind-and-outcome-vocabularies
num: P-20260829-bind-the-twice-declared-kind-and-outcome-vocabularies
title: "Bind the twice-declared kind and outcome vocabularies"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, drift, issues-system]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-29T05:45:27Z
updated: 2026-08-29T05:45:27Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

## Description

The blueprint invariant `declared-vocabularies` requires that "every vocabulary
a rule quantifies over is a declared constant, and every site that quantifies
iterates that constant rather than restating its members" — and names the
failure mode in its second sentence: "a guard, a parser dispatch and a test that
each enumerate the same set independently agree only by coincidence, and the one
that is short is silent about it."

Two of this group's vocabularies are declared twice, in different files, with no
marker binding the copies and no test comparing them.

## Where

- `ISSUE_TYPES` — `skills/issue/scripts/new.sh:81` (the capture-side guard) and
  `skills/issue/scripts/index.sh:79` (the read-side classifier). Both read
  `readonly ISSUE_TYPES=(issue epic)`.
- `ISSUE_OUTCOMES` — `skills/issue/scripts/transition.sh:69` (the close-side
  gate) and `skills/issue/scripts/index.sh:80` (the read-side classifier). Both
  read `readonly ISSUE_OUTCOMES=(done wontfix duplicate obsolete)`.

Every individual site iterates its own array correctly. The gap is that there
are two arrays where the rule assumes one.

## What makes it a divergence rather than ordinary duplication

The group already has an established convention for exactly this, applied
consistently everywhere else: a `SYNC(` marker naming the partners, plus a test
that compares the bodies.

- `is_valid_id` — three copies, marker on each, compared by
  `case_jimfile_is_valid_id_triplicate_identical`.
- the timestamp shape — four copies, `SYNC(ts-shape)` on each, compared by
  `case_issues_timestamp_shape_triplicate_identical`.
- the branch-name gate — two copies, `SYNC(valid-branch)` on each, compared by
  `case_place_valid_branch_agrees_with_the_allocator_copy`.

Two further markers declare a *deliberate* asymmetry in their own text, so an
intended difference never reads as drift. These two pairs have neither: no
marker, no test, no declared asymmetry.

`new.sh` even names its twin in prose — "index.sh declares the same vocabulary
for the reading side" — which is the acknowledgement without the enforcement.

## Why it matters

The two copies agree today, so nothing is broken now. The exposure is a
half-landed extension: adding a third kind to the capture guard without adding
it to the read-side classifier gives an emitter that accepts the value and an
index that reports every record carrying it as unrecognized. The same shape
applies to an outcome added at the close gate but not at the classifier. Both
are silent at the moment of the edit and surface later, in the index, as data
that looks corrupt rather than as a vocabulary that is short.

## The fix

Bind each pair the way every other shared definition in this group is bound: a
`SYNC(` marker on both copies naming the other, and a test that compares the
declared members. The existing triplicate tests are the pattern to copy.

Whether the two vocabularies should instead collapse to one declaration that
both files read is a larger question — these are bash scripts with no shared
include, which is why the corpus uses marker-plus-test rather than a single
definition everywhere else. Following the established convention is the smaller
and more consistent change.

## Scope note

The prose surfaces are a separate, larger question and are not part of this.
`SKILL.md` restates the outcome vocabulary, the lifecycle states, the priority
tiers and the two derived predicates by hand. Two vocabularies are already
derived and checked against the scripts that declare them from
`tests/docsurfaces.sh` — the transition verbs and the capture kinds — and the
rest are not. That is worth its own record rather than widening this one.
