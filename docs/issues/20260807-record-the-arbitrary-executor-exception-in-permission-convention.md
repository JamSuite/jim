---
id: 20260807-record-the-arbitrary-executor-exception-in-permission-convention
num: 275
title: "Record the arbitrary-executor exception in permission conventions"
status: closed
priority: low
labels: [docs, architecture, permissions]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:59Z
updated: 2026-08-12T09:15:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`ARCHITECTURE.md`'s Permission Conventions state:

> a skill that consumes only one verb of a multi-verb script may scope its
> clause tighter still — to that verb... **A skill that needs several of a
> script's verbs keeps the script-level clause.**

and describe `/jim:plan`'s grant as "the first such verb-scoped grant".

`/jim:issue` now uses three verbs of `place.sh` and carries three verb-scoped
clauses rather than one script-level clause, which the rule as written does not
permit. The choice is correct and should not be reverted: `place.sh run` is an
arbitrary-command executor (`exec "${PLACE_CMD[@]}"`), so a script-level
`place.sh *` grant would be a de facto `Bash(*)`. Withholding `run` and `mode`
from the skill's grant is the security-correct outcome.

What is missing is the record. The convention does not name the exception — "a
verb that executes arbitrary commands is never script-level-granted" — and still
calls `/jim:plan`'s the first verb-scoped grant when there is now a second, with
a different and stronger rationale.

## Proposed action

Extend Permission Conventions through `/jim:arch` (not by hand — the skill owns
that file's currency) to record the second precedent and the arbitrary-executor
exception, so the next author scoping a grant against a multi-verb script has
the rule rather than having to rediscover the reasoning.

## Resolution (backfilled 2026-08-12)

*Closed in `c4b5940` with the note "Resolved in the same pass that filed it" and
no record of what shipped; this reconstructs it.*

The exception is recorded in `ARCHITECTURE.md`'s Permission Conventions, in the
sentence carrying the script-level rule: a skill needing several of a script's
verbs keeps the script-level clause **unless the script carries a verb that
executes caller-supplied commands, in which case a script-level grant is never
taken**. `/jim:issue` is named as that case — three verb-scoped clauses over
`place.sh begin` / `commit` / `abort` rather than one `place.sh *`, because
`place.sh run` ends in `exec` over a caller-supplied command and a script-level
grant would be a de facto `Bash(*)` — and the rule is generalized: enumerate the
verbs when the withheld ones include an executor, since the cost of several
clauses is bounded and the cost of granting an executor is not.

The shipped wording is "executes caller-supplied commands" rather than this
issue's "arbitrary-executor", which is why the phrase this issue proposed does
not appear in the file.

The second half of the ask — that the text stop presenting `/jim:plan`'s as *the*
verb-scoped grant when a second exists — is met in substance rather than by
deletion: the sentence still calls it the first, which is chronologically true,
and now describes the second precedent and its stronger rationale immediately
after, so a reader scoping a grant against a multi-verb script meets both.
