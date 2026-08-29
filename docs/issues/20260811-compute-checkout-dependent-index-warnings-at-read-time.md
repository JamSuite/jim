---
id: 20260811-compute-checkout-dependent-index-warnings-at-read-time
num: 297
title: "Compute checkout-dependent index warnings at read time"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, placement, index]
relations:
  blocks: []
  depends-on: []
  related-to: [20260807-placement-turns-the-origin-lint-into-cross-branch-index-churn]
  duplicates: []
  part-of: []
created: 2026-08-11T01:31:36Z
updated: 2026-08-11T01:31:36Z
origin: docs/specs/issue/011-issue-placement/remediation.md
---

## Description

## Description

`index.sh` writes origin-resolution warnings into `INDEX.md`, the artifact every
reader parses. Whether a path-shaped `origin:` resolves is a fact about **the
checkout the run was standing in**, not about the collection — so a
checkout-dependent verdict is being stored in a checkout-independent artifact.

Under a branch placement that mismatch produced flapping churn, and the
remediation for issue/011 closed it by skipping the lint whenever
`issue_placement` names a branch, disclosing the skip in the warnings block. That
removes the wrong answer. It does not put the right one anywhere.

## The shape this suggests

Split the warnings block on what each half can actually know:

- **Tree-derived warnings stay in `INDEX.md`** — invalid relation targets,
  malformed frontmatter, unparseable `created`, malformed wikilinks, missing
  inverse back-edges. These are facts about the collection and belong in the
  collection's own index.
- **Checkout-derived warnings move to the reader's view** — origin resolution,
  computed by `render.sh stats` against the invoking CWD at read time.

Each developer then gets a meaningful answer about their own tree ("this origin
is not in *my* checkout"), the published index never flaps, and a placement
project regains the signal it currently loses.

## Why it is cheap

`render.sh` already parses `INDEX.md`'s `## Issues` rows, and those rows carry
`origin:`. The read-time pass needs no issue-file reads — it re-lints from the
index's own origin column.

## Why it was not done with the placement fix

It changes the stored artifact for projects with **no placement configured**,
which is behavior no issue/011 review finding asked to change. It was held back
deliberately rather than folded into a remediation whose bar was "do not sprawl
past what this spec broke".

## Proposed action

1. Remove the origin pass from `index.sh`'s warnings block, along with the
   placement-skip note that currently stands in for it.
2. Add a read-time origin pass to `render.sh stats`, resolving against the
   invoking CWD and rendered as its own section.
3. Update the group blueprint's `index.sh` provides face, which names the
   Integrity Warnings block's contents, and `ARCHITECTURE.md`'s description of
   the second pass.

## Test

`tests/issues.sh` currently pins both directions of the placement skip
(`case_issues_placement_tolerates_a_branch_only_origin`,
`case_issues_origin_lint_still_runs_without_a_placement`). Both become assertions
about `stats` output rather than about `INDEX.md`, and the placement case gains
what it cannot have today: a dangling origin actually reported to the reader who
can act on it.
