---
id: 20260731-fix-the-index-script-exit-trap-leaking-its-temp-file
num: 170
title: "Fix the index script EXIT trap leaking its temp file"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:08:22Z
updated: 2026-07-31T20:41:03Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/plan.md
---

## Description

`skills/issue/scripts/index.sh` installs `trap 'rm -f "$tmpfile"' EXIT INT TERM`
inside the function that declares `tmpfile` as a `local`. On the atomic-rename
failure path the function returns before clearing the trap, so the trap body runs
at shell exit with `tmpfile` out of scope — and under the script's `set -u`
preamble the expansion is fatal:

    index.sh: line 1: tmpfile: unbound variable

Because the trap aborts on that expansion, the `rm -f` never runs and the
temporary file is left behind.

## Reproduction

    mkdir -p t/INDEX.md
    printf -- '---\nid: 20260101-x\nnum: 1\nstatus: open\ntitle: "x"\ncreated: 2026-01-01T00:00:00Z\n---\n' > t/20260101-x.md
    chmod 500 t/INDEX.md          # make the atomic rename fail
    bash skills/issue/scripts/index.sh t
    ls -a t/                      # .INDEX.md.tmp.XXXXXX survives

Verified: the temp file is present after the run.

## Why it matters

Two effects, both small but real. The stderr noise is misleading — it names a
shell-internal failure rather than the actual cause, which the line above it
already reported correctly. And the leak defeats the cleanup the trap exists for:
a directory whose index cannot be written accumulates a hidden temp file per
attempt.

The failure path itself behaves correctly otherwise — the previous `INDEX.md` is
untouched and the non-zero exit propagates, which is how the `sdlc/018` build was
able to fixture a failed regeneration.

## Fix

Give the trap a value that survives the scope — e.g. expand defensively
(`${tmpfile:-}`), or hoist the variable, or clear the trap on the error path
before returning.

Surfaced while fixturing the index-regeneration failure path during the
`sdlc/018` build.

## Resolution (2026-07-31)

Closed by the C′-fix build, taking two of the three suggested fixes rather than
one, because they close different halves:

- The trap body expands defensively, so a fire after the frame is gone is no
  longer fatal under `set -u`. That stops the misleading shell-internal error
  from printing over the accurate message the line above already gave.
- The failure path cleans up and clears the trap *while the path is still in
  scope*, which is what actually removes the file — a defensive expansion alone
  cannot, since the trap has no value to remove by then.

Fixtured on the reproduction this issue supplied: rc 1, no `.INDEX.md.tmp.*`
left behind, no `unbound variable` on stderr, and the real cause still named.
