---
id: 20260730-document-provisional-spec-identity-and-the-reconcile-surface
num: 147
title: "Document provisional spec identity and the reconcile surface"
status: open
priority: medium
labels: [docs, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:16Z
updated: 2026-07-30T19:35:16Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

`sdlc/017` shipped provisional spec identity and the `/jim:spec reconcile`
surface, but the user-facing docs still describe the world before it. Only
`ARCHITECTURE.md` refreshes through the pipeline; everything below needs a human
pass.

- **`WORKFLOW.md`** — implies a spec id is always numeric, and documents neither
  the provisional mode nor the reconcile surface. A developer working offline
  has no documented account of what `/jim:spec` will do or how to finish the job
  later.
- **`README.md`** — same numeric-id framing.
- **`skills/spec/assets/spec-template.md:5`** — the template a new spec is
  materialized from still implies a numeric `id`.

The gap that matters most is the reconcile surface: an offline session now
produces a spec whose identity is provisional, and nothing outside the skill body
tells the developer that a later `--apply` run is required, what it renames, or
what happens to citations.

Distinct from
[[20260725-refresh-architecture-readme-workflow-for-the-partition]], which is the
partition-era pass over the same three documents, and from
[[20260726-document-coordination-branch-protection-and-team-setup]], which is the
coordination-branch setup story. If those are picked up together, do this one in
the same pass — they touch the same files.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
