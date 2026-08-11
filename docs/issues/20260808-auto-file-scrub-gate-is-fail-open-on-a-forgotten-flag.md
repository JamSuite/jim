---
id: 20260808-auto-file-scrub-gate-is-fail-open-on-a-forgotten-flag
num: 278
title: "Auto-file scrub gate is fail-open on a forgotten flag"
status: open
priority: high
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:29Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The auto-file scrub gate (spec AC #13, security Finding 2's mitigation) is
**fail-open on a forgotten flag**, and three artifacts state the opposite.

## Mechanism

`auto` initializes to `0` (`skills/issue/scripts/new.sh:65`), is set only by the
flag (`:85`), and is read only at `:119`:

```bash
if (( auto )) && [[ "$(bash "$JIMCONF" get issue_placement_ack ...)" != "true" ]]; then
```

A skill on the quiet path (`auto_issue_file = "true"`) that **omits** `--auto`
gets `auto=0`, skips the gate, and reaches `exec bash "$PLACE" run --verb file`
at `:126` — the unreviewed batch is committed and pushed to the shared branch.
That is precisely what AC #13 exists to prevent.

The safe-sounding case is the *other* omission: a reviewed batch that wrongly
passes `--auto` merely gets redirected to a second review.

## The false claim

Three artifacts assert the inverse:

- `skills/issue/scripts/new.sh:117-118`
- `skills/issue/SKILL.md:247`
- `ARCHITECTURE.md:395`

all saying a caller that forgets the flag "gets the interactive bargain rather
than a silent publish, which is the safe direction to fail."

A maintainer trusting `ARCHITECTURE.md` would conclude the flag is
optional-and-safe.

## Scope

The mechanism works as built — all nine consumers pass the flag and handle rc 4,
verified by sweep — so AC #13 is satisfied *today*. What is wrong is the
polarity and the documentation of it. The emitter cannot observe
`auto_issue_file` itself (reading it would also refuse the legitimately
*degraded interactive* filing, which is why the flag exists at all), so the AC's
trigger is a caller-supplied declaration whose default is "reviewed".

## Proposed action

Two parts, separable:

1. **Correct the prose in all three places** — this is unconditional and cheap.
   The current text documents a security property the code does not have.
2. **Decide the polarity.** The genuinely fail-closed shape is the inverse:
   treat every filing as unreviewed and have the interactive path opt out with
   `--reviewed`, so a forgotten flag refuses instead of publishing. That is a
   real design fork — every interactive caller, including `/jim:issue add`,
   would then carry a flag — and it should be decided deliberately rather than
   inherited.

The compensating control today is `tests/docsurfaces.sh:191-205`, whose binding
is weaker than it looks (see the related issue on the sweep).

## Progress (2026-08-11)

**The prose half is fixed** in `457c8d6`. `new.sh`, `skills/issue/SKILL.md` and
`ARCHITECTURE.md` no longer claim that a caller forgetting `--auto` "gets the
interactive bargain rather than a silent publish, which is the safe direction to
fail". All three now state that an absent flag reads as a reviewed batch, so
omitting it on a quiet path publishes.

**The polarity decision remains open** and is the reason this issue is not
closed. The genuinely fail-closed shape is the inverse — treat every filing as
unreviewed and have the interactive path opt out with `--reviewed` — so a
forgotten flag refuses instead of publishing. The cost is that every interactive
caller, including `/jim:issue add`, then carries a flag. Deliberately not taken.
