---
id: 20260626-instrument-jim-review-as-a-ledger-stage-and-preserve-verdict-his
num: 15
title: "Instrument /jim:review as a ledger stage and preserve verdict history"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [review, ledger]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-26T06:43:40Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/sdlc/015-review-depth/spec.md
---

## Description

`/jim:review` writes nothing to the ledger — it is absent from `LEDGER_STAGES`
(`spec research plan sec build`), so the review's own duration, runs, and
interruptions are never captured, and Step 8's overwrite-on-re-run discards the
prior alignment verdict.

Emit a `review finished alignment=<v> findings=<n>` ledger event so `review.md`
stays the latest snapshot while the verdict trajectory survives in the
append-only log (drifted → fixed → re-reviewed becomes visible). This is a
cleaner answer to spec 026's still-open re-run question than plain overwrite.

Surfaced during scoping of spec 027 (depth-aware review); deliberately kept out
of that spec's scope.
