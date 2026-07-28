---
id: 20260728-remove-spec-id-citations-from-issue-group-script-comments
num: 131
title: "Remove spec-ID citations from issue-group script comments"
status: open
priority: low
labels: [test, convention]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T21:39:32Z
updated: 2026-07-28T21:39:32Z
origin: docs/specs/issue/010-ordinal-coordination/review.md
---

## Description

Four new comments in the issue-group scripts cite artifact IDs, violating the
CLAUDE.md "no spec IDs (or Finding/AC/DD numbers) in comments" rule:

- `new.sh` (~:157) cites `AC5`
- `reconcile.sh` (~:89) cites `Finding 5`
- `render.sh` (~:314 and ~:510) cite `spec 010 AC 9`

This is a pre-existing systemic pattern, not new to `issue/010`: `new.sh`
already carries ~7 spec-025 citations and `render.sh` ~6 for specs 019/020/021.
Comments should state current behavior and its rationale — not provenance — and
spec IDs are especially fragile here because the `rename`/`split` verbs
renumber the very specs an ID points at.

## Fix

Best fixed as a one-pass issue-group comment-provenance cleanup across `new.sh`,
`reconcile.sh`, and `render.sh`: strip artifact-ID citations, keeping any
behavioral rationale. This finding drove the `issue/010` review's `minor-drift`
verdict.
