---
id: 20260818-transition-verbs-silently-ignore-as-when-it-does-not-apply
num: 354
title: "Transition verbs silently ignore --as when it does not apply"
status: open
priority: medium
type: issue
filed-by: "git@jrko.org"
claimed-by: ""
outcome: ""
labels: [issue, cli, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-18T22:03:41Z
updated: 2026-08-18T22:03:41Z
origin: "docs/specs/issue/012-schema-and-state-model/plan.md"
---

## Description

## Context

`transition.sh` accepts `--as <outcome>` for every verb, but only `close`
consumes it. The value is validated against the outcome enum before anything
is written, so a misspelling is caught — but a *well-formed* outcome passed to
a verb that has no use for it is accepted, ignored, and reported as success:

    transition.sh claim <id> --as wontfix
    → exit 0, claimed-by set, outcome untouched

## Why it matters

The developer asked for two things and got one, with nothing said about the
other. Silence here reads as confirmation: the exit status is 0 and the issue
did change, so there is no signal that half the request was dropped.

It is most likely to bite where the mistake is easiest to make — reaching for
`close --as wontfix`, typing `release` or `reopen` instead, and believing the
outcome was recorded. The record then disagrees with what its author thinks it
says, and nothing downstream can detect that, because an outcome that was never
written is indistinguishable from one that was never asked for.

This is the same class of defect as a stamp refresh that silently fails to move
a field it cannot find, which this script already refuses rather than reporting
success.

## What

Refuse `--as` on a verb that does not record an outcome, at the usage-error
exit code, before anything is written — matching how an unrecognized outcome is
already treated.

Worth deciding at the same time whether `--force` deserves the same treatment.
It is meaningful to `claim`, `release` and `start`, and inert on `close` and
`reopen`, so it has the same shape of problem with a smaller consequence.

## Constraints

- The check belongs beside the existing outcome-enum validation, which already
  runs before the placement door opens and before any file is read.
- Refusals stay fixed reason codes carrying no issue content.
