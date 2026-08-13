---
id: 20260812-architecture-md-keeps-two-stale-rosters-and-a-contradiction
num: 325
title: "ARCHITECTURE.md keeps two stale rosters and a contradiction"
status: open
priority: high
labels: [docs, architecture]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:35Z
updated: 2026-08-13T09:48:16Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`ARCHITECTURE.md` carries two fixed surfacing-skill counts of exactly the class
the review-remediation round set out to purge, plus one sentence that contradicts
its own paragraph.

## The stale rosters

- **`ARCHITECTURE.md:274`** — "`/jim:partition` the **eighth** surfacing skill".
- **`ARCHITECTURE.md:320`** — the Issue Collection producer cell:
  "the **8** surfacing skills (`/jim:spec`, `/jim:research`, `/jim:plan`,
  `/jim:build`, `/jim:brainstorm`, `/jim:debug`, `/jim:sec`, `/jim:partition`)".

That enumeration includes `/jim:partition`, which has no quiet path, and omits
`/jim:review` and `/jim:verify`, which both auto-file — the exact omission the
roster issue was filed against for `SKILL.md`. The derived consumer set is
**eleven** (`grep -l 'scripts/new\.sh \*' skills/*/SKILL.md`, minus `issue`), nine
of them with a quiet path.

`tests/jimconf.sh:820` carries a third ("the 7 surfacing skills"), in a code
comment.

A fourth sits in a blueprint face — `docs/specs/sdlc/000-blueprint/spec.md`'s
`## Requires`, on the `issue.emitter` entry: "the end-of-run § 7a candidate
batches from the surfacing skills (spec, research, plan, build, debug, sec,
review, brainstorm)". Eight named; `/jim:verify`, `/jim:partition` and
`/jim:blueprint` are absent, and all three hold the emitter grant. This one is
the group's declared consumer face rather than prose, so it is what a
blast-radius reader resolves against.

Correcting it belongs to the blueprint surface (`/jim:blueprint sdlc`), not a
hand edit — the same "through the skill, never by hand" rule this issue applies
to `ARCHITECTURE.md`.

The mechanical sweep added in the round —
`case_docsurfaces_candidate_batch_roster_matches_the_grant`
(`tests/docsurfaces.sh:195-215`) — is scoped to § 7a's body, so it cannot catch any
of these. `ARCHITECTURE.md` and `docs/specs/` are outside its corpus entirely,
and neither falls in any group's declared territory.

**The closing issue's resolution overclaims.** It reads as a clean sweep of the
file, asserting "`ARCHITECTURE.md`'s two counts are restated the same way"; only
the `:395` pair was. The `/jim:arch` run in the same round regenerated the file
and left `:274` and `:320` standing. A resolution note is the durable record —
when it is more complete than the change, the next reader inherits a false clean.
This is the second consecutive review to record that pattern.

## The self-contradiction

**`ARCHITECTURE.md:395`** — "Routing lives *inside* the six entry scripts rather
than in their callers … so the emitter … carries placement for every consumer's
candidate batch **with no change to any of them**."

True of routing only. The same bullet, earlier in the same paragraph, records that
every consumer must now pass `--auto`/`--reviewed` and handle rc 4 and rc 2 —
which is a change to all thirteen of them. Read at a skim the sentence says the
opposite of what shipped.

Two smaller items in the same file: `:395` calls `/jim:partition`'s grant a
"read-only **pair**" and then lists three verbs; and the canonical emitter-call
example at `:395` renders `new.sh --title … --body-file <tmp>`, omitting the now-
required declaration — so the one call shape `ARCHITECTURE.md` shows is the shape
that refuses at rc 2 under a placement.

## Action

Through `/jim:arch`, never by hand:

1. Restate `:274` and `:320` as a property ("every skill holding the `new.sh`
   grant"), not a count or a roster.
2. Scope `:395`'s clause to routing — "carries *routing* for every consumer with
   no change to any of them; the batch *declaration* is the one thing each caller
   states".
3. Render the canonical example as `new.sh (--auto | --reviewed) …`, matching
   `skills/issue/SKILL.md:235`; fix the "pair" wording to name three verbs.

Separately, add a dated `## Correction` to the roster issue naming `:274` and
`:320` as not landed — the instrument `#269` used for the same situation. And fix
the code comment at `tests/jimconf.sh:820`.

Through `/jim:blueprint sdlc`, restate the `issue.emitter` Requires entry's
roster as the same property, so the declared consumer face stops enumerating.

Worth considering: extend the docsurfaces roster sweep to `ARCHITECTURE.md` and
to the group blueprints' faces, so this class cannot recur outside § 7a. Both
corpora sit outside every current sweep.

## Note

**2026-08-13.** The fourth site — the `sdlc` blueprint's `issue.emitter`
Requires entry — was found while adding the reciprocal `issue.placement-door`
entry to the same face. The roster sits one bullet above the addition, so the
edit surfaced it; nothing swept it up. Recorded here rather than corrected in
that pass, because the two edits answer different findings and the roster
restatement is this issue's to own.

**2026-08-13, a fifth site.** `:395`'s description of the citation sweep — "it
drops the issues root from its `git ls-files` pathspec under a placement,
rewrites the collection the handle hands back, and publishes it as one `edit`
commit" — now describes only part of what the sweep does, and the part it
describes was the defect. Dropping the root from the pathspec never kept the
worktree's fork of the collection out: another configured root can be its
ancestor, and git lists it through that one. And "rewrites the collection the
handle hands back" is exactly the assumption the containment fix removed — the
sweep now establishes containment against whatever directory it was handed,
because `begin` does not report which arm it took.

Restate through `/jim:arch` as: the sweep drops from its enumeration every path
resolving inside a routed issues root (the pathspec alone does not), and bounds
every target by the root it came from rather than by which arm `begin` took.
