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
updated: 2026-08-12T09:35:31Z
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

## Note (2026-07-09): third trigger — any read verb via `ensure_index`

Reproduced again, this time through `render.sh show 42` run from inside
`docs/issues/`. No `index.sh` call, no `list` arg — a plain `show`. The chain
is `cmd_show` → `resolve_dir` → `ensure_index` (render.sh:89) → `index.sh`,
and `ensure_index`'s regen inherits the same relative-default + wrong-CWD
resolution as the 2026-07-01 note, so `mkdir -p` (index.sh:280) creates
`docs/issues/docs/issues/INDEX.md` while the real index goes un-refreshed.

The new fact this pins down: the stray dir is reachable from **every read verb**
(`show`, `list`, `stats`), because they all funnel through the shared
`ensure_index` helper — it is not specific to `list`'s arg parsing or to a
direct `index.sh` call. That is the sharpest statement of the "a read verb
violates its own read-only contract" defect, and it further confirms the root
fix (index.sh must not `mkdir` on a regen): a `cmd_list`-only guard cannot cover
the `show`/`stats` paths, which never touch `cmd_list`.

(Also underscores the CWD-relative default as the proximate cause — a read
reached from a non-repo-root CWD mis-resolves the target. Whether the resolver
should anchor the default to the project root is arguably a second, narrower
fix worth weighing alongside the index.sh root fix.)

## Progress (2026-08-12)

**Two of the three triggers are closed** in `c13caa9`, while closing
`20260812-two-argument-read-shape-bypasses-placement-and-creates-a-stray-d`.

- *Trigger 1 — `list <non-filter>`.* `cmd_list` reads its arguments by shape
  and refuses a token that is neither a filter nor an existing directory.
- *Trigger 3 — any read verb via `ensure_index`.* The guard sits in
  `ensure_index` itself, which is the single function every read verb
  regenerates through: an absent directory means no issues, so it serves nothing
  and creates nothing. This is the root fix the 2026-07-09 note argued for, at
  the shared helper rather than in each verb.

**Trigger 2 is untouched.** A direct `index.sh` run with no directory argument,
from a CWD other than the repository root, still resolves the relative
`./docs/issues` against the wrong place and `mkdir -p`s a stray nested tree. It
never passes through `ensure_index`, so nothing above reaches it.

Two candidate fixes remain, and this issue's own notes name both: drop
`index.sh`'s `mkdir -p` so a regeneration never creates its target — which needs
checking against the first-filing flow, since that is the one path where the
collection legitimately does not exist yet — or anchor the resolver's relative
default to the project root, which is the walk-up decision carried under
`20260812-jimconf-resolver-can-hand-a-fabricated-default-to-a-caller`.
