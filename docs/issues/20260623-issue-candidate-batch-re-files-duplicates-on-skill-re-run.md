---
id: 20260623-issue-candidate-batch-re-files-duplicates-on-skill-re-run
num: 14
title: "Issue-candidate batch re-files duplicates on skill re-run"
status: open
priority: medium
labels: [candidate-batch, consistency, dedup]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-23T10:43:52Z
updated: 2026-06-23T10:43:52Z
origin: conversation
---

## Description

The spec-018 end-of-phase **issue-candidate batch** has no dedup against
issues it already filed. When a surfacing skill runs a second time over the
same artifact, the batch re-derives the same findings and proposes them as
fresh issue candidates. Under `auto_issue_file = "true"` they are silently
re-filed, producing duplicate issue files; the interactive path lets the
developer skip them, so the risk is concentrated in the auto path.

This is a gap in the **shared** issue-candidate contract, not one skill's
bug — it applies to all seven surfacing skills. It surfaced via `/jim:review`
because review is the skill that *explicitly* supports re-runs (it overwrites
`review.md`, latest verdict wins), so re-running review re-fires the
issue-candidate batch every time.

**Proposed direction** (the contract owns the fix, so it lands once for all
surfacing skills — see also [[20260620-single-source-the-interactive-candidate-batch-ux-into-the-shared]]):

- *Origin-scoped dedup* — before filing, skip an issue candidate whose title
  already exists among open issues carrying this artifact's `origin`. Cheap;
  fuzzy on reworded titles.
- *Filed-issue back-references* — record filed issue ids in the producing
  artifact (e.g. a `filed_issues:` list) and skip candidates already there.
  Precise; gives review→issue traceability for mining; the artifact's
  overwrite-on-rerun must merge, not clobber, the list.
- *Global slug-existence dedup* in the shared emitter. Central; slug-exact
  only.

**Action:** add a dedup step to the shared issue-candidate batch contract so a
skill re-run does not re-file issue candidates it already filed.
