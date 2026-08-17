---
id: 20260725-review-the-17-frozen-jim-group-prose-mentions
num: 103
title: "review the 17 frozen jim-group prose mentions"
status: closed
priority: low
labels: [partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-25T08:04:46Z
updated: 2026-07-25T18:17:15Z
origin: BLUEPRINT.md
---

## Description

The split's reference sweep froze 17 prose mentions of the retired jim group (no single successor under a symmetric split). Locations: split-gate-evidence/freeze-final.txt at the time of the run; re-derivable via a "jim group" grep over docs/. Most are historical narrative in moved spec bodies and remain accurate as history.

Sweep once: rewrite any that read as current-state claims (per-mention judgment), leave genuine history frozen, then delete this list.

## Resolution

Sweep performed. `freeze-final.txt` was ephemeral split-run evidence and was never committed, so the enumerated list is unrecoverable; the authoritative record survives in `docs/specs/ledger.md` (the split event: `frozen=17` plus the full moved-mapping). The "jim group" grep is unreliable because "jim" names the project, the plugin, and the retired group, so it was superseded here by a `jim`-adjacent-to-`group` locator scoped to the moved spec bodies and core docs.

Per-mention judgment outcome — **no current-state claims remained to rewrite**:

- The present-tense members of the original set were already rewritten by the core-docs refresh (`50ad63b`): e.g. `/jim:file glob specs jim` and the `docs/specs/jim/001-meta … 048` enumeration both became partition-aware prose pointing at `BLUEPRINT.md`.
- Every live "jim group" mention that remains is genuine history in build `review.md` artifacts (frozen snapshots from when the group was single-group) — left frozen, accurate as history.
- `blueprint/015/spec.md` "multi-group jim project" is jim-the-project, not the retired group — correct as-is.
- The retired group's own `docs/specs/jim/000-blueprint` self-description is owned by the retired-directory end-of-life issue, not this sweep.

List retired.
