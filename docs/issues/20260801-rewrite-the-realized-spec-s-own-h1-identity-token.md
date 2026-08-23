---
id: 20260801-rewrite-the-realized-spec-s-own-h1-identity-token
num: 199
title: "Rewrite the realized spec's own H1 identity token"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [sdlc, spec, scripts, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T21:23:36Z
updated: 2026-08-02T06:52:07Z
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

## Resolution (2026-08-02)

Fixed in the pre-B build (`ad3b28d`), as proposed. `rewrite_id` takes the
identity's own token and retitles the first `# <P-token> …` heading onto the
realized ordinal, in the same pass and the same atomic install as the
frontmatter `id:`. The grammar stays narrow: whole-token match on this
identity's own token only (a sibling differing by a suffix does not match),
first heading only, and a missing heading is not a failure. The global sweep
grammar is unchanged. Fixtured with the suffixed-sibling and bare-mention
discriminators.
