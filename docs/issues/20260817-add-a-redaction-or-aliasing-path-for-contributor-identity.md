---
id: 20260817-add-a-redaction-or-aliasing-path-for-contributor-identity
num: 352
title: "Add a redaction or aliasing path for contributor identity"
status: closed
priority: medium
labels: [linddun-linking, privacy, issue]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-17T23:49:43Z
updated: 2026-08-18T06:39:28Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

## Context

Spec `issue/012` records a contributor identity on every issue — `filed-by` at
capture, `claimed-by` when someone takes it — and backfills `filed-by` across
the whole existing collection by recovering each file's creating commit.

Surfaced as Finding 6 of that spec's security review (Advisory; LINDDUN
Linking / Non-repudiation / Unawareness & Unintervenability). The spec
explicitly places identity reconciliation out of scope, so this is the
follow-on that scope boundary implies rather than a defect in it.

## Why it matters

Three effects compose once identity is recorded collection-wide:

- **Aggregation.** Individually, one attributed issue is unremarkable. Across
  hundreds, `filed-by` plus `claimed-by` plus `created` composes into a
  per-person activity profile — what someone works on, when they work, how much
  they take on, and what they abandoned. That is a materially different artifact
  from the sum of its rows.
- **Publication.** `ROADMAP.md` commits to making this repository public. The
  profile above becomes public content, and the identity values are plain text
  in file bodies rather than commit metadata — greppable and cheap to scrape in
  bulk.
- **No intervention path.** The backfill attributes issues to whoever created
  each file, without their involvement — including contributors other than the
  person running the migration. Once written, there is no supported way for
  anyone to change how they appear, correct a wrong attribution, or withdraw an
  address. The only recourse is hand-editing files behind the placement door.

Identity aliasing is the related-but-distinct problem: one person committing
under several addresses (a work address on one machine, a personal one on
another) silently splits every by-holder and by-filer view, so their work
appears to belong to two people. A single mechanism can address both.

## What

Add a supported path for a contributor to control how their identity appears in
the collection. Candidate shapes, cheapest first:

1. **Adopt git's `.mailmap`.** Verified available in this environment
   (`git check-mailmap`, git 2.55.0). It is the conventional mechanism, already
   understood by contributors, and solves aliasing and redaction with one file.
   Reads would resolve identity through it rather than trusting the stored value
   verbatim.
2. **Make the recorded form configurable** — full address, local-part, or a
   project-configured handle — so a project can decline to store addresses at
   all. Spec `issue/012` leaves this form as an open question; this issue is
   where the answer becomes changeable after the fact rather than fixed at
   capture.
3. **A redaction verb** that rewrites one identity across the collection,
   through the same door and index-regeneration discipline as any other
   mutation.

(1) and (2) compose well: `.mailmap` handles presentation, configuration handles
what gets stored in the first place. (3) is only needed if values must actually
leave the files rather than be resolved at read time.

## Constraints

- Whatever resolves identity must not become a per-read `git` fork across the
  whole collection — the backfill's own derivation costs one fork per file,
  which is acceptable once and not on a read path.
- Rewriting stored identities is a mass mutation of tracked files and belongs
  behind the same preview and atomicity guards the collection's other
  migrations use.

## Closed — obsolete

The condition this was filed against no longer holds. Closing as *obsolete*
rather than declined: nobody decided against the work, the ground moved beneath
it while spec `issue/012`'s open questions were being resolved.

Each of the three proposed shapes resolved on its own terms:

- **Configurable recorded form** — settled against. `issue/012` now excludes
  normalizing or obscuring the recorded value, and excludes a project-wide
  identity policy. The form is each contributor's own version-control
  configuration decision; a contributor wanting non-routable attribution
  configures a forge noreply address, which needs nothing from jim.
- **A redaction verb** — would not deliver what its name promises. Scrubbing
  addresses from issue files while the commit history beside them retains every
  one is tidying, not privacy. Genuine redaction means rewriting the whole
  version-control history, which is out of jim's remit.
- **Alias adoption** — folded into `issue/012` instead. The commit author's
  address has a mapping-aware spelling that resolves through the project's own
  alias file where one exists and returns the raw address where none does.
  Using it costs a single character in the derivation, adds no configuration and
  no mapping for jim to maintain, and keeps one person's several addresses from
  splitting every by-person view. It is recorded there as an architect note, and
  that spec's exclusion on reconciling identities was tightened so the two do
  not appear to conflict.

What remains genuinely uncovered is retroactive change for a contributor who
files under one address and later prefers another — and that is the redaction
shape above, which does not work for the reason given. If it becomes a real
request rather than an anticipated one, it should be re-filed against the
history-rewrite problem it actually is, not against the issue collection.
