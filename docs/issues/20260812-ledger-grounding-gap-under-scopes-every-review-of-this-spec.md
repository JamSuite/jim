---
id: 20260812-ledger-grounding-gap-under-scopes-every-review-of-this-spec
num: 335
title: "Ledger grounding gap under-scopes every review of this spec"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [sdlc, ledger, review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:44Z
updated: 2026-08-12T21:53:44Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`/jim:review` builds its change set from `jimledger.sh files <spec-dir>`, which
returns the range recorded between `build started` and `build finished`. For
`issue/011` that is **19 files**, and `metrics` reports
`base_sha=f024b9e head_sha=3c1a78f commits=15`.

The tree those reviews actually judged is **140 commits and 113 files** past that
head (+14920/−237). Everything after the build — a defect-fix pass, a sixteen-work-
package remediation, and a review-remediation round — falls outside the ledger's
range entirely.

Three consecutive reviews have hit this:

- The second and third both recorded it and judged the working tree anyway.
- The third recorded it **twice** — as an "Instrumentation gap" under Coverage and
  a "Grounding gap" under Living intent.
- The fourth recorded it again.

Each time it was worked around by hand. It has never been filed.

## Why it is more than a reporting nuisance

The change set is not only a reporting input. It is the **selection** input for
the living-intent sensor: `/jim:verify --from-review` uses
`jimledger.sh files <spec-dir>` to decide which judge invariants are
change-selected, and an unselected judge invariant is `skipped` with reason
`scope`. A change set narrowed to the build's 19 files can therefore silently skip
invariants whose only touched code arrived in the remediation.

It did not bite in practice for `issue/011` — the remediation touched the same
files the build did, so all nine invariants were selected — but that is luck, not
design. A remediation that touched a *new* file would leave its invariants
unjudged, and the review would report the resulting clean coverage without
qualification.

The same gap makes the `review.md` metric frontmatter describe a build rather than
the reviewed subject, so every mined data point for this spec is off by two orders
of magnitude on files and one on commits.

## What is not the answer

Re-running `/jim:build` to re-stamp the range would falsify the build's own
record. The ledger is append-only and the build genuinely was 15 commits.

## Action

Give `/jim:review` a change set that matches its subject. Options worth weighing:

1. A `jimledger.sh files-since <spec-dir>` verb that ranges from the build's
   `base_sha` to `HEAD` rather than to the recorded `head_sha`, used by review when
   the recorded head is an ancestor of HEAD.
2. Record a `remediation started/finished` stage pair on the ledger, so post-build
   work has its own range and `files` can union them.
3. Have `/jim:review` detect `head_sha != HEAD`, widen to the working tree, and say
   so in a structured field rather than in prose each reviewer writes by hand.

Whichever is taken, `/jim:verify --from-review`'s change-selection must consume the
same widened set — that is the half with correctness consequences, not just
reporting ones.

Origin: recorded in the second, third and fourth `/jim:review` runs of
`issue/011`; filed from the fourth.
