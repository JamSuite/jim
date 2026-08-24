---
id: 20260823-schema-spec-integrity-mockup-diverges-from-the-emitted-report
num: 370
title: "Schema spec integrity mockup diverges from the emitted report"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:30Z
updated: 2026-08-24T19:26:55Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

## Description

The schema spec's integrity mockup shows a report shape the index does not
produce. The capability exists; the mockup describes it differently enough to
mislead.

## What the mockup shows

```
## Integrity

- #63  status is `closed` but no outcome recorded
- #88  outcome `duplicate` names no superseding issue
- #94  unrecognized outcome: `donw`
- #96  unrecognized kind: `epik`
```

## What the index writes

The section is `## Integrity Warnings`, and each entry names the issue by its
slug in a code span rather than by its ordinal:

```
## Integrity Warnings

- `20260101-example` is closed but records no outcome.
```

## Why it matters

Naming records by slug rather than ordinal is the better choice — the slug is
what the file is called, and it survives the ordinal being reassigned. So the
implementation is right and the mockup is stale.

That is exactly the case worth correcting rather than shrugging at: a mockup
that survives in an approved spec is read later as the intended shape, and the
next person to touch this either "fixes" the implementation toward the mockup
or spends time working out which one is authoritative.

## Direction

Update the mockup to the shape the index actually emits. No code change.

## Resolution (2026-08-24)

Fixed in `627c761`.

The mockup is now byte-identical to what `index.sh` writes for those three
records. It was produced by running the index against a fixture collection
holding one record of each class, not transcribed from the code — the
difference matters here, since transcribing is how the original diverged.

**The fourth line was dropped rather than corrected.** A close naming no
superseding issue never reaches the index: `transition.sh` refuses `--as
duplicate` at exit 2 unless the record already names the superseding issue in
its `duplicates` relation, so there is no warning of that shape to mock up. The
spec now says that in place, because a line vanishing from a mockup is itself a
thing the next reader has to work out.

The direction proposed above is what landed.
