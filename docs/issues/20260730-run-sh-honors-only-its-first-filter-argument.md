---
id: 20260730-run-sh-honors-only-its-first-filter-argument
num: 153
title: "run.sh honors only its first filter argument"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [meta-test, testing]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-30T10:32:47Z
updated: 2026-07-30T10:32:47Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/plan.md
---

## Description

## Description

`skills/meta-test/scripts/run.sh` reads its filter as `FILTER="${1:-}"` and
ignores every later argument, so a multi-filter invocation narrows silently to
the first one.

This is not hypothetical: `sdlc/017`'s plan carried

```
bash skills/meta-test/scripts/run.sh specreconcile jimledger | grep -E 'realized_event|vacated|Ran [1-9]'
```

as a task's Verify command. It exits 0 and looks like it covered both files,
while the `jimledger` half never ran — the `vacated` alternation in the grep
simply matched nothing, which is indistinguishable from matching cases that
passed. The build ran the second filter as a separate invocation to actually
check it.

Two candidate shapes:

- Accept several filters and select a case whose name contains any of them.
- Or keep one filter and reject extra arguments with a usage error, so a
  multi-filter invocation fails loudly instead of under-reporting.

The second is smaller and arguably the better failure mode for a test runner —
silently checking less than asked is the property worth removing, and either
change removes it.
