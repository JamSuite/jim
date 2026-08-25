---
id: 20260823-sweep-config-keys-and-migrate-subcommands-against-their-referenc
num: 363
title: "Sweep config keys and migrate subcommands against their references"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [tooling, docs, testing]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:21:48Z
updated: 2026-08-25T07:16:04Z
origin: "docs/specs/issue/013-recorded-identity-schemes/review.md"
---

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

## Resolution (2026-08-25)

Both sweeps landed in `16f6815`, derived from code rather than transcribed.

**Migrations.** `case_docsurfaces_migration_commands_are_documented` reads each
script's own usage text and requires a row in the feature doc's Migrations table
for every subcommand it advertises — and, in the other direction, requires every
row to name a subcommand that still exists. Usage rather than the dispatch table
is deliberate: `migrate.sh` dispatches an internal primitive it does not
advertise, and what the operator is told exists is what the table owes a row.

**Config keys.** `case_docsurfaces_config_keys_are_documented` walks
`jimconf.sh keys` and requires each key in README's tables and in
`jimconf.toml.example`, plus the issues feature doc for the `issue*` and
`identity*` families. It accepts the three shapes the tables really use: the CLI
name, the TOML name the resolver derives for path-valued keys, and a family row
such as `health_threshold_<signal>` that documents five keys at once. The family
prefixes are read out of the document rather than guessed by splitting the key,
because `faces_max` and `breaking_runs` carry underscores of their own.

Each direction was mutation-checked: dropping the `schema` row, adding a row for
a subcommand that does not exist, and dropping `identity_scheme` from README each
turn the relevant case red, and the corpus is green with all three restored.

## What the census added

The drift this issue reported has since been repaired by the documentation pass,
so both sweeps are regression guards rather than repairs. Censusing for the rule
rather than the reported instances found two more:

**A fourth hand-enumerated roster.** The allocator's verbs reach the operator
surfaces through a list written into the test itself, so a *new* verb is invisible
to it — the same omission class, one level up. It is not derivable as the others
are, because the script does not distinguish its hand-run verbs from the ones
other scripts call. Filed as
[[20260825-allocator-verb-sweep-is-hand-listed-not-derived]].

**A stale roster inside the code.** `jimalloc.sh`'s header enumerates the
allocator's commands and stopped at `catch-up`, so `lift` was absent from the
first roster a reader of the script meets. Corrected in `ec97331` — and it is the
concrete evidence that the un-derived sweep above cannot see a new verb, since
nothing caught this one.

The third candidate this issue named — a skill's `allowed-tools` grant against
the scripts its body instructs — is already swept by
`case_docsurfaces_issue_grant_covers_the_scripts_it_instructs`.
