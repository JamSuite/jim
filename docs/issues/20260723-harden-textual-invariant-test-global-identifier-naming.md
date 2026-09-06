---
id: 20260723-harden-textual-invariant-test-global-identifier-naming
num: 89
title: "Harden textual-invariant test global-identifier naming"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [test, meta-test, tech-debt]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T10:23:59Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/022-blueprint-present-tense/plan.md
---

## Description

## Context

During spec 050's build, `tests/presenttense.sh` was authored by mirroring
`tests/gatepresentation.sh` (the documented template). Both declared the same
file-level globals — `TOKEN`, `RULE_DOC` — and helper `token_count`. The
aggregate runner (`skills/meta-test/scripts/run.sh`) sources every `tests/*.sh`
into one shell, so the alphabetically-later file (`presenttense.sh`) clobbered
those globals at source time, and `gatepresentation.sh`'s cases then read the
wrong token/doc and failed. Standalone runs passed, masking it until the
full-suite task.

## Resolution applied

`tests/presenttense.sh` was given `PT_`-prefixed identifiers (`PT_TOKEN`,
`PT_RULE_DOC`, `pt_token_count`) so it no longer collides. The full suite is
green (692/692).

## Remaining work

`tests/gatepresentation.sh` still uses unprefixed generic globals, so a *third*
textual-invariant test copied from it as a template would collide again. Harden
the pattern: either prefix `gatepresentation.sh`'s file-globals too, or add an
explicit rule to `skills/meta-test/scripts/testlib.sh`'s Design Contract that
textual-invariant test files must give file-level globals a file-unique prefix
(the per-script `run_*` invoker convention already implies this for functions;
extend it to globals). Low priority — only bites when a new such test reuses the
generic names.
