---
id: 20260731-namespace-bare-agent-handles-and-add-a-checklist-item
num: 161
title: "Namespace bare agent handles and add a checklist item"
status: open
priority: low
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
created: 2026-07-31T11:48:39Z
updated: 2026-08-13T11:36:20Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

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

## Re-grade

**2026-08-13. `critical` → `low`.**

The label was inherited from the `plugin-name` invariant's criticality, not
graded from this breach. `/jim:verify` sets an offered issue's priority to the
invariant's criticality (`skills/verify/SKILL.md:267`), so a critical rule
breached trivially yields a critical issue.

This description already says the breach is trivial: "No dispatch path depends on
these strings, so nothing fails at runtime — the risk is routing/documentation
misdirection." Four strings in `description:` frontmatter, all in prose, none
load-bearing.

The compounding half — that the invariant claims enforcement by authoring
checklists which carry no such item — is the more durable defect, and it is a
process gap rather than a critical one.
