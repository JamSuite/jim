---
id: 20260825-blueprint-generate-mode-has-no-commit-verb
num: 379
title: "Blueprint generate mode has no commit verb"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [blueprint, ledger, skills]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T08:31:09Z
updated: 2026-08-25T08:31:09Z
origin: "skills/blueprint/SKILL.md"
---

## Description

Generate mode writes a group blueprint and stops. It stamps
`last_full_generate`, runs the reconcile pass, and never commits the file it
just wrote or records that it ran.

## Where it diverges

`commit-blueprint` is called from three places, none of them generate mode:

- update mode's absent-blueprint fallthrough, as `create`
- update mode's normal write, as `update`
- retire mode, as `update`

Generate mode's Step 5 ends at "After a completed write, run the reconcile
pass" — no commit, and no `jimledger.sh event` anywhere in Steps 1–5. Update
mode opens with `blueprint started` and closes with `blueprint finished`;
generate mode records neither.

## What it leaves behind

**A committed map describing an uncommitted face.** The reconcile pass that
generate mode *does* run commits `BLUEPRINT.md` through `commit-map`, so the
derived contract graph lands in history while the `Provides` and `Requires`
entries it was derived from sit uncommitted in the working tree. Under
`auto_blueprint = "true"` that happens unattended.

**No ledger trace of a regeneration.** `last_full_generate` in the frontmatter
is the only record that one happened. The group ledger shows updates, verifies
and retires, and is silent about the operation the others are measured against.

**A hand-written commit imitating the real one.** The `issue` group was fully
regenerated on 2026-08-25 and landed as `a353589`, subject
`docs(blueprint): update 000-blueprint` — the `commit-blueprint` format,
written by hand, saying "update" for a generate, and carrying only `spec.md`
where `commit-blueprint` would have carried `ledger.md` too. The group's ledger
has no `blueprint` entry for it.

## Direction

Two decisions.

**The mode word.** `commit-blueprint` whitelists `create|update` and silently
maps anything else to `update`, so calling it from generate mode today yields a
subject saying "update" for a regeneration. Either a fresh generate is `create`
and a regeneration is `update` — accurate enough, and no script change — or the
whitelist gains a third word.

**Whether generate records a stage event, and in which order.** A
`blueprint finished` written by generate mode would be counted by
`updates-since`, which is the cadence signal `last_full_generate` is the
baseline for — a generate counting itself as an update against its own
baseline. Update mode's fallthrough already solves exactly this: it records
`finished` with zero counters **first**, then stamps the watermark from a fresh
`now`, so the strictly-after count excludes it. Generate mode can copy that
ordering.

If the omission is deliberate — a fresh generate being part of a larger change
the developer commits themselves — nothing says so, and the asymmetry reads as
an oversight to every reader who meets it.
