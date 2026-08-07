---
id: 20260807-cmd-begin-swallows-the-containment-gate-refusal
num: P-20260807-cmd-begin-swallows-the-containment-gate-refusal
title: "cmd_begin swallows the containment gate refusal"
status: open
priority: high
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:23Z
updated: 2026-08-07T11:43:23Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`cmd_begin` swallows the containment gate's refusal:

```bash
if ! place_materialize "$tip" "$prefix" "$handle/collection"; then
    local mrc=$?          # $? is the status of the NEGATED pipeline: always 0
    rm -rf -- "$handle"
    return "$mrc"         # returns 0
fi
```

Reproduced against a crafted traversal tree: `run` correctly exits 2 while
`begin` exits **0 with empty stdout**.

An agent keying on the exit code believes it holds a handle; the documented
contract (`begin` prints `<token>\t<dir>`) yields an empty token and an empty
dir, and the insights flow would hand the analyst a path resolving to the
project root. Nothing escapes — the refusal reaches stderr and the handle is
removed — but the Critical containment gate's refusal is invisible to the caller.

This is the only `if ! cmd; then x=$?` construct in the repository; the two other
`place_materialize` call sites use `|| return $?` and are correct.

## Proposed action

```bash
place_materialize "$tip" "$prefix" "$handle/collection" || {
  local mrc=$?
  rm -rf -- "$handle"
  return "$mrc"
}
```

Add a `begin`-against-a-crafted-tree case; the traversal fixture already exists
and is only driven through `run`.
