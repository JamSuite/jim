---
id: 20260702-size-issue-slugs-at-derivation-not-truncation
num: 29
title: "Derive appropriately sized issue slugs instead of relying on truncation"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue-tracking, jimfile]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-02T07:25:25Z
updated: 2026-07-02T07:25:25Z
origin: conversation
---

## Description

## Context

Filing an issue with its full long title as the slug subject produced
`20260702-add-violation-vs-fold-fork-and-criticality-graded-autonomy-to-bl`:
`normalize_slug` in `jimfile.sh` hard-caps the slug at 64 chars (`cut -c1-64`),
cutting mid-word and leaving a partial token (`-to-bl`) for the reader to
reason about. The truncation "worked" — the id validated and filed — but the
result needed a manual rename. Truncation should be a last-resort belt, not
the sizing mechanism.

## What

Two-part remedy:

1. **Prompt-level (primary).** The `/jim:issue add` capture step derives a
   *concise slug subject* — a readable handle, not the full title — before
   calling `jimfile.sh next-id issue`, sized so the 64-char cap never engages.
   The title keeps its full wording; only the id shortens. The confirm-or-edit
   moment already displays the resolved id, which catches the misses.
2. **Script-level (belt).** When the cap does engage, `normalize_slug`
   truncates at a word (hyphen) boundary — dropping the trailing partial token
   and any trailing hyphen — never mid-word. Deterministic, testable in
   `tests/jimfile.sh`, and it protects every caller: the candidate batches
   file through `new.sh` with `--title` only, so their slugs are derived from
   full titles and only the belt covers them.
