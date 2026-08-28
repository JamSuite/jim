---
id: 20260828-define-capture-flag-extraction-for-malformed-input
num: 412
title: "Define capture flag extraction for malformed input"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: "jrko"
outcome: done
labels: [skill-surface, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:32Z
updated: 2026-08-28T23:54:29Z
origin: "docs/specs/issue/015-epic-authoring-and-views/review.md"
---

## Description

`skills/issue/SKILL.md:33-37` instructs the dispatching agent to take `--type`
and `--part-of` "and its value" out of `$ARGUMENTS` before the remainder
becomes the capture subject. The wording assumes exactly one well-formed
occurrence of each flag. Three inputs are undetermined.

## The three cases

**A repeated flag — the serious one.**

    /jim:issue add x --type epic --type issue

An agent that extracts the first occurrence and considers extraction done
leaves `--type issue` in the string. By the bullet's own stated rule, a flag
left in the string is filed as part of the title — so the record is titled
`x --type issue`. That is the identical title-pollution defect the flag wiring
was written to close, reached from a different direction.

**A trailing flag with no value.**

    /jim:issue add see PR --part-of

Nothing says whether to drop the bare flag or leave it as subject text.

**A non-kind token after `--type`.**

    /jim:issue add investigate --type of service degradation

Two readings are equally supported: extract `of` as the value and let the
emitter refuse (safely — the refusal is above the allocator, so no ordinal is
spent, but only after the interview has run to step 5), or treat `--type` as
having no recognized value and leave it in the subject.

## The fix

State the tie-break for a repeat, say what a valueless trailing flag does, and
say whether the kind is pre-validated before extraction or forwarded for the
emitter to refuse. A skill body is instructions to an agent, so "parse the
flags" is not enough — the ambiguous inputs need naming.

## Note

`new.sh` itself is unambiguous on all three: its parser takes the last
occurrence of a repeated flag, and its enum gate refuses an unrecognized kind
above the allocator. The gap is entirely in the prose that decides what reaches
the parser.

## Resolution

Fixed in `1954c7a8`.

One rule replaces the three undetermined readings: **the flag and one following
token always leave the subject, and the emitter judges the value.** The `add`
dispatch bullet states it and the capture checklist carries it as an
enforceable item, which is the surface an agent applies literally.

- **A repeat** — extraction removes *every* occurrence and carries the **last**
  forward. That is what `new.sh`'s parse loop already does, so the prose now
  describes the mechanism rather than assuming a shape it never had.
- **A valueless flag** — one ending the string, or followed by the other flag,
  names no value: drop it, carry nothing, and say so.
- **A non-kind value** — the next token is the value whatever it is, forwarded
  unjudged. Settled with the developer against pre-validating: the emitter owns
  the vocabulary and its refusal is the answer, exactly as the `list` bullet
  already says for filters. Its enum gate sits above the allocator, so the
  refusal costs no ordinal, and the step-5 draft shows the kind — which is
  where a developer catches it before the emitter does.

**A fourth case, not in the record.** A flag whose value is itself a flag
(`add x --part-of --type epic`). Without a clause for it, "take the next token"
swallows `--type` as a membership reference; it now falls under the
valueless rule. There is no false positive to trade against, because a value
that a reference could legitimately take never starts with `-`.

**Two tests, both characterization rather than red-first.** The mechanism was
already correct — the defect was entirely in prose that an agent, not a
script, executes — so there was nothing to make fail first. Each was proved by
mutation instead: neutering the parser to first-wins fails the tie-break case,
and adding a third kind to `ISSUE_TYPES` fails the synopsis case alongside the
existing checklist one. Suite 1,683 green.

**One claim was already pinned and was not duplicated.** That a refusal spends
no ordinal is held by `case_new_refusals_leave_the_ordinal_unspent`, which
drives an unrecognized kind specifically and asserts the next filing takes the
ordinal the refusals would have burned.

**Verified rather than inherited.** The record's closing Note — last occurrence
wins, enum gate above the allocator — was checked against the code before the
prose was written to lean on it: the parse loop overwrites on repeat, and the
gate precedes the allocator call.

**What this does not do.** It defines what the *skill* hands the emitter; it
adds no parser guard to `new.sh`. A flag-shaped value passed directly to the
emitter still consumes the flag as a value and then reports the following token
as an unknown flag, which is a confusing refusal rather than a wrong one. That
is a separate surface and is not filed here.
