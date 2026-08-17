---
id: 20260812-a-diverged-clone-wedges-into-permanent-rc-3-refusal
num: 323
title: "A diverged clone wedges into permanent rc 3 refusal"
status: open
priority: high
labels: [issue, placement, liveness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:34Z
updated: 2026-08-12T21:53:34Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Once a clone's local destination ref diverges from the remote carrying content
the destination also has, every subsequent write refuses rc 3 forever, under a
message advising a remedy that reproduces the refusal.

Three lines compose it in `skills/issue/scripts/place.sh`:

- `:1837` — `place_changed` finds an empty changed set and returns **0** without
  moving `refs/heads/<dest>`.
- `:1855` — the graft arm's `place_changed upstream merged` guard returns **0**
  when the destination already holds the merged result, again without advancing the
  local ref.
- `:1550` — `place_regraft` refuses on any touched path whose upstream copy
  differs from base (`theirs != base`), with no `theirs == ours` check.

So a clone that reaches divergence — via the rc-3 refusal pinned at
`tests/place.sh:1272`, or via the `:1855` convergence return — recomputes the same
merge base on every later write, finds the same `theirs != base`, and refuses
identically.

The message at `:1553` says:

    Nothing is lost — re-run to reapply on the current state

Re-running reproduces the refusal exactly. Nothing in `place.sh` or its docs names
the only real remedy: resetting the local destination ref.

Two related defects in the same rule:

1. **Byte-identical concurrent content is treated as a conflict.** `:1545-1561`
   refuses whenever `theirs != base`, with no `theirs == ours` test. A destination
   that already holds exactly what this mutation would write is a converged state,
   not a conflict.
2. **The refusal message mis-describes an upstream deletion.** `:1551-1553` prints
   "'<name>' also changed at the destination" when the destination *deleted* the
   path, and likewise for a convergent delete where both sides removed it. The rule
   is right; the diagnosis sends the developer looking for an edit that does not
   exist.

Four graft edge cases have no test at all: delete-vs-upstream-modify,
create-vs-create, upstream-delete-vs-our-modify, and convergent delete.

Found by the AC 7 investigator and corroborated by the publish-state-machine
region investigator during the fourth review. No mutation is lost in any traced
composition — this is a liveness defect, not a data-loss one.

## Action

1. `place_regraft:1545` — `continue` when `theirs == ours`, before the
   `theirs != base` test.
2. On the diverged arm, either advance the local ref when `merged == upstream`, or
   replace the "re-run" advice with the actual reconciliation step.
3. `:1551-1553` — branch the message on `[[ -z "$theirs" ]]` to say the path was
   deleted at the destination.

Pin with a case that drives a second write after a diverged refusal, asserting it
does not refuse identically, plus the four untested graft edge cases.
