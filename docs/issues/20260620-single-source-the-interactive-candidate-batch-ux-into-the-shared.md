---
id: 20260620-single-source-the-interactive-candidate-batch-ux-into-the-shared
num: 11
title: "Single-source the interactive candidate-batch UX into the shared contract"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [refactor, candidate-batch, consistency]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-20T23:31:27Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/issue/009-issue-candidate-batch-extraction/plan.md
---

## Description

Spec 025 single-sourced the candidate-batch **filters** and the **file-write** mechanism (`new.sh`), but the interactive batch UX remains copy-pasted across the seven surfacing skills (`/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:build`, `/jim:brainstorm`, `/jim:debug`, `/jim:sec`): the numbered, default-checked checkbox render; the `file all` / `skip all` bulk actions; and the per-row `f` / `e` / `s` overrides (~15 lines each).

Spec 025 consciously scoped this out — its Out of Scope excluded *scripting* the interactive confirm/checkbox/per-row-edit flow (it is LLM-prompt conversation logic, per the Bash-vs-Prompt rule), **not** single-sourcing the prose. Moving the interactive UX into `skills/issue/SKILL.md` § 7a (Candidate-batch contract) as shared prose, referenced by a brief pointer in each skill, would finish paying down the duplication issue #8 identified — leaving only the skill-specific *materialize* prose inline.

Follow-on to spec 025 / issue #8. Low priority: the load-bearing logic (filters, write mechanism, fileable bar) is already single-sourced; this is the residual UX prose.
