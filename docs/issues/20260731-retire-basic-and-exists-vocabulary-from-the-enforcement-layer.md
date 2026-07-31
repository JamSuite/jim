---
id: 20260731-retire-basic-and-exists-vocabulary-from-the-enforcement-layer
num: 164
title: "Retire BASIC and EXISTS vocabulary from the enforcement layer"
status: open
priority: high
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T11:49:02Z
updated: 2026-07-31T11:49:02Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

## Description

`/jim:verify sdlc` scored the `sentinel-vocab` invariant (high) a partial. Every
production gate is clean: all eleven workflow skills use the canonical
`SET` / `IF…THEN` / `ELSE IF` / `ENDIF` vocabulary, no `!`-injection slot appears
inside `(...)` in any production skill, and no EXISTS-family directive survives
in one.

The divergence is in the enforcement layer — which is where this invariant's
"plugin-wide, enforced here" clause places its weight:

1. `skills/meta-matrix-conditional-evaluation/SKILL.md:69,79` — rows AA/BB use
   `IF <name> EXISTS THEN`, named a regression verbatim at `ARCHITECTURE.md:492`.
   Every other retired form in this fixture family sits inside an explicit
   forensic carve-out; AA/BB are the inverse — the frontmatter (`:5-6`), the body
   intro (`:17`) and the section lede (`:62`) all assert they are load-bearing,
   and `skills/meta-matrix/SKILL.md:58` says the refinement "is only viable if AA
   and BB both return ✅". They are in fact superseded: rows GG/HH at `:129,139`
   already exercise the canonical predicate.

2. `agents/meta.md:66` — instructs the agent to check that gates "use the
   BASIC-style idiom from ARCHITECTURE.md → Plugin Conventions → Logic-Flow
   Conventions". "BASIC-style" is precisely the label `ARCHITECTURE.md:490` gives
   the retired Tier-1 anti-pattern. The sibling checklists it parallels were
   migrated to "the sentinel form" (`skills/meta-skill/SKILL.md:106`,
   `skills/meta-agent/SKILL.md:126`); this one was not.

## Why it matters

No shipped workflow skill can execute a retired gate today, so runtime behavior
is sound. But an agent instructed to check for "the BASIC-style idiom" and a
fixture that advertises the retired predicate as load-bearing both bias future
authoring toward the regression.

## Fix

Both are one-line corrections; neither touches production gate logic. Relabel
AA/BB as superseded (matching the carve-out its siblings carry), and reword
`agents/meta.md:66` to name the sentinel form.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.
