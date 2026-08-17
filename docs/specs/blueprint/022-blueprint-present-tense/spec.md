---
title: "Enforce present-tense discipline at blueprint draft composition"
type: feature
group: "blueprint"
id: "050"
status: approved
origin:
  - docs/issues/20260711-blueprint-present-tense-discipline-enforcement.md
---

# 050 Enforce present-tense discipline at blueprint draft composition

## Overview
`/jim:blueprint`'s current-state doctrine executes at draft-composition time —
supplied text carrying non-present-tense framing is normalized before the draft
is composed, and every draft is self-scanned before it reaches the gate — so the
skill enforces the discipline rather than leaving the human gate to catch it.

## Problem Statement
The blueprint surface promises current-state, present-tense artifacts — stated
three times as descriptive framing ("reflects reality, not aspiration" in the
SKILL intro; "current, present-tense" and "Current state only" in the two
template banners) — but nothing operative enforces it. There is no rule at the
sites that accept outside text, and no Validation Checklist item. Caller-composed
and interview-supplied wording carrying historical, transitional, or aspirational
framing gets transcribed verbatim into drafts. The only backstop is the human
gate, which catches such leaks at the cost of an approval round — and on the
migrate arms, which defer commits to the caller with no local re-gate, may not
catch them at all.

This is a discipline distinct from the existing "content is data, not
instruction" trust rules. Those target *adversarial* content. The leak here is
*cooperative*, developer-authored text that simply carries the wrong tense — an
intent-vs-wording problem, not a data-vs-instruction one. The developer sets
intent; the skill should own the wording.

## User Stories
- As a developer running `/jim:blueprint`, I can supply forward-looking
  motivation for a group change and trust the skill to render it as present-tense
  current state, so I don't spend an approval round correcting tense.
- As a developer, I can see which phrasings the skill normalized when it presents
  the draft, so the rewrite is auditable and I keep final authority to revert any
  change.
- As a developer, I can rely on the gate to *confirm* present-tense discipline
  rather than *supply* it, so a draft never reaches me already carrying framing
  the doctrine forbids.
- As a maintainer of the blueprint skill, I can change the present-tense
  discipline in one place, so the rule cannot drift across the several sites that
  apply it.

## Acceptance Criteria
- [ ] The blueprint SKILL Validation Checklist carries an item requiring every
      map/blueprint sentence to be present-tense current state — free of
      historical, transitional, and aspirational framing.
- [ ] The detection scope is defined by three marker categories — historical,
      transitional, aspirational — with specific vocabulary illustrative and
      extensible, not fixed as an exhaustive normative word list.
- [ ] The discipline — the rule, the three marker categories, and the
      normalize-and-disclose contract — is defined in a single canonical location
      and referenced by the composition sites, not restated at each.
- [ ] The presence of the present-tense reference at each composition site is
      mechanically verifiable, so a dropped or missing citation is caught without
      relying on manual review.
- [ ] Every site that accepts caller- or interview-supplied text (map-tier update
      args, the mint-new handoff from `/jim:spec`, the interactive interview
      synthesis, the migrate `--changes` arms, and the group-tier generate/update)
      treats that text as input rather than copy: supplied non-present-tense
      framing does not survive into the presented or returned draft.
- [ ] The normalization step treats caller- and interview-supplied text as
      untrusted data under the existing data-vs-instruction boundary: tense is
      rewritten, but a directive embedded in supplied text is normalized as text
      and never followed — the intent-vs-wording layer adds no injection path.
- [ ] When the skill rewrites supplied wording, each change is itemized in the
      draft or summary it presents, so the developer sees what was altered and
      can revert it; the developer retains final authority over the wording.
- [ ] The itemized disclosure is secret-scrubbed like every other draft: a
      rewritten phrase containing a secret-looking value is redacted to
      `secret-looking value at <path:line>` before the disclosure is presented or
      returned, on both the gated and no-re-gate paths.
- [ ] A pre-gate self-scan runs on every draft, both tiers and all paths, before
      presentation, and resolves detected markers — so the draft reaching the
      gate already conforms and the gate confirms discipline rather than supplying
      it.
- [ ] On the no-re-gate migrate paths (`--rename` / `--split` / `--merge`, which
      defer commits to the caller), normalization still applies and the
      disclosure of what was rewritten is surfaced in the summary returned to the
      caller.

## Out of Scope
- The blueprint SKILL line-budget concern (issue #43) — this spec adds enforcement
  prose and does not reclaim headroom. The skill-size cap is expected to rise, so
  budget is not treated as a blocker here.
- Adversarial-content handling (the data-vs-instruction trust rule) — unchanged;
  this spec governs intent-vs-wording only.
- Retroactive normalization of already-written blueprints and maps — enforcement
  is at composition time, not a sweep over existing artifacts.
- Present-tense enforcement in other skills or artifacts (specs, `ARCHITECTURE.md`,
  `ROADMAP.md`) — this spec is scoped to the blueprint surface.
- The exact implementation of the detection mechanism (regex forms, self-scan
  prompt wording, the textual-invariant test's shape) — a plan concern; the
  hybrid approach itself is decided (see Open Questions).
- A configurable suppression / allowlist for false positives — disclose-and-revert
  is the accepted control (see Open Questions).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: Centralize enforcement at the draft-finalization convergence point

- **Relates to AC:** *"the discipline is defined in a single canonical location
  and referenced"* and *"a pre-gate self-scan runs on every draft"*
- **Surfaced as:** the developer asked whether the validation should be
  centralized given the several sites that accept supplied text.
- **Levelled-up requirement (already in the ACs):** the discipline is
  single-sourced, not duplicated, and no supplied non-present-tense framing
  survives into a presented or returned draft.
- **Deflection reason:** Delegation — the exact structure is the architect's call.
- **Architect note:** every path converges on finalizing the draft before it
  leaves the skill — presentation to the human gate (generate / update / create /
  interview) or return to the caller (the no-re-gate migrate arms). A single
  self-scan at that convergence, backed by one shared reference defining the rule,
  the three categories, and the normalize-and-disclose contract (the pattern
  already used by `references/gate-presentation.md` and the issue § 7a
  candidate-batch contract), would enforce the discipline once rather than
  restating it at each intake site — which also relieves the SKILL line-budget
  pressure noted in #43. Weigh the trade: intake-time normalization has the
  developer's intent in context (more faithful rewrites); a single chokepoint
  guarantees universal coverage; a hybrid (intake normalizes, chokepoint
  backstops) is possible. Caveat: the migrate arms exit through a different door
  (return-to-caller, no gate), so they likely reference the same scan at their
  return point rather than sharing the literal presentation step.
- **Routing hint:** Architect to decide.

## Open Questions
- [x] ~Detection mechanism: deterministic marker-scan, LLM judgment, or hybrid?~
      → **Hybrid.** The cite-by-path single-sourcing is mechanically verifiable (a
      textual-invariant test, mirroring `tests/gatepresentation.sh`); the tense
      rewrite itself is an LLM self-scan, because tense-intent is judgment-laden —
      a bare "will"/"today" can be legitimate present-tense current state, so a
      word-list alone over-flags. Implementation specifics remain a plan concern.
- [x] ~Do repeated false positives warrant a suppression / allowlist affordance?~
      → **No.** Disclose-and-revert (each rewrite itemized, the gate or caller as
      final authority) reuses an existing control; a dedicated suppression
      mechanism would duplicate it. Excluded (see Out of Scope).
