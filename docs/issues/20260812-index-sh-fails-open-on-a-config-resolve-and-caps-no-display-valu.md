---
id: 20260812-index-sh-fails-open-on-a-config-resolve-and-caps-no-display-valu
num: 310
title: "index.sh fails open on a config resolve and caps no display value"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, index]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:42:08Z
updated: 2026-08-12T09:00:55Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`index.sh` reads the placement key with the fail-open posture `place.sh`
explicitly rejects, and sanitizes the resulting branch name without the corpus's
length cap.

## Mechanism

**Fail-open resolve.** `skills/issue/scripts/index.sh:469-471`:

```
placement="$(bash "$JIMCONF" get issue_placement 2>/dev/null)"
[[ -n "$placement" ]] || placement="branch"
```

The resolver's exit status is discarded and an empty result defaults to `branch`,
which *runs* the origin lint. `place.sh:184-189` takes the explicitly opposite
stance on the same key — "A failed resolve is not an unset key" — and refuses at
rc 2. Consequence is bounded to warning text and never blocks, but the direction
of the fallback is toward publishing the churn the gate exists to prevent, and a
failed resolve makes the index silently claim the lint *was* performed.

This read also applies neither `place_valid_branch` nor the coordination-branch
refusal, so a junk placement value is interpolated into the published warning
line rather than refused.

**Uncapped sanitizer.** `index.sh:476` uses `tr -d '[:cntrl:]\``  — control
characters and backticks, which is markdown-correct — but **no length cap**,
diverging from the house form (`tr -d '\000-\037\177' | cut -c1-512`) used in
`place.sh:331`, `jimledger.sh:83`, `spec/reconcile.sh:125` and
`jimpartition.sh:852`. The value is the config-supplied branch name and it lands
whole in a committed `INDEX.md`.

## Proposed action

Check the resolver's status and refuse rather than defaulting; adopt the capped
house sanitizer.

## Origin

Post-build review of `issue/011`; found by the AC 11, AC 1/2 and conventions
investigators independently. The placement gate itself was made fail-closed
during the remediation; this second reader was not brought along.

## Resolution (2026-08-12)

Fixed in `39661e1`. The resolver's exit status now decides, and a failure refuses
at rc 2 naming the key rather than defaulting to `branch` — which *runs* the
origin lint, so a failed resolve had the published index claim a check it never
performed. The display value adopts the capped corpus sanitizer, which is now the
same `row_safe` every row value clears, plus the backtick stripping the code span
it sits in requires.

This depended on `20260812-jimconf-resolver-can-hand-a-fabricated-default-to-a-caller`:
until the resolver returned a status, checking one was inert.

Pinned by `case_index_refuses_when_the_placement_resolve_fails` and
`case_index_caps_the_displayed_placement_name`. The first passes the directory
explicitly on purpose — with it resolved from config, `resolve_dir` refuses first
and the case would pass without exercising this check at all, which is how the
first version of it went green under neutering.

The finding's third observation stands and is not taken here: this read applies
neither `place_valid_branch` nor the coordination-branch refusal. The value is
display-only on this path and the gate lives in `place.sh`; giving `index.sh` its
own copy would duplicate a boundary rather than move it.
