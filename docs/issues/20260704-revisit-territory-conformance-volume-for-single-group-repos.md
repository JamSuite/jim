---
id: 20260704-revisit-territory-conformance-volume-for-single-group-repos
num: 48
title: "Revisit territory-conformance volume for single-group repos"
status: open
priority: low
labels: [verify, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T23:41:11Z
updated: 2026-07-04T23:41:11Z
origin: docs/specs/jim/035-verify-engine/plan.md
---

## Description

## Context

Surfaced during the spec 035 build (`/jim:verify`). The `check` verb's
territory-conformance step emits a `TERRITORY-CONFORMANCE` record for every
tracked file outside the group's declared territory (the deterministic set
difference). On jim's own repo — a single group whose territory is
`skills/`, `agents/`, `tests/` — that is ~240 files (all of `docs/`, root
config, README, etc.).

Per DD #8 the script emits the raw set difference and the skill frames
attribution (group code = violation, docs/config = informational). That is
correct by design, but at this volume the framing burden is large.

## What

Revisit the conformance default for the single-group case where a group's
territory is a strict subtree of the repo. Options to weigh:

- Have the skill summarize scaffolding buckets rather than enumerate every
  outside-territory file.
- Consider whether `jimverify.sh check` should narrow the candidate set
  (e.g. only files matching code-like heuristics) or leave it fully to the
  skill.
- Reassess when spec B (pipeline integration) lands, since blast-radius
  scoping may reshape conformance anyway.

## Why

Territory conformance (AC #5) is most useful when it surfaces a genuine
stray; drowning that signal in project scaffolding weakens it. This is a
practice-informed refinement, not a correctness bug — the design is
intentional and the skill's attribution framing handles it; a trend-signal
watch item.
