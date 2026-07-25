---
title: "Blueprint regen cadence"
type: feature
group: "blueprint"
id: "032"
status: approved
origin:
  - "docs/issues/20260702-surface-targeted-update-count-since-last-full-blueprint-regen.md"
  - "docs/brainstorms/20260630-000-current-spec.md"
---

# 032 Blueprint regen cadence

## Overview

Make a group blueprint's targeted-update drift actionable: surface, in
`/jim:blueprint` update mode, how many targeted updates have accumulated since
the last full generate (a staleness signal), and let a project opt into a
configurable threshold that triggers a whole-group regeneration automatically —
so a team that wants a continuously-accurate blueprint no longer has to watch a
counter and regenerate by hand.

## Problem Statement

A blueprint update is deliberately diff-scoped: it edits only the sections a
change touches and never regenerates the rest, keeping per-review cost low. But
targeted updates accumulate drift the diff lens cannot see — non-local
implications a full whole-group regeneration would reconcile. Today that drift
is invisible: with default knobs a developer has no way to tell whether a
blueprint is fresh or has silently absorbed many narrow updates since its last
full reconciliation, so they never know when a full regen is worth the cost. The
gate for this (`require_blueprint`) shipped, but no *visibility* signal did.

A visibility signal helps a developer who is watching, but it does nothing for a
project that has opted into automation. `auto_blueprint` already means "keep the
blueprint written without me" — yet a team running it still has to notice an
accumulating count and trigger the full regen by hand, which is exactly the
manual vigilance automation is supposed to remove. For those projects the
blueprint should simply *stay accurate*: once enough targeted updates pile up, a
full regeneration should happen on its own, the same way `auto_blueprint`
already writes without a prompt.

The same blind spot has a coupled correctness gap: the blueprint commit path
labels every self-commit as an "update", so a blueprint created for the first
time through the review fallthrough is recorded as an update rather than a
create. That both misreports history and undermines the very baseline a cadence
signal must measure from — "since the last full generate" is only meaningful if
a create is distinguishable from an update.

## User Stories

- As a developer running a targeted blueprint update, I can see how many
  targeted updates have accumulated since the blueprint was last fully
  generated, so that I know when a whole-group regeneration is due.
- As a developer, I get that signal whether the update ran interactively or was
  triggered automatically by a review, so that drift accumulating silently
  across review-after-review does not stay hidden from me.
- As a developer who has not opted into a threshold, the signal is informational
  only — it never blocks the update or regenerates anything on its own — so that
  my human-in-the-loop control over when a full regen happens is preserved by
  default.
- As a developer who wants my blueprint continuously accurate, I can configure a
  staleness threshold so that once enough targeted updates accumulate a full
  regeneration happens automatically (under `auto_blueprint`) or I am prompted to
  run one, so that I do not have to watch a counter and trigger regens by hand.
- As a developer whose blueprint is created for the first time through the
  review fallthrough, that commit is recorded as a create rather than an update,
  so that the create/update history is honest and the cadence baseline is
  well-defined.

## Acceptance Criteria

- [ ] **Cadence signal in update mode.** When `/jim:blueprint` runs in update
      mode against an existing blueprint and one or more targeted updates have
      been applied since the blueprint was last fully generated, the run reports
      that count (e.g. "N targeted updates since last full generate"). When the
      count is zero, no such line is shown.
- [ ] **Baseline is the last full generate.** A full generate (whole-group
      regeneration in generate mode, including the absent-blueprint fallthrough)
      establishes or advances the baseline, so subsequent update-mode runs count
      only targeted updates applied after that generate. A blueprint fully
      generated with no intervening targeted updates reports nothing (count 0).
- [ ] **Both invocation paths.** The signal surfaces whether update mode was
      invoked interactively (`--from-review` / `--since` by a developer) or
      automatically by `/jim:review`'s blueprint-update step; under
      `auto_blueprint` it appears in the unattended write summary.
- [ ] **Fix-only ledger-only-commit preserved.** A fix-only update — every
      proposed edit withheld at the violation fork — still commits `ledger.md`
      alone, with no `spec.md` write forced by the cadence signal; spec 031's
      ledger-only-commit property is carried forward unbroken. *(External
      constraint — Upstream Spec: spec 031.)*
- [ ] **Opt-in staleness threshold (default off).** A single integer
      configuration key sets the staleness threshold, and it is **disabled by
      default**. When disabled — the default — the feature is signal-only: no
      regeneration is ever triggered and the update's completion is never gated,
      preserving today's human-in-the-loop control. The threshold does not affect
      *display* — the count is still surfaced whenever it is ≥ 1 regardless of
      the threshold's value.
- [ ] **Threshold-triggered regeneration.** When the accumulated count reaches
      the configured threshold, a full whole-group regeneration is triggered.
      Under `auto_blueprint` it runs unattended — subject to spec 031's
      criticality-graded autonomy, so a `critical`/`high` invariant or Provides
      downgrade during that regen still prompts. When `auto_blueprint` is off,
      the developer is prompted / strongly recommended to run it and it never
      fires on its own. Either way the triggered regeneration advances the
      baseline, resetting the count.
- [ ] **First-time create labeled as a create.** A blueprint created for the
      first time (the absent-blueprint fallthrough) is committed with a message
      identifying it as a create, distinct from a targeted update's commit
      message. A normal targeted update remains labeled as an update.
- [ ] **Graceful when no baseline is recorded.** For a blueprint created before
      this feature (no recorded baseline), update mode reports that no
      full-generate baseline is recorded rather than erroring; the next full
      generate establishes the baseline and the signal begins reporting normally.
      When no trustworthy baseline or count can be determined, the threshold
      never fires a regeneration — it falls back to the signal / prompt rather
      than acting on an unreliable count.

## UI Mockup

<!-- Conceptual; exact wording is a plan concern. -->
```
Blueprint update — jim: 2 sections updated, committed.

  3 targeted updates since last full generate.
  (A whole-group regeneration reconciles drift the targeted lens cannot see.)
```

Immediately after a fresh full generate (count 0), the line is simply absent.

When the threshold is configured and reached, the run escalates instead of just
reporting — unattended under `auto_blueprint`:

```
Blueprint update — jim: 5 targeted updates reached the regen threshold (5).
Running a full whole-group regeneration to reconcile accumulated drift…
```

With `auto_blueprint` off, the same condition prompts rather than fires:
`5 targeted updates — run a full regen now? (/jim:blueprint jim)`.

## Out of Scope

- **A skill-chosen threshold or a blocking gate.** The threshold is a
  developer-configured value that is disabled by default — the skill never picks
  a magic number on its own, and the triggered regeneration is an opt-in
  automation, not a gate that blocks the update's completion.
- **A second dedicated auto knob.** The auto-fire-vs-prompt decision reuses the
  existing `auto_blueprint`; no new boolean (e.g. `auto_blueprint_regen`) is
  added. One integer threshold key is the whole new config surface.
- **Changing the diff-scoped nature of targeted updates.** Updates remain narrow;
  this spec only makes their accumulation visible and, on opt-in, actionable.
- **Back-stamping a baseline into existing blueprints.** Pre-feature blueprints
  self-heal on their next full generate rather than being migrated.
- **Whether a review should auto-*create* a first blueprint under
  `auto_blueprint`.** That the fallthrough auto-creates a complete blueprint is
  settled by specs 030/031 and is not revisited here; this spec only corrects
  how that create is *labeled* and folds it into the baseline.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive. The mechanism below was worked through and approved with the developer during scoping, so it is a strong design direction rather than an open exploration; the architect still owns its exact shape.*

### Insight 1: Single-writer watermark for the baseline

- **Relates to AC:** *"A full generate establishes or advances the baseline"* (AC #2)
- **Surfaced as:** a `last_full_generate` frontmatter field on the blueprint, written **only** by generate mode (the sole writer), stamped via `jimfile.sh now`.
- **Levelled-up requirement (already in the ACs):** the baseline is "the last full generate", however stored.
- **Deflection reason:** Delegation.
- **Architect note:** the developer explicitly rejected a two-writer counter (generate resets, update increments) because having update mode mutate the count in `spec.md` would dirty `spec.md` on every run and break the fix-only ledger-only-commit property (AC #4). A single-writer watermark keeps update mode read-only w.r.t. the blueprint. Decide field placement, format, and the blueprint-template addition. Generate mode's differential path (existing blueprint) is still a full whole-group scan (Steps 2–3), so it too advances the watermark.
- **Routing hint:** Architect to decide.

### Insight 2: Deterministic ledger-derived count

- **Relates to AC:** *"reports that count"* / *"no `spec.md` write to maintain the count"* (AC #1, #4)
- **Surfaced as:** a new deterministic `jimledger.sh` subcommand (working name `updates-since <blueprint-dir> <iso>`) that counts `blueprint finished` events in the dir's `ledger.md` whose timestamp is strictly after the watermark; update mode reads the watermark and calls it, writing nothing to `spec.md`.
- **Levelled-up requirement (already in the ACs):** N is derived from existing recorded state, read-only.
- **Deflection reason:** Delegation.
- **Architect note:** the ledger already records one `blueprint finished` per completed update (spec 031) and per fallthrough create (the current absent-blueprint path). The fallthrough create's own `finished` event sits *at* the watermark, so a strictly-after comparison correctly excludes it → a freshly created blueprint reads 0. Belt-testable in `tests/jimledger.sh` like the spec 026/030 diff-range and commit-blueprint cases (count 0 / N / absent-ledger). Consider whether "absent watermark" (AC #7) is handled in the subcommand or the skill.
- **Routing hint:** Architect to decide.

### Insight 3: create/update mode on the blueprint commit

- **Relates to AC:** *"committed with a message identifying it as a create"* (AC #6)
- **Surfaced as:** a mode argument on `jimledger.sh commit-blueprint <dir> [create|update]`, defaulting to `update` for back-compat; the absent-blueprint fallthrough passes `create`, the normal update path passes (or defaults to) `update`.
- **Levelled-up requirement (already in the ACs):** a first-time create is distinguishable from a targeted update in history.
- **Deflection reason:** Delegation.
- **Architect note:** this corrects a wart introduced when the fallthrough was routed through `commit-blueprint` (which hardcodes `docs(blueprint): update 000-blueprint`). Nothing *consumes* the commit message programmatically, so the change is history-honesty, not a parse contract — but it also makes the create/update distinction legible in git log. Belt-testable (create subject vs. update subject). This is the same "vary the commit message" idea previously declined for spec 031's fix-only ledger-only case; there it was cosmetic, here create-vs-update is a real semantic distinction.
- **Routing hint:** Architect to decide.

### Insight 4: Threshold config key and trigger point

- **Relates to AC:** *"a single integer configuration key sets the staleness threshold"* / *"a full whole-group regeneration is triggered"* (AC #5, #6)
- **Surfaced as:** a bare-name integer `jimconf` key (working name `blueprint_regen_threshold`), default `"0"` (disabled), resolved through the existing `resolve()` convention like `review_fanout_cap` / `auto_security_loop_limit`; the auto-fire-vs-prompt decision reuses the existing `auto_blueprint` (the developer confirmed a lean one-knob design — no dedicated `auto_blueprint_regen` boolean).
- **Levelled-up requirement (already in the ACs):** an opt-in, default-off threshold that triggers a regen; unattended under `auto_blueprint`, prompted otherwise.
- **Deflection reason:** Delegation.
- **Architect note:** decide the **trigger point** — checking at the *start* of an update run and regenerating *instead* of the targeted update (once count ≥ threshold) avoids a redundant targeted edit that a whole-group regen would immediately supersede; checking *after* applying the update is simpler but wastes that edit. Either satisfies AC #6. The regen path is generate mode's existing differential regeneration (Steps 2–4a), which already advances the watermark (Insight 1) and already honors spec 031's graded autonomy — so "triggered regen resets the count" and "critical/high still prompts" fall out for free rather than needing new logic. **Validate the count/threshold before acting** (see security.md): the count now gates an unattended action, so a malformed watermark or tampered ledger must degrade to "do not fire" (AC #8), not to a spurious regen.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Always show the count, or only past a threshold?~ → *Display* is always
  shown whenever N ≥ 1 (zero line suppressed); there is no display threshold.
  Separately, an opt-in *regen* threshold (default off) governs the auto-regen
  trigger — a distinct concern from display.
- [x] ~Signal only, or also auto-regenerate at a threshold?~ → Both: signal-only
  by default; a configurable, default-off threshold triggers a full regen when
  reached (developer decision, folded in during scoping — supersedes issue #27's
  original "no auto-regen" scope).
- [x] ~One knob or two for the auto-regen?~ → One integer threshold key; the
  auto-fire-vs-prompt decision reuses the existing `auto_blueprint` (lean design,
  confirmed with the developer).
- [x] ~Does the signal surface in the auto (review-triggered) path?~ → Yes, both
  interactive and auto; it appears in the unattended write summary under
  `auto_blueprint`.
- [x] ~How to handle blueprints with no recorded baseline?~ → Report that no
  baseline is recorded rather than erroring; self-heal on the next full generate.
  The threshold never fires without a trustworthy baseline/count.
- None blocking.
