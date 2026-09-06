---
id: 20260823-issue-skill-instructs-two-scripts-its-tool-grant-does-not-permit
num: 368
title: "Issue skill instructs two scripts its tool grant does not permit"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, sdlc, tooling]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:27Z
updated: 2026-08-24T19:25:25Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

The `issue` skill's body instructs running two scripts its `allowed-tools`
grant does not permit. Every lifecycle verb and every collection migration is
documented but unauthorized.

## The gap

Granted (`SKILL.md` frontmatter): `jimfile.sh`, `jimalloc.sh peek issue`,
`jimconf.sh`, `index.sh`, `new.sh`, `render.sh`, `reconcile.sh`,
`place.sh begin|commit|abort`, `mkdir`.

Instructed by the body but **not granted**:

- `transition.sh` — the five lifecycle verbs (claim, release, start, close,
  reopen)
- `migrate.sh` — the collection conversion, and now the identity rewrite

No wildcard covers either. A developer following the documented steps hits a
permission prompt for a script the skill itself told them to run.

## Why it was not caught

`tests/docsurfaces.sh` does not police this. Its introduction-sweep covers
`jimledger.sh`'s verbs and a fixed registry list; nothing checks a skill's own
grant against the scripts its own body instructs.

Note for anyone reading an older account of this: `docsurfaces.sh` does **not**
globally skip the `issue` skill. Two of its cases read `skills/issue/SKILL.md`
directly. The skill is excluded only as a *consumer* in the candidate-batch
roster sweeps, correctly, because it owns that contract rather than consuming
it. That exclusion is not the reason this gap survived — the absence of a
grant-versus-body check is.

## Direction

Add both scripts to the grant, scoped to the verbs the body actually uses
rather than a blanket wildcard. Documenting the identity rewrite in the body
belongs with this change: it was deliberately deferred so the two would land
together rather than scattering a new verb into a grant that was already wrong.

A mechanical check of a skill's grant against the scripts its body names is
tracked separately.

## Resolution (2026-08-24)

Fixed in `5978e1d` (the grant) and `136a2a5` (the identity documentation this
issue asked to land with it).

**The two scripts are scoped differently, and the difference is the point.**

`transition.sh` is granted whole. The body uses all five of its verbs and it
has no sixth, so the script-level clause *is* the verb-scoped one — five
clauses would name the same set at five times the width.

`migrate.sh` is granted by subcommand: `schema` and `identity`, the two the
body instructs. Withheld are `prefix`, which renames every file in the
collection and rewrites its inbound references, and `rewrite`, which is a
test-only internal deliberately absent from the script's own usage. Neither is
an executor, which is where this departs from the convention as written —
`ARCHITECTURE.md` § Permission Conventions said a multi-verb consumer keeps the
script-level clause unless an executor is among the withheld. The generalized
rule is recorded there.

**Pinned by `case_docsurfaces_issue_grant_covers_the_scripts_it_instructs`**,
run against the unfixed grant first, where it fails naming both scripts. It
derives the call sites from the body rather than listing them, so a call site
added later is covered; and it asserts the collection-wide rename stays
withheld, so the narrowing is not read as an oversight and widened.

The check is scoped to this one skill on purpose. A grant-versus-body sweep
over every skill is the third candidate named in the mechanical-check issue and
belongs there. Run by hand over all skills during this fix, it found no other
skill with the gap.
