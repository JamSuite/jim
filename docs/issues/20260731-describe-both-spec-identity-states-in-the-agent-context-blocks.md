---
id: 20260731-describe-both-spec-identity-states-in-the-agent-context-blocks
num: 168
title: "Describe both spec-identity states in the agent context blocks"
status: open
priority: medium
labels: [sdlc, docs, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:08:07Z
updated: 2026-07-31T12:08:07Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/plan.md
---

## Description

## Description

The agent context blocks still describe a single spec-identity shape, predating
coordinated identity:

- `agents/pm.md:48-50` — "Specs: `docs/specs/{group}/{00X}-{name}/spec.md`" and
  "IDs: 3-digit zero-padded, sequential within each group"
- `agents/architect.md:49-51`, `agents/researcher.md:50`, `agents/coder.md:49`,
  `agents/security.md:53-55` — the same `{00X}-{name}` path shape

Both halves are now incomplete: an id is minted by the coordination allocator
rather than being sequential within the group, and a bound spec may legitimately
carry a reserved `P-{date}-{slug}` token whose whole value is the directory
basename.

## Why it matters

Low severity by itself — these are illustrative reference paths, and the skill
bodies govern (`agents/pm.md:74`). They were deliberately excluded from the
`sdlc/018` build: `agents/*.md` is outside that plan's File Manifest, and the
judge that surfaced them during `/jim:verify sdlc` reached the same conclusion
and did not count them as the `spec-id-sequencing` breach.

They remain stale relative to the two-state identity, and they are the context an
agent reads first.

## Fix

Update the five context blocks to name both identity states, matching the
language already used in `skills/spec/SKILL.md`, `WORKFLOW.md`, and the spec
template.

Surfaced during the `sdlc/018` build and corroborated by a `/jim:verify sdlc`
judge.
