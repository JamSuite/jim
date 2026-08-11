---
id: 20260807-insights-analyst-reads-the-branch-local-collection-under-placeme
num: 266
title: "Insights analyst reads the branch-local collection under placement"
status: closed
priority: high
labels: [issue, placement, insights]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:25Z
updated: 2026-08-11T00:32:51Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`skills/issue/SKILL.md` step 8 was updated to resolve the insights directory via
`place.sh begin --read` and hand `<dir>` to the analyst.
`agents/issue-analyst.md` was not. Its method still reads:

```
3. **Bodies last, selectively.** Read the individual `docs/issues/*.md` bodies
   only for the issues you are actively grouping
```

Under a branch placement the bodies live in the materialized handle directory,
not `docs/issues/`. So the analyst takes its roster and graph facts from the
**destination** (steps 1-2 use `<dir>`) and its bodies from the **branch-local**
collection — silently analysing two different collections. Where the working
tree has no collection at all, the body reads fail and convergence degrades to
metadata-only with no disclosure.

## Secondary

- `<dir>` now points inside the git dir, which the analyst's Read-only grant
  must reach; unverified.
- `SKILL.md` asks the main agent to count `*.md` in `<dir>`, but `/jim:issue`'s
  `allowed-tools` grants no `Glob` or `LS`. Pre-existing, but harder to work
  around now that `<dir>` is an opaque absolute path rather than a known one.

## Proposed action

Parameterize the analyst on the directory it is handed rather than the literal
`docs/issues/*.md`, and confirm its capability grant reaches a path under the
git dir. Add a case asserting the analyst's body reads resolve against the
materialized directory.
