---
id: 20260731-unwrap-the-injection-slot-in-the-arch-skill-argument-table
num: 163
title: "Unwrap the injection slot in the arch skill argument table"
status: open
priority: critical
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T11:48:54Z
updated: 2026-07-31T11:48:54Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

## Description

`/jim:verify sdlc` scored the `injection-set-rhs` invariant (critical) a partial.
Every gate site across the thirteen production skills in scope uses the canonical
paren-free form — `SET <name> = !`bash …`` bound, then compared in a paren-free
`IF … THEN … ENDIF` chain.

One production site places a live `!`-injection slot inside `(...)` on the same
line:

    skills/arch/SKILL.md:24
    | Empty | Create or update the resolved architecture path (default: !`bash …/jimfile.sh path architecture`) |

`ARCHITECTURE.md:511` states the prohibition without qualification: "An
`!`-injection slot must not appear inside `(...)` on the same line — the
preprocessor silently leaves the literal text in place, the bash never fires, and
the LLM sees the raw backticks." The group's own authoring checklist repeats it
(`skills/meta-skill/SKILL.md:106`).

## Why it matters

The risk is latent rather than currently firing — the empirical wrapper matrix
(`docs/debug/20260512-skill-bash-substitution-wrappers.md:174,182`) records this
shape substituting successfully outside an `IF` construct. But the convention is
stated with no non-`IF` carve-out, and the reason the invariant is `critical` is
that a paren-wrap failure surfaces **no** error at load time. Leaving it in place
keeps the plugin's most-cited authoring convention contradicted by one of its own
reference skills.

## Fix

Restructure the table cell so the slot is not parenthesized — or bind it with a
`SET` above the table and reference the name.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.
