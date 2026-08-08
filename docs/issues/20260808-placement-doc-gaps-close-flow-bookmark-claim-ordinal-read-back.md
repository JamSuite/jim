---
id: 20260808-placement-doc-gaps-close-flow-bookmark-claim-ordinal-read-back
num: P-20260808-placement-doc-gaps-close-flow-bookmark-claim-ordinal-read-back
title: "Placement doc gaps: close-flow, bookmark claim, ordinal read-back"
status: open
priority: medium
labels: [issue, placement, docs]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:40:08Z
updated: 2026-08-08T18:40:08Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Three documentation sites are wrong or unachievable under a branch placement.
Grouped because they are one editing pass.

## 1. WORKFLOW.md tells the user to edit the file directly

`WORKFLOW.md:127`: "Close an issue by editing its `status:` field directly."

Under a placement that file is not in the working tree. The correct two-step flow
(`place.sh begin` → Edit → `place.sh commit`) exists only in
`skills/issue/SKILL.md` §6a. `tests/docsurfaces.sh:207-209` guards that flow
precisely because it "has to stay documented where an agent editing an issue will
look" — but the case sweeps only `SKILL.md`, not `WORKFLOW.md`.

`WORKFLOW.md:215`'s skills tree also still reads
`scripts (index/new/render/backfill/migrate)` — missing `place.sh` (issue/011)
and `reconcile.sh` (issue/010).

## 2. ARCHITECTURE.md states an invariant one writer breaks

`ARCHITECTURE.md:395` says the bookmark "records the tip this clone last *saw at
the destination* … a commit that only ever reached this clone does not advance
it."

True on the plumbing path (`place.sh:1263-1269` gates the advance on
`tier == origin || -z remote`). False in direct mode:
`place_direct_publish:484` advances the bookmark immediately after the local
commit and *before* the push at `:487`, with no rollback on rejection.

The sentence states the invariant as achieved. It should either describe the
plumbing-path scope or the direct-mode writer should be brought into it — the
latter is tracked separately as part of the bookmark false-alarm issue.

## 3. SKILL.md §6's ordinal read-back is unachievable

`skills/issue/SKILL.md:162` tells the agent to read the written file's `num:`
back from the printed path. Under a placement `new.sh` prints a
**destination-relative** path (`new.sh:271-280`) for a file that is not in the
working tree, and the emitter's stdout carries slug and path only — so there is
no route to the ordinal at all.

The likely recoveries are both bad: re-running `new.sh` without `--slug`
allocates a **second** coordinated ordinal and writes a second issue at the
destination; hand-composing the file breaks `single-emitter`. Where the working
tree happens to hold a same-named file from a branch-local collection, the agent
reads the wrong file and reports a wrong ordinal at rc 0.

§6a got a placement arm; §6 did not. `SKILL.md:17`'s "Only two places need to
know: editing an issue in place (step 6a) and the auto-file path (step 7a)" is
consequently wrong — §6 is a third and §8 a fourth.

## Proposed action

Fix 1 and 2 as straightforward edits (ARCHITECTURE.md via `/jim:arch`). For 3,
either give §6 a `place.sh begin --read` arm or add `num` to the emitter's
stdout — the latter removes the read-back entirely and is the smaller contract
change than it looks, since the line is already `<slug>\t<path>`.
