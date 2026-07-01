---
id: 20260627-read-verb-list-creates-a-stray-directory-from-a-non-filter-arg
num: 18
title: "Read-verb list creates a stray directory from a non-filter arg"
status: open
priority: low
labels: [issue, cli]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-27T05:13:33Z
updated: 2026-07-01T08:13:10Z
origin: conversation
---

## Description

`render.sh list <arg>` interprets any single argument that is not a filter
token (`open|closed|critical|high|medium|low`) as the optional `<dir>`
positional (render.sh:331). When a user mistypes an issue reference — e.g.
`/jim:issue list 17`, meaning issue #17 — the arg `17` becomes the issues
directory. `ensure_index` then calls `index.sh 17`, which `mkdir -p`s the path
(index.sh:280) and writes an empty `17/INDEX.md`.

The result: a deterministic *read* verb silently creates a junk directory on
the filesystem, contradicting render.sh's own "read-only" header contract.

Proposed fix:
- Root (index.sh): a read-triggered index regen must not `mkdir -p` a
  non-existent directory. If the issues dir is absent there are no issues —
  emit the empty view and create nothing. Directory creation belongs in the
  write path (new.sh), not in regen reached from a read.
- Defense-in-depth (render.sh cmd_list): a lone argument that is neither a
  valid filter token nor an existing directory should error as an unknown
  filter (the error path at render.sh:333-335 already exists) instead of
  silently adopting it as a new `<dir>` to create.

Add a bash regression test under skills/issue/scripts that asserts a read over
a non-existent dir creates nothing.

Surfaced while running `/jim:issue list 17` during this session.

## Note (2026-07-01): second trigger via direct index.sh + relative default

The same `mkdir -p` (index.sh:280) also fires without any `list` arg. Running
`index.sh` with no directory argument resolves its target from
`jimconf.sh get issues`, whose default is the **relative** `./docs/issues/`.
Invoked from a CWD other than the repo root — e.g. from inside `docs/issues/`
itself — that relative path resolves to `docs/issues/docs/issues/`, and
`mkdir -p` silently creates the stray nested tree plus an `INDEX.md` inside it,
while the real `docs/issues/INDEX.md` goes un-refreshed. Observed this session
when regenerating the index after an issue edit.

This reinforces that the fix belongs at the **root** (index.sh must not create
its target dir on a regen — an absent dir means no issues, so emit nothing and
create nothing). The render.sh cmd_list defense-in-depth would not catch a
direct `index.sh` invocation, so it cannot be the sole fix.
