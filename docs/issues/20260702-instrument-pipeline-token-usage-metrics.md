---
id: 20260702-instrument-pipeline-token-usage-metrics
num: 32
title: "Instrument the pipeline with token-usage metrics"
status: open
priority: medium
labels: [jimledger, metrics, profiling]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-02T10:26:11Z
updated: 2026-07-02T10:26:11Z
origin: conversation
---

## Description

## Context

The ledger already records per-stage `started`/`finished` epochs (from which
`metrics` derives durations, runs, interruptions), and `review.md` carries
mineable outcome frontmatter. The missing dimension is **token consumption** —
without it, configurations can't be profiled (e.g. "does `review_model: haiku`
cut investigator tokens, and what does it do to verdict/finding quality?").

## What

Add token-usage metrics to the pipeline — totals, per-stage, per-skill —
joined against the outcome stats jim already records. Three tiers:

1. **In-band subagent usage (cheap, no new infra).** Every `Agent(...)`
   result already surfaces the subagent's token count to the orchestrator.
   `/jim:review` records `investigator_tokens=` / `investigator_count=` (and
   the resolved `review_model` / `review_depth`) as kv on its `finished`
   event and in `review.md` frontmatter; same pattern for `/jim:research`
   dispatches and future swarms. This alone enables the review-model A/B
   experiment.
2. **Main-thread per-stage totals (open design fork).** The skill can't see
   its own consumption, so spec/plan/build totals need an out-of-band
   source: (a) a deterministic helper snapshotting the session transcript's
   usage block at stage boundaries — works today, but the JSONL format is
   documented as internal and version-unstable (belt tests + graceful
   degradation required); or (b) OTEL export (`claude_code.token.usage`,
   model-attributed) to a local file joined against ledger stage windows —
   stable but opt-in telemetry. Resolve at spec time.
3. **Config stamping + analysis surface.** Stamp resolved knob values per
   run (nothing to group comparisons by otherwise); extend `metrics`'
   fixed-key allowlist with the token keys; cross-run comparison mines
   `review.md` frontmatter, with a dedicated profile view as a possible
   later slice.

Phase 1 (tier 1 + config stamping) is spec-ready; tiers 2–3 carry the
source fork and may warrant a brainstorm first. Real cost data would also
feed [[20260630-build-the-invariant-verification-engine]]'s
criticality-keyed verification appetite.

Security note for any transcript/OTEL parser: extract numeric usage only —
never echo conversation content into committed artifacts.
