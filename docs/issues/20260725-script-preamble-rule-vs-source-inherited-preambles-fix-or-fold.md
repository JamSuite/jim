---
id: 20260725-script-preamble-rule-vs-source-inherited-preambles-fix-or-fold
num: 99
title: "script-preamble rule vs source-inherited preambles: fix or fold"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-25T08:04:41Z
updated: 2026-07-26T08:18:02Z
origin: BLUEPRINT.md
---

## Description

The script-preamble rule says every script sets `set -uo pipefail`, but skills/meta-test/scripts/run.sh, tests/jimconf.sh, and tests/jimfile.sh inherit it via `source`/framework instead of setting it themselves. The invariant is withheld from the platform blueprint (fail-closed) until resolved.

Fork: fix the code (add the preamble to the three files) or fold the intent (reword the rule to "sets or sources a preamble-setting framework"). Either way, restore the row to platform's 000-blueprint afterward.
