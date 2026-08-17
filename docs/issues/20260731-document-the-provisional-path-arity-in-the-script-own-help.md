---
id: 20260731-document-the-provisional-path-arity-in-the-script-own-help
num: 176
title: "Document the provisional path arity in the script own help"
status: closed
priority: medium
labels: [file, scripts, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:48Z
updated: 2026-07-31T21:28:44Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`cmd_path`'s `spec|plan|research` arm gained a two-argument provisional arity, but
three documentation sites inside the same script still show only the
three-argument form:

- `skills/file/scripts/jimfile.sh:37-39` — the CLI SUMMARY header
- `:920-923` — the `cmd_path` docstring, which enumerates the multi-arg forms
- `:1145-1147` — `usage()`, i.e. what `--help` prints

So `bash jimfile.sh` with no arguments prints a usage block omitting the
provisional form entirely. `ARCHITECTURE.md:390` documents the two-arity contract
correctly and the arm's own inline comment explains it — the gap is the script's
user-facing help.

The sibling `mv-spec-id` documents both forms in its docstring but its `usage()`
entry is likewise four-arg-only, so this is consistent drift across both
two-arity verbs. `skills/file/SKILL.md:31` and `README.md:183` also show only the
three-arg example.

## Fix

Add the provisional arity to the CLI SUMMARY, the `cmd_path` docstring, and
`usage()`; do the same for `mv-spec-id`'s `usage()` entry.

Finding 6 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

Closed by the C′-fix build. All six sites carry the provisional arity: the CLI
SUMMARY, the `cmd_path` docstring, `usage()`, `mv-spec-id`'s `usage()` entry,
`skills/file/SKILL.md`, and `README.md`. `--help` now prints both forms for both
two-arity verbs.

The docstring says what the second form *means* rather than only its shape — the
token is the whole basename, not an ordinal that composes with a separate name —
because the shape alone is what made five call sites each remember an
undocumented rule.

`spec-ordinal-holder`'s `usage()` entry picked up its `--root` option in the same
pass, added for the move-primitive gate.
