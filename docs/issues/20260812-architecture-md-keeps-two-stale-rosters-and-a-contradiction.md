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
updated: 2026-08-12T21:53:35Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`ARCHITECTURE.md` carries two fixed surfacing-skill counts of exactly the class
the review-remediation round set out to purge, plus one sentence that contradicts
its own paragraph.

## The two stale rosters

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

The mechanical sweep added in the round —
`case_docsurfaces_candidate_batch_roster_matches_the_grant`
(`tests/docsurfaces.sh:195-215`) — is scoped to § 7a's body, so it cannot catch any
of these. `ARCHITECTURE.md` is outside its corpus entirely.

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

Worth considering: extend the docsurfaces roster sweep to `ARCHITECTURE.md`, so
this class cannot recur outside § 7a.
