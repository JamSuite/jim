---
id: 20260808-insights-empty-collection-short-circuit-has-no-granted-capabilit
num: P-20260808-insights-empty-collection-short-circuit-has-no-granted-capabilit
title: "Insights empty-collection short-circuit has no granted capability"
status: open
priority: low
labels: [issue, invariant]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:49:44Z
updated: 2026-08-08T18:49:44Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`skills/issue/SKILL.md` § 8 step 2 directs the main agent to perform an action the
skill grants no capability for, and the nearest granted substitute is the exact
read step 3 forbids three lines later.

## Mechanism

Step 2 (`skills/issue/SKILL.md:272-274`) asks the agent to count `*.md` files in
the resolved `<dir>` for an empty-collection short-circuit, ending "Count files
only; do not read their contents."

The skill's `allowed-tools` (`:6`) grants no `Glob`, no `LS`, no `Bash(ls *)`.
`Read` cannot list a directory. So of the granted tools, the only one that can
answer "is this collection empty" is a `Read` of a known filename — i.e.
`<dir>/INDEX.md`, which `:277-279` forbids ("Do **not** read issue bodies or
`INDEX.md` yourself") and `:318`'s checklist checks against.

The alternative is an ungranted `Glob`. That is not *blocked* — jim's own research
(`docs/research/20260512-skill-allowed-tools-narrowing.md:32`) records that
`allowed-tools` "does not restrict which tools are available" — but it is outside
the declared surface, so the step's execution depends on the user's ambient
permissions rather than on the skill.

`jimfile.sh exists <dir>` is granted but answers only the "absent" half, not
"empty". `render.sh` has no count verb.

## Why it is worth fixing rather than tolerating

This is the `insights-capability-boundary` invariant's load-bearing half. The
analyst side is capability-enforced (its `tools:` grant genuinely withholds
`Write`); the main-agent side is instruction-enforced only. A step that pressures
the agent toward the one read the boundary forbids is pressure applied exactly
where the enforcement is weakest.

The short-circuit also buys little: the analyst already handles the empty case
itself (`agents/issue-analyst.md:82-83`).

## Proposed action

Cheapest options, in order:

1. Drop the short-circuit — the analyst covers it.
2. Use `render.sh list <dir>`, which is granted and treats a trailing non-filter
   token as the directory.
3. Add a count verb to `render.sh` if the short-circuit is worth keeping as a
   pre-dispatch check.

## Related

A separate open issue covers the analyst reading a literal `docs/issues/*.md`
path under a placement (#266). This one is the main-agent side of the same
invariant.
