---
id: 20260728-fix-vacuous-inline-backtick-wikilink-test-in-tests-issues-sh
num: 128
title: "Fix vacuous inline-backtick wikilink test in tests/issues.sh"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [test, hygiene]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-28T21:39:09Z
updated: 2026-07-28T21:39:09Z
origin: docs/specs/platform/010-allocator-issue-prefix/plan.md
---

## Description

`tests/issues.sh` → `case_issues_index_wikilink_in_inline_backticks_ignored`
(~line 567) passes a **double-quoted** body string to `write_issue` containing a
backtick span:

```
write_issue "$dir" "20260530-a" 'title: "A"
status: open' "Authors who write `[[B]]` in prose ... not asserting an edge."
```

Because the body is double-quoted, bash runs **command substitution** on the
backtick span and tries to execute `[[B]]` as a command, emitting
`tests/issues.sh: line 567: [[B]]: command not found` on stderr during every
suite run. Two effects:

1. **Spurious stderr leak** — pollutes `bash tests/issues.sh` and the aggregate
   runner output.
2. **Vacuous assertion** — the substitution strips the `[[B]]` token before
   `write_issue` sees it, so the persisted body contains no wikilink at all. The
   test asserts "no graph edge is produced," which then passes trivially — it is
   not exercising `index.sh`'s inline-backtick suppression. (The intended
   coverage is likely still provided by the fenced-variant siblings.)

## Fix

Single-quote the body argument (or escape the backticks) so the literal
`` `[[B]]` `` reaches the persisted body and the assertion tests real behavior.
Re-run `bash tests/issues.sh` and confirm the stderr line is gone and the case
still passes.

Surfaced by the `platform/010` full-suite gate; unrelated to the allocator
change.
