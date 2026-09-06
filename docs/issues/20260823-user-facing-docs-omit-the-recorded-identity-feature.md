---
id: 20260823-user-facing-docs-omit-the-recorded-identity-feature
num: 364
title: "User-facing docs omit the recorded-identity feature"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [docs, readability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:47Z
updated: 2026-08-24T19:25:54Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

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

## Resolution (2026-08-24)

Fixed across `136a2a5` (the `SKILL.md` half), `dafb06d` (the lifecycle) and
`b84a523` (`README.md` and the feature doc).

**Where this issue under-scoped itself.** The frontmatter block could not be
corrected in isolation. Showing `type`, `filed-by`, `claimed-by` and `outcome`
while no user-facing document names a verb that moves any of them leaves the
doc self-incomplete — so the lifecycle was documented too: the verbs reach the
README command table, `WORKFLOW.md`'s subcommand list and a new feature-doc
section, and `WORKFLOW.md`'s artifact row stops calling the status set
`open`/`closed`.

Two further enumerations in the same documents were stale from the same
increment and are corrected with them: the `list` filter set, which gained
`active`, and the typed relation buckets, which gained `part-of`.

**Two more on the identity half.** The Migrations table needed `migrate.sh
schema` as well as `migrate.sh identity` — it had said "four one-shot commands"
across two increments that each added one. And the index's integrity-warning
enumeration named five classes where the code emits fifteen, including the two
that name this rewrite as their remedy; a reader following the warning to the
feature doc would have found the warning itself undocumented.

The keys reach `README.md`'s table as asked. The feature doc gets a section
rather than two table rows, because the forms are ordered, the mapping runs
before them, and the refusal-versus-default distinction all have to be stated
somewhere for the rows to be safe to act on.
