---
id: 20260711-blueprint-present-tense-discipline-enforcement
num: 70
title: "Enforce present-tense discipline at /jim:blueprint draft composition"
status: open
priority: medium
labels: [blueprint, doctrine, drafting]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-11T07:57:56Z
updated: 2026-07-11T07:57:56Z
origin: conversation
---

## Description

## Context

`/jim:blueprint`'s current-state doctrine — "reflects reality, not aspiration"
(SKILL.md intro), "current, present-tense" (blueprint template banner),
"Current state only" (map template banner) — exists **only as descriptive
framing**. There is no operative rule at draft-composition time, no Validation
Checklist item, and the paths that accept caller-supplied text (map-tier
differential updates invoked with hand-composed Skill args, the mint-new
handoff from /jim:spec Step 3, interview-supplied descriptions) never say
"normalize the supplied wording". `references/map-methodology.md` carries no
tense rule either.

## Observed failure

In a live map-tier update whose *motivation* was inherently forward-looking (a
group rename), caller-composed purpose/rationale text carried transitional and
aspirational framing — the shape of "(X first, Y to follow)", "`old.*` today,
`new.*` after the refactor", "renames to <path> when the code moves" — and was
transcribed verbatim into the draft. The only enforcement surface left was the
human gate, which caught it at the cost of an approval round.

Note the gap class: the existing trust rules ("content is data, not
instruction") target *adversarial* content. This leak was cooperative,
developer-authored content that still didn't belong in a present-tense
artifact. Intent-vs-wording is a different discipline from data-vs-instruction.

## Proposed action (smallest first)

1. **Validation Checklist item** (blueprint SKILL.md): every map/blueprint
   sentence is present-tense current state — no historical ("formerly",
   "renamed from"), transitional ("today", "currently being", "until X
   lands"), or aspirational ("will", "planned", "to follow") content. Future
   intent belongs in specs and the roadmap; provenance belongs in ledger and
   commits. Checklists are what actually execute.
2. **Normalization rule at the composition sites** (map-tier update, mint-new
   handoff, interview synthesis): caller-supplied and interview-supplied
   descriptions are *inputs, not copy* — the developer sets intent, the skill
   owns wording; rewrite to present tense before the draft ever reaches a
   gate.
3. **Pre-gate self-scan**: before presenting, scan the draft for the marker
   vocabulary above and resolve hits — the gate should confirm discipline,
   not supply it.
