---
id: 20260808-blueprint-emitter-face-omits-the-auto-flag-and-exit-code-4
num: 279
title: "Blueprint emitter face omits the auto flag and exit code 4"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [blueprint, contract]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-08T18:49:44Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

The `issue` group's `new.sh` Provides face does not record the `--auto` flag or
exit code 4 — a contract extension that nine skills in the `sdlc` group now
depend on. This is the group's widest fan-in provides face.

## The gap

`docs/specs/issue/000-blueprint/spec.md` (the `new.sh` **single issue emitter**
entry) documents stdout, failure codes, identity, atomicity and encoding, and
closes with:

> The file lands wherever `issue_placement` directs — the working branch by
> default, or a designated destination branch — and stdout names the path within
> that destination.

That is unqualified, but `skills/issue/scripts/new.sh:119-125` adds a condition
under which **nothing lands**: with `--auto` set and `issue_placement_ack` not
`"true"`, the emitter exits 4 having written nothing.

Secondarily, the entry's "failures are fixed reason codes, never raw content" is
literally widened by the rc-4 message, which interpolates the `issue_placement`
config value into stderr. The interpolated value is project-controlled config, not
untrusted `--title`/`--body` content, so the security intent is upheld and the
disclosure is deliberate — but the phrase "fixed reason codes" no longer describes
it exactly.

## Judged *not* a breaking change

A consumer written against the declaration alone never passes `--auto`, and the
gate is guarded by `(( auto ))`, so it can never receive rc 4. The extension is
additive and opt-in. The sibling `§ 7a candidate-batch-contract` entry — which
`sdlc`'s Requires face also binds (`docs/specs/sdlc/000-blueprint/spec.md:61`) —
does document the flag and the code, so the consumer's real dependency is covered
by a declared surface today.

The residual is that `issue.emitter` is separately requireable, and it already
enumerates failure and placement semantics, so rc 4 is squarely within the topics
it covers. A future consumer binding only that entry would read "the file lands
wherever `issue_placement` directs" and be misled about a security-relevant
refusal path.

## Also missing: an invariant for the gate

There is no blueprint invariant covering the scrub gate, so `/jim:verify issue`
can never check spec AC #13 — even though `tests/docsurfaces.sh:191-205` proves
the property is mechanically checkable. Every other load-bearing property of this
group has one.

## Proposed action

Through the blueprint surface, not by hand:

1. One clause on the `new.sh` Provides entry recording the `--auto` opt-in and
   the rc-4 no-write refusal. Declaration edit only; no code change implied.
2. Consider an invariant for the gate, so the property has a verification route
   rather than only a doc-surface test.

## Resolution (2026-08-11)

Fixed in `540bdf4`. The `new.sh` emitter face records `--auto`, exit 4, and that
the flag is a caller-supplied declaration the emitter cannot verify — so a
consumer binding this entry alone is no longer told a guarantee the code does not
give. The reason-codes clause is qualified for the refusal message, which names
the configured destination.

Graded a weakening of a Provides entry: the declared guarantee narrows, the entry
declares no criticality so it grades critical/high, and it was gated rather than
auto-written. Blast radius `sdlc` and `blueprint`. This cleared the last
provider-side contract violation.
