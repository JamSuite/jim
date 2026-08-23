---
id: 20260726-add-a-per-file-must-each-polarity-to-the-verify-mechanical-floor
num: 109
title: "Add a per-file must-each polarity to the verify mechanical floor"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [verify, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-26T07:09:09Z
updated: 2026-07-26T07:09:09Z
origin: docs/specs/platform/006-script-preamble-conformance/spec.md
---

## Description

## Description

The verify mechanical floor cannot assert a per-file universal property. In `skills/verify/scripts/jimverify.sh`, `check_pattern` with `polarity=must` is *existential* — it holds as soon as the regex matches anywhere in scope (`n > 0`) — and `must-not` is the only universal polarity (holds iff zero matches). Because grep is line-oriented, neither can express "every `*.sh` file in scope has property Y" — e.g. "the first executable line is `set -uo pipefail`". `count=N` exists but is brittle (breaks on any file add/remove or a comment mentioning the string).

Consequence: a class of for-all-files invariants that are mechanically decidable can only verify through the `judge` ceiling. Confirmed instance: `script-preamble` — platform/006 restored it as `judge` backed by a deterministic bash test in platform's own suite, precisely because no floor `pattern` could express it. Other plausible members: `name-matches-path` and the agent-body-budget rule (both currently `judge`).

Proposed action: add a universal per-file polarity to the floor (e.g. `must-each`) that iterates each file under `scope` and requires a per-file regex match, holding iff every file matches. Cover it in `tests/jimverify.sh` and document it in `skills/blueprint/references/check-authoring.md`. Then migrate the for-all-files judge-only invariants (starting with `script-preamble`) from `judge` to the new mechanical polarity.

This is a blueprint-group engine change (`skills/verify` / `jimverify.sh` territory), deliberately kept out of the platform/006 fix to avoid a cross-group straddle. Scope it against the whole invariant class it would upgrade — the value is the generalization, not any single rule; do not fold it into a one-rule fix.
