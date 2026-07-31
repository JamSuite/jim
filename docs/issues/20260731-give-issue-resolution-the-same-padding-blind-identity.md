---
id: 20260731-give-issue-resolution-the-same-padding-blind-identity
num: 182
title: "Give issue resolution the same padding blind identity"
status: open
priority: medium
labels: [file, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:31Z
updated: 2026-07-31T12:39:31Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

The spec side now treats two spellings of one ordinal as one identity. The issue
side does not, and one ingestion path can create the split.

`alloc_seed_derive_issues` emits the frontmatter `num` **verbatim**
(`skills/file/scripts/jimalloc.sh:884,893`), while the spec seed normalizes with
`%03d` (`:836`). A hand-authored `num: 007` therefore seeds
`issue allocate 007 …`. The fold counts it as 7 via `10#` (`:451`) and the seed's
dedupe key is numeric (`:876,882`), but `alloc_resolve_issue` compares as strings
(`:292,295,304`) — so `resolve issue 7` reports "not allocated" while `peek issue`
reports 8.

## Assessment

Out of the coordinated-identity remediation's scope, which was explicitly scoped
to spec ordinals: issue ordinals are conventionally unpadded and no
allocator-minted padding variant exists. But it is the identical defect class just
closed on the spec side, reachable through the bootstrap.

## Fix

Either normalize `num` in `alloc_seed_derive_issues` the way the spec seed does,
or give `alloc_resolve_issue` the same numeric comparison the spec resolver now
has. Normalizing at the seed is the narrower change.

Surfaced by an investigator during the post-build review of `sdlc/018`.
