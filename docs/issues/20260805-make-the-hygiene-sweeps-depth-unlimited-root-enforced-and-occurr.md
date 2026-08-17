---
id: 20260805-make-the-hygiene-sweeps-depth-unlimited-root-enforced-and-occurr
num: 240
title: "Make the hygiene sweeps depth-unlimited, root-enforced, and occurrence-counting"
status: open
priority: medium
labels: [test-coverage, test, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:31Z
updated: 2026-08-05T22:20:31Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
---

## Description

## Description

`tests/scripthygiene.sh` contains one sweep that gets the corpus question right
sitting beside three that do not, and the locale sweep added this build cannot
count.

**Depth.** The stray sweep enumerates with `find` at any depth over three roots
and says so in-source ("A depth-limited sweep cannot see
`skills/<x>/tests/<name>.sh`"). The preamble (`:83`), locale (`:98`) and
read-target (`:143`) sweeps in the same file are depth-1 globs. A script one
directory deeper passes all three:

```
skills/issue/scripts/lib/helper.sh   # set -e, no locale export, undeclared read target
  production_scripts_export_lc_all  -> PASS
  read_targets_are_declared_local   -> PASS
  every_script_sets_pipefail        -> PASS
  ordinal_width_bound               -> FAIL   (the grep -r sweep sees it)
```

**Roots.** The stray sweep's roots are unenforced: deleting `agents/` and
`scripts/` from the `find` leaves the case green with genuine strays planted in
both, because `skills/` alone over-satisfies the `n >= 10` floor.

**Counting.** The new locale sweep (`:127-129`) uses `grep -c`, which counts
*lines*, so a pinned and an unpinned `sort -u` on one line cancel to zero. It
matches only the literal `sort -u` spelling — `sort --unique`, `sort -nu` and
plain order-dependent `sort` all pass — and it excludes its own file wholesale
rather than just the pattern string. Two of the three sites the locale issue was
filed about are re-unpinnable with the suite green.

**Blind spots proven by planting**, in addition to the above: `tests/nested/`,
`tests/*.bash`, files with no extension, unreadable files (`grep: Permission
denied` on stderr, case still PASS), symlinked files, symlinked directories, the
repo root, `docs/`, `.claude/`. Scaffolding from inside `tests/` writes
`tests/tests/widget.sh`, reports success, and the file is never run and never
flagged:

```
( cd tests && bash ../skills/meta-test/scripts/metatest.sh scaffold widget )
  -> Scaffolded tests/widget.sh          (reads as success)
find tests -name widget.sh
  -> tests/tests/widget.sh
bash skills/meta-test/scripts/run.sh widget
  -> Ran 0 tests: 0 passed, 0 failed
```

The issue's title is "detect a stray test file instead of silently not running
it"; these files are silently not run *and* not detected.

## Proposed action

Give the preamble, locale and read-target sweeps the same depth-unlimited `find`
the stray sweep uses.

Add a per-root enumeration assertion so dropping a root fails rather than being
absorbed by the shared floor.

Count occurrences rather than lines in the locale sweep, match `sort` with any
flag combination that implies ordering, and narrow the self-exclusion to the
pattern string rather than the whole file.

Extend the stray sweep to `tests/` itself — nested subdirectories and non-`.sh`
extensions — since that is the half of the rule its own title names.
