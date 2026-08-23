---
id: 20260808-auto-file-scrub-gate-is-fail-open-on-a-forgotten-flag
num: 278
title: "Auto-file scrub gate is fail-open on a forgotten flag"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:39:29Z
updated: 2026-08-12T19:49:07Z
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

## Decision (2026-08-12)

**The polarity is settled**, superseding the 2026-08-11 Progress note above,
which said it remained open. It is **not** the inverse this issue proposed.

The shape taken is a third one: **require an explicit `--auto` or `--reviewed`
and refuse when neither is given, scoped to the routing condition.**

Why over the straight inversion. The inverse removes the fail-open but installs
a new silent default in the other direction — a caller that forgets
`--reviewed` on a genuinely reviewed batch gets an rc 4 redirection it should
not. Requiring a declaration has no silent default in either direction: a
forgotten flag is a loud refusal at the one moment it matters. Scoping it to the
routing condition keeps it inert for any project without a placement, which is
the entire installed base today — so the default path, the one AC 2 protects,
is unchanged.

Cost is the same either way: twelve call sites, ten of them prose.

**Not yet implemented.** This records the decision so it is not re-opened.

## Resolution (2026-08-12)

Implemented in `e7982b7`, as decided.

**The emitter.** `new.sh` gains `--reviewed` alongside `--auto`, and inside the
routing condition requires **exactly one**: neither is rc **2** naming the
destination and both remedies, both is rc **2** naming the contradiction. rc 4
keeps its old meaning — an acknowledged-placement redirect for a declared
`--auto` batch — and the header now distinguishes the two, since one has a
remedy (show the batch, file it `--reviewed`) and the other is a caller defect
with no remedy but to say which kind of batch this is.

Scoping to `route` is what keeps the default path literally unchanged: with no
placement configured, both flags are inert and a filing that declares nothing
still works. Pinned by `case_issues_declaration_is_not_required_by_default`.

**The call sites.** Every consumer's interactive path now declares `--reviewed`,
including `/jim:issue add` — step 5's confirm-or-edit *is* the review — and the
two consumers with no quiet path at all, `/jim:partition` and `/jim:blueprint`,
whose filings are always the reviewed case. The blueprint calls live in
`references/`, not in its `SKILL.md`, which is why a SKILL.md-scoped sweep never
saw them.

**The binding.** `tests/docsurfaces.sh` gains
`case_docsurfaces_interactive_paths_declare_reviewed`, swept over the emitter
grant rather than over a list, so a consumer added later inherits the check. The
existing `--auto` half is unchanged.

Pinned by `case_issues_placement_filing_without_a_declaration_refuses` and
`case_issues_placement_contradictory_declarations_refuse`. The first is proven
red with the gate neutered, and reproduces this issue exactly: the filing
publishes at rc 0 to `jim/issues` and prints a path. Seventeen pre-existing
placement fixtures filed with no declaration and had to be updated — that count
is the honest measure of how reachable the fail-open was.

**Correction to this issue's own text.** It says the gate "is satisfied *today*"
because all nine consumers pass the flag, and treats the polarity as
documentation-only. That was true of the nine SKILL.md quiet paths and false of
the surface as a whole: `/jim:blueprint` files through the same emitter and
appears in no roster this issue or `#317` consulted.
