---
id: 20260823-sweep-config-keys-and-migrate-subcommands-against-their-referenc
num: 363
title: "Sweep config keys and migrate subcommands against their references"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [tooling, docs, testing]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:48Z
updated: 2026-08-23T23:21:48Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

## Description

## Description

`tests/docsurfaces.sh` already has an introduction-sweep that checks
`jimledger.sh`'s verbs are documented. That pattern was never extended to
`migrate.sh`'s subcommands or to `jimconf.sh`'s key list, so a new verb or a
new key can ship undocumented with no test failure.

## Evidence that this is a live gap, not a hypothetical

The same hole has now swallowed two increments in a row, silently:

- `migrate.sh schema` shipped and never reached `docs/features/issues.md`'s
  Migrations table, which still says "Four one-shot, opt-in commands"
- `migrate.sh identity` shipped in the following increment and did the same
- `identity_scheme` and `identity_domain` shipped and never reached
  `README.md`'s otherwise-exhaustive "Supported keys" table

The identity-key omission was caught by a human reading `jimconf.toml.example`
during build preparation. Nothing mechanical would have caught it, and the
`README.md` half was missed anyway.

## Direction

Two sweeps, both modelled on the existing `jimledger.sh` verb check:

- `migrate.sh`'s dispatched subcommands against the Migrations table in
  `docs/features/issues.md`
- `jimconf.sh keys` against the config tables in `README.md` and
  `docs/features/issues.md`, and against `jimconf.toml.example`

A skill's `allowed-tools` grant against the scripts its own body instructs is a
third candidate of the same shape — see the separate issue on the `issue`
skill's grant.

Preferring a mechanical check here over remembering to update three documents
is the same trade the project already made for ledger verbs.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 14.
