---
id: 20260801-rewrite-the-realized-spec-s-own-h1-identity-token
num: 199
title: "Rewrite the realized spec's own H1 identity token"
status: open
priority: medium
labels: [sdlc, spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T21:23:36Z
updated: 2026-08-01T21:23:36Z
origin: conversation
---

## Description

## Description

The spec template composes its first heading as `# {id} {title}`, so a spec
scoped offline opens with the bare provisional token:

    # P-<date>-<slug> <title>

Realization rewrites the frontmatter `id:` and sweeps citations in their
typed (`<group>/P-<token>`) and path forms — but the H1's copy is the bare
token with no slash and no group prefix, so it matches neither pattern and
survives realization. Every spec scoped under a provisional identity realizes
with a stale heading.

## Observed

First production spec-side realize (2026-08-01, `platform/012`): frontmatter
came back `id: "012"`, the H1 still read
`# P-20260801-registry-integrity-and-drift Registry integrity and drift`.
Repaired by hand.

## Proposed action

Treat the realized spec's own H1 leading token as a self-identity site, like
the frontmatter `id:` — the realizer rewrites `# <P-token>` to the realized
ordinal in that one file. This keeps the global sweep grammar unchanged
(a bare token is ambiguous everywhere else; the spec's own first heading is
not).
