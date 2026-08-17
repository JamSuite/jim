---
id: 20260807-read-collection-blobs-in-one-batch-instead-of-one-process-per-en
num: 260
title: "Read collection blobs in one batch instead of one process per entry"
status: open
priority: medium
labels: [issue, performance, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T10:59:34Z
updated: 2026-08-07T10:59:34Z
origin: docs/specs/issue/011-issue-placement/plan.md
---

## Description

## Description

Under a branch placement, `place.sh` materializes the destination collection
before every read and every write. The extraction is deliberately per-entry —
branch content is untrusted, so each tree entry clears a containment gate before
a byte is written, and blobs are read by object name rather than tree path.

That correctness is not in question. The cost is: the loop spawns two processes
per collection entry — one `git cat-file blob <sha>` and one
`jimfile.sh valid-relpath <name>` — so a 250-issue collection costs roughly 500
subprocesses per materialization. `list`, `show`, `stats` and `insights` each
pay it once.

Measured on this build's fixtures, `place.sh mode` (the routing decision, which
every issue-script invocation now makes) costs ~27ms against a ~280ms
`render.sh list`. That part is fine. The materialization loop is the part that
scales with collection size, and it is the one worth fixing before a project
with a large collection turns placement on.

Default placement is unaffected: nothing is materialized when the collection
lives on the working branch.

## Proposed action

Replace the per-entry `git cat-file blob <sha>` with a single
`git cat-file --batch` reader fed the enumerated object names, keeping the
containment gates exactly as they are — the gates run before anything is
written, and batching the *reads* does not weaken them.

The `valid-relpath` call is the second half. It is one of three gates (flat
name, `valid-relpath`, `realpath` containment) and the cheap inline checks
already subsume it for single-segment names, so the options are either to fold
it into the batch loop differently or to accept it. Worth measuring before
changing, since it is a named security boundary and the point of calling it is
that it is the project's one spelling of that rule.

## Notes

Binary-safe parsing of `--batch` output in pure bash is the real work here — the
format is length-prefixed, and the no-third-party-deps rule means no `jq`-style
helper. That is why this was not folded into the original build.
