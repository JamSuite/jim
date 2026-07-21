---
id: 20260721-narrow-rewrite-identity-dotted-key-and-typed-ref-over-match
num: 77
title: "Narrow rewrite-identity dotted-key and typed-ref over-match"
status: closed
priority: low
labels: [046, rewrite-identity, hardening]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-21T05:45:35Z
updated: 2026-07-21T19:39:01Z
origin: docs/specs/jim/046-spec-migration/review.md
---

## Description

## Finding (from review of spec jim/046)

The `rewrite-identity` verb's mechanical rules can over-match a few non-identity
tokens in a numbered spec body:

- The dotted-key rule rewrites any whole-token `<old>.<lower-alnum>` — so a
  literal `cart.json` / `cart.py` (a filename, not a `group.surface` dotted-key)
  would be rewritten to `checkout.json`.
- Non-`group:` frontmatter lines fall through to the body token scan, so a
  `cart/001`- or `cart.x`-shaped value in a frontmatter field other than
  `group:` would be rewritten.

All such edits stay within the worktree (a substance-fidelity edge, never a
containment breach) and are surfaced to the developer as a scrubbed old→new diff
at the rename gate before commit (AC 12), which is the safety net.

## Suggestion

Consider narrowing the dotted-key rule (exclude a known file-extension suffix
set, or require the surface half to look like a provides-surface) and/or scoping
the body token-scan to skip non-`group:` frontmatter lines. Note the tradeoff:
frontmatter's only identity field is `group:` (handled explicitly), so scoping
the token-scan out of frontmatter is low-risk; the body-prose `cart.json` case is
harder to disambiguate mechanically and is intentionally left to the gate.

Origin: docs/specs/jim/046-spec-migration/review.md (Finding 1)
