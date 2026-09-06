---
id: 20260823-render-sh-help-tells-users-to-close-an-issue-by-hand
num: 369
title: "render.sh help tells users to close an issue by hand"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, docs, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:28Z
updated: 2026-08-24T19:26:24Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

`render.sh`'s help text tells the reader to close an issue by hand, in a way
that now produces an integrity warning.

## What it says

```
Issues live in the configured issues directory. Close one by editing its
`status:` field directly.
```

## Why it is wrong now

An issue that has ever been finished carries an `outcome`. Editing `status:` to
`closed` by hand leaves that field empty, and the index reports the record as
"closed but records no outcome" — a warning written into generated content the
project publishes.

The supported path is `transition.sh close`, which records the outcome
alongside the status and regenerates the index. The help text predates that
verb existing.

## Related staleness in the same area

`place.sh`'s header carries a verb enumeration that no longer matches the verbs
it implements. Both are documentation that drifted from the code beside it, and
both are cheap to correct in one pass.

## Why it matters

Help text is the surface a user reaches when they are already unsure. Pointing
them at a manual edit that the collection's own integrity check then flags
teaches the wrong model of how the collection is maintained.

## Resolution (2026-08-24)

Fixed in `a9235e6`, with one further site in `fc943fd`.

The help now lists the five lifecycle verbs and `reconcile` — it had fallen
behind the surface it exists to enumerate, not only carried a wrong sentence —
and says what a hand-written close leaves behind rather than recommending one.

**Two sites beyond the two this issue named.**

`WORKFLOW.md` carried the identical instruction, and is the surface a user is
likelier to reach than a script's `help`. Its correction splits what was one
sentence in two: closing goes through the verb, which owns the placement door
itself; editing an issue's *content* is the case that still needs the two-step
door, which is what the placement caveat was always about.

`migrate.sh`'s header and usage text call the `type` field `kind` — the name it
carried before it shipped. Same class, same script family, found by sweeping
the word rather than by re-reading this issue.

**Pinned by three cases, each run against the unfixed source first.**
`case_issues_render_help_points_at_the_lifecycle_verbs` matches each verb with
its operand, because bare `close` and `start` already occurred in the
surrounding prose and would not have discriminated.
`case_place_header_enumerates_every_commit_verb` derives its expectation from
`PLACE_VERBS` rather than listing the verbs, so the next verb added is covered
without anyone remembering the header is a second place to edit.
`case_docsurfaces_workflow_close_flow_survives_a_placement` was retargeted from
the sentence it used to pin to the section, since the correction splits that
sentence in two.
