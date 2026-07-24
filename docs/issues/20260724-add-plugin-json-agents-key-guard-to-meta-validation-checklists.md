---
id: 20260724-add-plugin-json-agents-key-guard-to-meta-validation-checklists
num: 18
title: "Add plugin.json agents-key guard to meta validation checklists"
status: open
priority: medium
labels: [meta, validation]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-24T10:33:25Z
updated: 2026-07-24T10:33:25Z
origin: docs/research/20260724-jim-meta-external-research.md
---

## Description

Claude Code auto-discovers every agent in a plugin's default `agents/` directory. If `.claude-plugin/plugin.json` declares an explicit `agents` array, that array replaces auto-discovery — only listed agents exist, with no error or warning for the rest.

Documented incident (verified 2026-07-24 in Jamie-BitFlight's agent-creator skill, `Jamie-BitFlight/claude_skills` → `plugins/plugin-creator/skills/agent-creator/SKILL.md`): adding a 2-entry `agents` array hid 17 of 19 agents in that plugin.

jim's `plugin.json` currently relies on auto-discovery (no `agents` key) — correct today, but nothing guards it.

**Proposed guard**, added to the validation checklists that `meta-skill` and `meta-agent` run after generating or updating a component:

- Assert `.claude-plugin/plugin.json` has no `agents` key; if one is ever deliberately introduced, assert it lists every agent file in `agents/`.
- After any `plugin.json` edit, confirm all expected agents and skills remain discoverable (whole-plugin validation — best-practice #8 in the origin research doc).

Origin research doc `docs/research/20260724-jim-meta-external-research.md` lives on branch `feat/claude-speak` until merged.
