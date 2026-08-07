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
updated: 2026-08-07T11:45:28Z
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
