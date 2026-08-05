---
id: 20260805-resolve-the-discovery-root-refusal-physically-and-measure-its-ot
num: 249
title: "Resolve the discovery-root refusal physically and measure its other three cells"
status: open
priority: high
labels: [meta-test, test, security, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:09Z
updated: 2026-08-05T22:20:09Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

Three defects in one boundary, found independently by three reviewers.

**1. A symlinked cwd defeats the refusal.** `skills/meta-test/scripts/metatest.sh:76-82`
tests bash's *logical* `$PWD` (`case "$PWD/" in */skills/*|*/agents/*)`). `cd`
through a symlink leaves the logical path free of `/skills/`, so the refusal
never fires and the write lands in the real discovery root:

```
cd $R/skills/demo   -> Error: refusing to write under ...   rc=1
ln -s $R/skills/demo /tmp/link
cd /tmp/link        -> Scaffolded tests/widget.sh           rc=0
                       wrote $R/skills/demo/tests/widget.sh
```

A second route: `ln -s $R/skills/demo ./tests` in an ordinary directory writes
through the symlinked `tests/` target. `$PWD` env-var spoofing does not work
(bash revalidates) and the name gate holds against `../` and absolute names — the
symlink is the open door.

**2. The test measures one of its four cells.** `tests/metatest.sh:147-150`
invokes `add widget smoke` without ever creating `tests/widget.sh` in that
sandbox, so `add_action` reaches the *file-does-not-exist* branch, which also
exits 1 with non-empty stderr. Both assertions pass whether or not the refusal
exists, and the `add` arm carries no "no test file written" assertion. Because
`agents/` is exercised only through `add`, dropping `*/agents/*` from the pattern
also survives. Mutation: deleting the refusal from `add_action` -> GREEN;
dropping `*/agents/*` -> GREEN.

**3. The suite writes into the production tree.** `tests/metatest.sh:58` does
`ln -s "$REPO_ROOT/skills" "$d/skills"`, so `mkdir -p "$sb/skills/demo"` at `:141`
creates `$REPO_ROOT/skills/demo`. It is invisible to `git status` only because git
does not track empty directories; with the refusal mutated out, a real file lands
there. This violates the standing rule that tests use temporary directories, never
production paths.

## Proposed action

- Resolve the path physically: `case "$(pwd -P)/" in ...`, and resolve the write
  target's parent before writing so a symlinked `tests/` is caught too.
- Give the test its missing three cells: `scaffold` x `agents/`, `add` x `skills/`,
  `add` x `agents/` — each with `tests/widget.sh` present, so `add` reaches the
  refusal rather than the missing-file branch, and each asserting no file was
  written.
- Stop the sandbox symlinking `skills` to the real tree; copy or stub the
  directory the case needs.
