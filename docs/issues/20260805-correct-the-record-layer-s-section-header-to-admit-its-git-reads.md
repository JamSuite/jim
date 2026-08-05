---
id: 20260805-correct-the-record-layer-s-section-header-to-admit-its-git-reads
num: 220
title: "Correct the record layer's section header to admit its git reads"
status: open
priority: medium
labels: [id-coordination, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:48Z
updated: 2026-08-05T01:53:48Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

Issue #216's proposed action was two clauses joined by "then": move the sanitizer
into the record layer, **"then make the section header state what is true. A
header that describes a purity the code does not have is worse than no header,
because it is what the next editor reasons from."**

Clause one shipped, and shipped well. `alloc_sanitize_field:158` is a genuine
record-layer primitive — its body calls only `printf`/`tr`/`cut` with zero
function dependencies, all 18 call sites are at line ≥ 432 (strictly downward),
the section's upward dependencies dropped from three to two, and behavior is
byte-identical across 16 hostile inputs before and after the move.

Clause two was never done. `skills/file/scripts/jimalloc.sh:76` still reads:

```
# ─── Section: Record layer (pure — operates on a log, no git) ────
```

That is false. `alloc_read_log:123` is inside the section and forks git —
`git cat-file -p` at `:135`, demonstrated with a PATH shim:

```
GIT-FORKED: git check-ref-format refs/heads/jim/registry
GIT-FORKED: git cat-file -p refs/heads/jim/registry:specs.log
```

It also holds two upward calls into the git-plumbing section: `:134` →
`alloc_coord_branch` (`:1885`) and `:1057` → `alloc_config` (`:1830`). The
section's own comment at `:122` says "the coordination branch via git plumbing",
contradicting its header 46 lines above.

`git log -L 76,76 175047c..HEAD` is empty — the line was never touched by the
range.

So the issue filed about a header claiming a purity the code lacks left the header
claiming a purity the code lacks.

Nothing pins the layering either: `60df938` touched no test file, and moving the
14-line block verbatim back beside `alloc_display_field` leaves `tests/jimalloc.sh`
at 305/305.

Minor, related: the old comment's clause "Applied on emission to every field,
including those that already crossed the id boundary" was dropped, but that
behavior still exists at `:2834-6` and `:3709-3741`. An omission rather than an
overclaim.

## Proposed action

Rewrite the section header at `:76` to state what the section actually is — it
operates on a log and reads the coordination branch through git plumbing — or
move `alloc_read_log` out of it, whichever reflects the intended boundary.

Consider whether a layering assertion is worth a fixture at all; today the only
thing preventing the sanitizer drifting back upward is that someone would have to
notice.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 11).
