---
id: 20260803-keep-the-record-layer-off-the-reporting-layer-s-sanitizer
num: 216
title: "Keep the record layer off the reporting layer's sanitizer"
status: closed
priority: low
labels: [id-coordination, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-03T05:50:29Z
updated: 2026-08-05T10:21:33Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/review.md
---

## Description

`alloc_rename_scan` and `alloc_realize_scan` sit in the section documented as
the pure record layer — "operates on a log, no git", no output concerns. Both
now call `alloc_sanitize_field`, which lives in the reporting layer roughly 2200
lines away.

Nothing is wrong today, and the reason the call drifted down is defensible: a
record field that any consumer might echo wants gating once, at the point it is
read. But the section header still claims a separation the code no longer has,
and that layer's purity is exactly what makes it safe to reuse from a resolver,
two folds, a classifier and two emitters without each caller reasoning about
output.

## Proposed action

Decide which way the boundary goes — move the sanitizer into the record layer as
a shared primitive, or return raw fields and gate at each reporting site — then
make the section header state what is true. A header that describes a purity the
code does not have is worse than no header, because it is what the next editor
reasons from.

## Provenance

Post-build review of the rename/redirect emission spec
(`docs/specs/blueprint/025-rename-redirect-record-emission/review.md`,
Finding 20b). Not filed alongside that review's other follow-ons.

## Partially delivered (2026-08-05)

The proposed action is two clauses joined by "then". The first shipped; the
second did not. Staying open for it.

**Delivered — the boundary was decided and the sanitizer moved.**
`alloc_sanitize_field` is now a genuine record-layer primitive at
`jimalloc.sh:158`: its body calls only `printf`/`tr`/`cut` with zero function
dependencies, and all 18 call sites are at line >= 432, strictly downward. The
section's upward dependencies dropped from three to two. Behaviour is
byte-identical before and after the move across 16 hostile inputs. The function's
own header now checks out line by line against its body.

**Not delivered — the section header still claims a purity the code lacks.**
`jimalloc.sh:76` reads:

```
# ─── Section: Record layer (pure — operates on a log, no git) ────
```

`alloc_read_log:123` sits inside that section and forks git — `git cat-file -p` at
`:135` — demonstrated with a PATH shim. It also holds two upward calls into the
git-plumbing section (`:134` → `alloc_coord_branch`, `:1057` → `alloc_config`).
The section's own comment at `:122` says "the coordination branch via git
plumbing", contradicting its header 46 lines above. `git log -L 76,76` over the
range is empty — the line was never touched.

So the issue filed about a header claiming a purity the code does not have left
that header in place. This issue's own rationale is the reason it matters: it is
what the next editor reasons from.

Nothing pins the layering either — the move touched no test file, and relocating
the block verbatim back beside `alloc_display_field` leaves the suite green.

Minor: the old comment's clause "Applied on emission to every field, including
those that already crossed the id boundary" was dropped, but that behaviour still
exists at `:2834-6` and `:3709-3741`. An omission, not an overclaim.

Source: post-build review of the B-prime cluster,
`docs/notes/20260805-b-prime-review.md` (Finding 11).

## Delivered in full (2026-08-05)

The second clause landed, so this closes with its follow-on. The section header
now states what is true rather than a purity the accessor inside it does not
have, and the boundary is held by a fixture rather than by attention. Details on
the follow-on item.
