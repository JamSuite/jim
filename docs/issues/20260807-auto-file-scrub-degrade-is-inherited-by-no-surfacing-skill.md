---
id: 20260807-auto-file-scrub-degrade-is-inherited-by-no-surfacing-skill
num: 262
title: "Auto-file scrub degrade is inherited by no surfacing skill"
status: closed
priority: high
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:24Z
updated: 2026-08-12T09:15:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The auto-file scrub rule is stated in `skills/issue/SKILL.md` §7a and pinned by
a `tests/docsurfaces.sh` invariant. No skill executes it.

```
skills/ files mentioning issue_placement:  issue/SKILL.md, place.sh, jimconf.sh
surfacing skills reading auto_issue_file:  9
surfacing skills reading issue_placement:  NONE
```

Every consuming skill (`spec`, `research`, `plan`, `build`, `brainstorm`,
`debug`, `sec`, `review`, `verify`) carries its own local restatement —
`IF auto_issue_file == "true" THEN apply the AUTO-FILE PATH` — and that is what
the agent executes. §7a lives in a skill file that is not loaded during, say,
`/jim:build`.

Concretely: a project with `auto_issue_file = "true"` and
`issue_placement = "jim/issues"` finishes a build and publishes every candidate —
including text drawn from tool output and fetched pages — to the shared branch
with no review. The mitigation is present as documentation and absent as
behavior.

## The design error worth naming

The plan reasoned that the eight surfacing skills cite §7a, so "one edit, eight
inheritors." That holds for a *rule to consult* (the fileable bar, the emitter
call shape) and fails for a *branch to take*, because the local text already
spells the branch out unconditionally. A pointer cannot override a local
imperative the agent is reading.

The textual invariant made it worse by certifying the rule was "stated" — which
it is, and which turns out not to be the property that matters.

## Proposed action

Put the decision where it is mechanical rather than inherited. Options, roughly
in order of preference:

1. A `place.sh` verb that answers "may this batch auto-file?" — the config gate
   already lives there, and each skill's auto-file branch consults it. One new
   call per skill, no duplicated rule.
2. Add the `SET`/`IF` guard to each of the nine skills' auto-file blocks. Nine
   edits, and the rule then has ten spellings.
3. Have the emitter refuse an auto-filed write under an unacknowledged
   placement. Mechanically strongest, but the emitter cannot tell an auto-filed
   call from an interactive one without a new flag.

Whichever is chosen, the docsurfaces invariant should assert the *consumers*
honor it, not merely that §7a mentions it.

## Resolution (backfilled 2026-08-12)

*Closed by the fix pass in `647ca2f`; this note is reconstructed from that pass's
commits, which recorded the resolution in trailers alone.*

Fixed in `3d4e592` and `4194ee3`. The decision moved out of the surfacing skills
and into the emitter, which is the one place that can make it mechanically: a
skill can only carry the rule as prose an agent may or may not act on, while
`new.sh` sees the flag. It exits **4** under an unacknowledged placement having
written nothing, so the caller's remedy is to show the batch for review. Every
auto-file site declares the batch unreviewed with `--auto`.

Pinned by the sweep in `tests/docsurfaces.sh`, which asserts each consumer passes
the flag and handles the code rather than certifying the rule is stated
somewhere — the property that turned out not to matter.

**Two later corrections belong with this note.** The fix-pass commit message
claimed a caller that forgets the flag "gets the interactive bargain rather than
a silent publish, which is the safe direction to fail." That is backwards, and
the three artifacts repeating it were corrected under this remediation in
`457c8d6`; the polarity itself is tracked as
[[20260808-auto-file-scrub-gate-is-fail-open-on-a-forgotten-flag]]. The sweep's
binding was also weaker than it looked and was strengthened separately.
