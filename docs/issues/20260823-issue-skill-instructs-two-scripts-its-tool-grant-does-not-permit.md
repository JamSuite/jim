---
id: 20260823-issue-skill-instructs-two-scripts-its-tool-grant-does-not-permit
num: 368
title: "Issue skill instructs two scripts its tool grant does not permit"
status: open
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, sdlc, tooling]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:27Z
updated: 2026-08-23T23:45:27Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

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
