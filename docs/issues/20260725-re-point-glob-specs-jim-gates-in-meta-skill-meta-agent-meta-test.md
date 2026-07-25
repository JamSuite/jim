---
id: 20260725-re-point-glob-specs-jim-gates-in-meta-skill-meta-agent-meta-test
num: 102
title: "re-point glob-specs-jim gates in meta-skill, meta-agent, meta-test"
status: closed
priority: high
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:47Z
updated: 2026-07-25T08:29:06Z
origin: BLUEPRINT.md
---

## Description

Three skill gates hard-code the retired group as a live script argument: `glob specs jim` in skills/meta-skill/SKILL.md, skills/meta-agent/SKILL.md (Gate 1), and skills/meta-test/SKILL.md (Gate 1). Post-split the glob of the retired group returns nothing, so these gates cannot find approved specs — functionally broken until re-pointed. skills/file/SKILL.md doc examples also use the jim group.

Fix: re-point the gates to glob the relevant group(s) (likely all groups, or parameterize by target component). Code change through the normal spec → plan → build workflow; high priority — the meta toolchain's gating is inert until this lands.
