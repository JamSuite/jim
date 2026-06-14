---
id: 20260613-re-derive-existing-issue-ids-to-active-prefix-scheme
num: 7
title: "Re-derive existing issue ids to the active prefix scheme"
status: open
priority: low
labels: [issue, migration, tooling]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-13
updated: 2026-06-13
origin: docs/specs/jim/021-issue-id-prefix/spec.md
---

## Description

Spec 021 (configurable issue-id prefix) chose **forward-only** behavior: changing
the prefix configuration affects only newly-created issues, and existing ids are
never rewritten. A collection therefore ends up with mixed-scheme ids after a
config change.

This issue tracks the deferred follow-on: a one-shot command that re-derives
existing issue ids to the *active* prefix scheme — renaming the files and
rewriting inbound references (`relations:` targets and `[[wikilinks]]`) so the
collection converges on a single scheme. The hard part is reference-rewrite
safety (no dangling relations, idempotency, collision handling), which is why
021 scoped it out rather than bundling it.

Investigate feasibility and reference-rewrite safety before committing to a
design.
