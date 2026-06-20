---
num: 10
id: 20260620-architecture-md-hand-edits-bypass-jim-arch-and-stale-the-header
title: "ARCHITECTURE.md hand-edits bypass /jim:arch and stale the header"
status: open
priority: medium
labels: [arch, workflow]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-20T11:43:15Z
updated: 2026-06-20T11:43:15Z
origin: conversation
---

## Description

`ARCHITECTURE.md`'s header declares it *generated and maintained by `/jim:arch` —
edit via the skill to preserve consistency*, and carries a `*Last updated: <date>*`
stamp. But a full `/jim:arch` regen is heavy (it rewrites a 300+ line document and
risks drift in unrelated sections), so small architectural updates — notably
`/jim:build`'s completion-gate arch refresh (Step 6.2) — tend to be made as surgical
hand-edits instead. Those hand-edits bypass `/jim:arch`: they do not bump the
`Last updated:` stamp and drift from the skill-maintained convention.

**Evidence:** during spec 024's build, a one-sentence hand-edit was made to the
candidate-batch paragraph while `Last updated:` still read `2026-06-17` (3 days stale).

Fix directions (for a spec to decide):

- Give `/jim:arch` a **targeted/surgical update mode** that applies a scoped edit
  *and* stamps `Last updated:` (plus provenance), so small updates are cheap but
  consistent — resolving the heavy-regen-vs-inconsistent-hand-edit tension.
- Or a minimal **header-stamp helper** that any `ARCHITECTURE.md` edit must run.
- Or enforce **skill-only editing** (no hand-edits; the `/jim:build` completion gate
  always invokes `/jim:arch`).

Surfaced during spec 024 work, where the build's completion gate hand-edited the doc.
