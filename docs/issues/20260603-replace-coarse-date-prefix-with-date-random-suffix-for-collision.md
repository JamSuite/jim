---
num: 6
id: 20260603-replace-coarse-date-prefix-with-date-random-suffix-for-collision
title: "Replace coarse date prefix with date+random suffix for collision-safe issue ids"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, id-scheme]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-06-03T00:00:00Z
updated: 2026-06-03T00:00:00Z
origin: docs/brainstorms/20260603-issue-command-consolidation.md
---

## Description

### The observation

Spec 017 chose the `YYYYMMDD-slug` filename scheme for "collision-tolerance
under parallel feature branches / multi-agent worktrees." On review, the
day-resolution date prefix barely serves that goal: two branches each creating
`20260603-fix-login.md` collide identically on merge — the date only avoids
collision when the *slugs* differ. The 018 `-2`/`-3` discriminator handles
same-branch collisions but cannot help across unmerged branches (each branch
independently picks `-2`).

The date's genuine value is chronology + provenance + reducing same-slug
collisions to same-*day*-same-slug. That is weak collision avoidance, not the
cross-branch safety it was framed as.

### Proposed action

Add a short random component to the filename so the id is genuinely
collision-safe under decentralized/parallel creation, while preserving
chronological sort and provenance:

```
20260603-a3f9-auth-swallow-401.md
        ^^^^ short random (e.g. 4-char base32)
```

Implementation touches `jimfile.sh next-id issue` (compose date + random +
slug). The change is to the **reference key / filename scheme**, so it must be
weighed against backward compatibility with the existing collection and any
`relations:` / `[[wikilink]]` references that key off the current id form.

### Why deferred

Surfaced during the issue-command-consolidation brainstorm
(`docs/brainstorms/20260603-issue-command-consolidation.md`). The collision
scheme is orthogonal to the command-surface consolidation (verbs, `show`
resolver, `num:` display ordinal); folding it in would mix two concerns. The
brainstorm decided to keep `date+slug` for that round and capture the scheme
change here. Low priority — the current scheme is adequate for the
single-developer threat model that 017/018 assume.
