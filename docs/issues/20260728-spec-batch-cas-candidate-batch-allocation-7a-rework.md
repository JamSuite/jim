---
id: 20260728-spec-batch-cas-candidate-batch-allocation-7a-rework
num: 127
title: "Spec batch-CAS candidate-batch allocation (§7a rework)"
status: open
priority: high
labels: [id-coordination, candidate-batch, cross-group]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-28T06:59:35Z
updated: 2026-07-28T06:59:35Z
origin: docs/specs/issue/010-ordinal-coordination/plan.md
---

## Description

`issue/010` wires issue filing onto the coordination allocator but coordinates
**per item** — one CAS per filed issue. The end-of-run candidate batch (the
eight surfacing skills: spec, plan, build, review, sec, research, partition,
issue-add) therefore does N sequential CAS operations under a reachable remote,
racing every other push to the coordination branch.

This follow-on collapses a candidate batch into **one CAS**:

- Add a batch issue-allocate verb to `jimalloc.sh` over the shared, erosion-
  guarded `alloc_publish` path (N durable ids + ordinals in one commit).
- Rework the §7a candidate-batch contract (`skills/issue/SKILL.md`) so
  allocation happens **after** interactive row-resolution (skips/edits change the
  set), then files each surviving candidate through `new.sh` with pinned
  `--slug`/`--num`.
- Propagate the reworked batch shape into the eight surfacing skills' inlined
  candidate-batch blocks (cross-group: sdlc + blueprint + issue).
- Define the batch's failure semantics (all-or-nothing vs. documented partial).

Cross-group blast radius (sdlc + blueprint depend on the emitter and the §7a
contract), which is why it was split out of `issue/010`.

Carries security Finding 3 (`issue/010` security.md, Notable) and Handoff
Insight 2. Follow-on to `issue/010`.
