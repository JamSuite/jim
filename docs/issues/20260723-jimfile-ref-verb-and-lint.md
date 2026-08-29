---
id: 20260723-jimfile-ref-verb-and-lint
num: 94
title: "Extend jimfile.sh with a reference ref-verb, anchor resolution, and a bare-reference lint"
status: open
priority: low
type: issue
filed-by: "dorsma"
claimed-by: ""
outcome: ""
labels: [enhancement, jimfile, references]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-23T20:18:03Z
updated: 2026-07-23T20:19:05Z
origin: docs/brainstorms/20260720-claude-speak.md
---

## Description

## Problem

Cross-references in jim artifacts are often terse and unresolvable (`#13`, "spec 004", "Task 2"), costing the reader a lookup. `brainstorms/20260720-claude-speak.md` §4.0a adds a reference-convention table to the writing rule — the primary mechanism, since references are emitted inline while writing. This issue tracks the *tooling* that assists, filed separately because it touches `scripts/` and the claude-speak initiative is prose-only.

## Scope — extend `skills/file/scripts/jimfile.sh`

`jimfile.sh` already turns components→path (`path <kind> <args>`). Add:

1. **`ref <path>` → `<relpath> (<title>)`** — deterministic title extraction from the H1 / frontmatter, so a reference's `(title)` is never drifted or hallucinated.
2. **Anchor resolution: `ref <path> --anchor "<heading text|number>"` → `<relpath> §<n> (<heading text>)`** — resolve headings (`^#{1,6} `) and tasks (`- [ ]`) via grep/sed. POSIX, no third-party deps (jim's bash constraint). The emitted anchor carries the heading text, since markdown has no native anchor ids.
3. **Reference lint** — scan a doc and flag bare `#num`, numberless `§n`, and bare "spec NNN" references so they get fixed.

## Notes

- The convention itself lives in `skills/meta-skill/SKILL.md` § Writing style (per `brainstorms/20260720-claude-speak.md` §4.2). This tooling assists title lookup and validation, not inline emission.
- Needs meta-test coverage under `skills/meta-test/`, following the testlib conventions.
- Reference: `brainstorms/20260720-claude-speak.md` §4.0a Reference conventions.
