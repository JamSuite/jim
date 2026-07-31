---
id: 20260731-namespace-bare-agent-handles-and-add-a-checklist-item
num: 161
title: "Namespace bare agent handles and add a checklist item"
status: open
priority: critical
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T11:48:39Z
updated: 2026-07-31T11:48:39Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

## Description

`/jim:verify sdlc` scored the `plugin-name` invariant (critical) a partial. The
structural half is sound — `.claude-plugin/plugin.json` declares `"jim"`, and all
29 skills and 12 agents derive their namespace from it correctly, with every
permission grant and command reference namespaced.

Four sites write a jim agent handle **without** the namespace, and all four sit
in `description:` frontmatter — the text Claude Code matches on for routing:

- `skills/build/SKILL.md:4` — "Instructs the @coder to implement a spec …"
- `agents/reviewer.md:17` — "@reviewer handles post-build review."
- `agents/reviewer.md:24` — "A drift-vs-plan question routes to @reviewer."
- `agents/reviewer.md:31` — "@reviewer reviews shipped code …; design-time
  security is @jim:security's job." (both forms on one line)

Their own peers use the namespaced form uniformly (`@jim:coder` at
`agents/coder.md:17,26,35`), and `ARCHITECTURE.md:23` records `@jim:reviewer` as
the canonical handle.

## Why it matters

No dispatch path depends on these strings, so nothing fails at runtime — the risk
is routing/documentation misdirection. The compounding half is that the
enforcement the invariant *claims* does not exist: neither
`skills/meta-agent/SKILL.md:109-133` nor `skills/meta-skill/SKILL.md:89-117`
carries an item about the `jim:` prefix on references, so these sites can recur
unchecked.

## Fix

Namespace the four handles, and add a namespacing item to both authoring
checklists so the invariant's "enforced by this group's authoring checklists"
clause becomes true.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.
