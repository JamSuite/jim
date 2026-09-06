---
id: 20260731-unmix-the-template-brace-around-arguments-in-the-arch-skill
num: 165
title: "Unmix the template brace around ARGUMENTS in the arch skill"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T11:49:09Z
updated: 2026-08-13T11:36:20Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

`/jim:verify sdlc` scored the `sigil-discipline` invariant (high) a partial. Both
hard mechanical rules hold plugin-wide: no `<lower>` placeholder appears inside an
`!`-injection slot, every `$UPPER` token is one of the three recognized names, and
no `{lower}` slot appears inside a fenced bash or command line.

Two sites in one file wrap the live `$UPPER` slot in the `{lower}` template sigil:

- `skills/arch/SKILL.md:33` — "the target is `{$ARGUMENTS}/<filename portion of
  the resolved path>`"
- `skills/arch/SKILL.md:49` — "the target is `{$ARGUMENTS}/<filename portion of
  arch_doc>`"

`{$ARGUMENTS}` carries two of the three sigils in one token: the `{lower}`
template-generator brace (reserved for `assets/*.md` bodies) wrapped around
`$UPPER` (reserved for real shell expansion). This is the literal "never mixed"
breach.

## Why it matters

Not merely cosmetic. `/jim:arch` declares `argument-hint: "[directory-path]"`
(`skills/arch/SKILL.md:10`), so `$ARGUMENTS` is a live preprocessor-substituted
slot, and the same file relies on that substitution in prose at `:20` and `:31`.
After substitution the model sees literal braces around a real path
(`{docs/adr}/<filename portion …>`), inviting a brace-bearing target path on the
directory-argument branch of both the create (`:33`) and differential-update
(`:49`) flows.

Provenance: `docs/specs/sdlc/008-directive-vocabulary/plan.md:78` specified this
exact string, so the source spec carries the same mix.

## Fix

Drop the braces — `$ARGUMENTS/<filename portion …>`. Optionally lift the nested
`<filename portion of …>` angle placeholder out of inline-code prose, which is a
secondary deviation (harmless, since it sits outside any injection slot).

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.

## Re-grade

**2026-08-13. `high` → `medium`.**

Inherited from the invariant. Closer to right than most of this batch, but still
one grade high.

`$ARGUMENTS` is a live substituted slot, so after substitution the model does see
literal braces around a real path — a genuine invitation to a brace-bearing target
on both the create and update branches. That is a live correctness risk, not a
latent one, which is why it does not drop to `low`.

It stays under `high` because the consequence is a malformed path the developer
sees immediately, not a silent wrong write.
