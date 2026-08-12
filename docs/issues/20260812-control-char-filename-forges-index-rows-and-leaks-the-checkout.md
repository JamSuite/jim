---
id: 20260812-control-char-filename-forges-index-rows-and-leaks-the-checkout
num: P-20260812-control-char-filename-forges-index-rows-and-leaks-the-checkout
title: "Control-char filename forges index rows and leaks the checkout"
status: open
priority: critical
labels: [issue, security, data-integrity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:18Z
updated: 2026-08-12T21:53:18Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Under a branch placement the collection arrives from a shared branch any
teammate can write, so an entry name is untrusted input. Nothing in the chain
rejects control characters in one.

`place_materialize` (`skills/issue/scripts/place.sh:1293-1341`) gates five
things: mode `100644|100755`, no `*/*` and not `.`/`..`, no leading `-`,
`jimfile.sh valid-relpath`, and a `realpath -m` containment check. None of them
sees a newline or a tab. `cmd_valid_relpath` (`skills/file/scripts/jimfile.sh:229-246`)
checks only empty, absolute, and `..` segments.

`index.sh` then enumerates with an unquoted expansion
(`skills/issue/scripts/index.sh:338`):

    IFS=$'\n' files_sorted=($(printf '%s\n' "${files[@]}" | sort))

`IFS=$'\n'` closes space-splitting but pathname expansion is still live, and
`set -f` appears nowhere in the corpus. So an ordinarily-committed file named
`20260101-a.md<LF>*.md` splits into two words and each is glob-expanded. The
fragment after the newline is a **relative path resolved against the run's CWD**,
which is the developer's primary checkout — `place.sh` never leaves it. A
fragment of `*.md` therefore enumerates the project root's markdown,
`index.sh:361-366` takes `basename … .md` as a slug (which passes `is_valid_id`),
parses each file's frontmatter scalars, and renders them as issue rows. `place.sh`
publishes that index to the shared destination branch.

The per-slug validator at `index.sh:364` cannot catch this: it runs on the
fragments, after the split. A tab instead of a newline takes the other branch —
the entry is materialized and published, but its slug fails `is_valid_id`, so the
file is silently never indexed.

A narrower path corrupts `place.sh` itself. The two-phase base snapshot is a
line-oriented round trip (`place_save_snapshot:878-886` writes `sha\tname`,
`place_load_snapshot:888-899` reads it back per line), so a newline-bearing name
loads as two bogus records. A fabricated record reaches the deletion loop at
`place_build_commit:1433-1436` as a real name, which can drop a dotfile entry from
the published tree and land the empty commit the retry guard promises never to
leave.

Reached independently by three agents on different tasks during the fourth
review — one region investigator and the `untrusted-body-never-shell` and
`materialization-contained` judges.

No test in `tests/place.sh` or `tests/issues.sh` covers a control character in an
entry name, in either direction. The outbound gate (`place_snapshot`,
`place.sh:1362-1389`) has the same hole, so a wrapped command can create such a
name too.

## Action

Two fixes, both wanted — the second is the containment gate, the first is the
defence in depth that makes the enumeration correct regardless:

1. `index.sh:338` — quote the substitution and read the sorted list with
   `while IFS= read -r -d ''` (or `sort -z`), so a filename is one word whatever
   bytes it holds.
2. `place.sh` — reject any entry name containing `[[:cntrl:]]` in **both**
   `place_materialize` (inbound) and `place_snapshot` (outbound), beside the
   existing gates.

Pin each direction with a case that plants a newline-bearing name and asserts the
refusal, and one asserting no row is rendered for a path outside the collection.
