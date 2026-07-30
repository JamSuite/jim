---
id: 20260730-two-defects-in-the-spec-citation-sweep
num: 160
title: "Two defects in the spec citation sweep"
status: open
priority: high
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T19:35:08Z
updated: 2026-07-30T19:35:08Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/review.md
---

## Description

The citation sweep in `skills/spec/scripts/reconcile.sh` (`:306-387`) rewrites
provisional spec references across the docs corpus when an identity is realized.
Its boundary matrix is sound — same-day siblings, prefix/suffix neighbours and
case variants all behave — but two defects sit inside it.

## 1. The fence tracker is char- and length-blind (live today)

`:349` toggles on any line whose first non-blank characters open a fence — three
backticks or three tildes — and flips a single boolean. Consequences:

- a 4-backtick outer fence is closed by the first inner 3-backtick fence, so the
  inner block is treated as **live prose and rewritten**;
- a `~~~` line inside a backtick block toggles it;
- an unclosed fence silently skips the remainder of the file.

This is not hypothetical — the 4-backtick-wrapping shape exists in the swept
roots right now:

- `docs/issues/20260531-wikilink-parser-skips-fenced-code-blocks.md`
- `docs/specs/blueprint/009-verify-contracts/plan.md`
- `docs/specs/blueprint/007-verify-engine/plan.md`
- `docs/brainstorms/20260512-jim-howtos.md`

jim already ships **two** correct trackers that record the opening marker and
close only on a ≥-length run of the same character:
`skills/*/scripts/migrate.sh:338-345` and `skills/issue/scripts/index.sh:219-245`.
This is a third implementation that is weaker than both.

**Fix:** reuse one of the existing trackers rather than maintaining a third.

## 2. The path-vs-typed replacement pick drops the slug

The pick keys on whether the character *before* the token is `/`. In the
partition precedent that signal only **labels** the record — the replacement is
identical either way and the `-slug` tail survives. Here the source token
consumes the whole slug, so a path citation whose group is the first segment:

    [x](sdlc/P-20260728-alpha/spec.md)

picks the **typed** replacement and yields `sdlc/017/spec.md` — a dead link.

Latent today only because every citation in the corpus goes through
`docs/specs/…`, which puts a `/` before the group as well.

**Fix:** decide by whether a `/` *follows* the token too, or match the path form
explicitly with its trailing separator.

Surfaced by `sdlc/017`'s post-build review (the `major-drift` pass of
2026-07-30).
