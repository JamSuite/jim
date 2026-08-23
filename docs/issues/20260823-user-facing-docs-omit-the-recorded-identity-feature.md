---
id: 20260823-user-facing-docs-omit-the-recorded-identity-feature
num: 364
title: "User-facing docs omit the recorded-identity feature"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [docs, readability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:47Z
updated: 2026-08-23T23:21:47Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

A project can now choose the form every recorded contributor identity takes,
and no user-facing document says so.

## What is missing

**`README.md`** — the "Supported keys" table lists every other configuration
family, including the dynamic-suffix ones. It has no row for `identity_scheme`
or `identity_domain`. A user scanning that table for how to control what a
filer looks like will not find it.

**`docs/features/issues.md`** — the canonical feature document:

- the Configuration table omits both keys
- the Migrations table says "Four one-shot, opt-in commands" and lists neither
  `migrate.sh schema` (missing since the schema conversion shipped) nor
  `migrate.sh identity`
- the example frontmatter block still shows no `type`, `filed-by`,
  `claimed-by` or `outcome` fields at all
- nothing mentions the new integrity warning, even though the warning's own
  text tells the reader to run `migrate.sh identity --renormalize` — a command
  this document never explains

**`skills/issue/SKILL.md`** — documents `migrate.sh schema` and nothing about
identity. This one was a declared Out of Scope item in the plan, deferred so it
could land with the tool-grant fix rather than be scattered across two changes.
It is named here for completeness, not as a surprise.

## Why it matters

`jimconf.toml.example` documents both keys correctly, so the feature is
discoverable to someone who already suspects it exists. Nothing leads a reader
there. The effect is a setting that silently governs several hundred records
with no path to finding it.

## Direction

`README.md` and `docs/features/issues.md` are the two that were simply missed.
The `SKILL.md` half belongs with the tool-grant fix.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Findings
6 and 7.
