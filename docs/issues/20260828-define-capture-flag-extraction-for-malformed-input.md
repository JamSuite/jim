---
id: 20260828-define-capture-flag-extraction-for-malformed-input
num: P-20260828-define-capture-flag-extraction-for-malformed-input
title: "Define capture flag extraction for malformed input"
status: open
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [skill-surface, epic]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:37:32Z
updated: 2026-08-28T11:37:32Z
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
