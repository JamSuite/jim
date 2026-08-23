---
id: 20260702-cache-per-issue-analysis
num: 33
title: "Cache per-issue analysis"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issues-system, insights, performance]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-02T10:54:12Z
updated: 2026-07-02T10:54:12Z
origin: conversation
---

## Description

## Description

### The gap

The analytical read verbs (`insights` today, a `trends` deep-mode or the #5
footprint analysis tomorrow) regenerate their synthesis from scratch on every
run. The `issue-analyst` reads `INDEX.md` plus the individual issue **bodies**
to detect semantic convergence, so cost and latency scale roughly linearly with
collection size. On jim's own ~32-issue collection a full insights run already
spends ~50k tokens and ~3 min, dominated by body reads — and jim is used
primarily on *other* projects, whose issue collections are frequently far
larger, so the linear-scaling cost bites real adopters well before it bites this
repo.

### What is already cached (and what isn't)

The **deterministic layer** is effectively memoized: `index.sh` computes the
roster, `## Graph`, and integrity warnings in bash at zero token cost, and
`render.sh` re-invokes `index.sh` only when `INDEX.md` is stale. The
**synthesis layer** — the LLM's semantic clustering over body prose — has no
equivalent memoization and is what recomputes every run.

### Proposed action

Scope an incremental, content-hash-keyed cache for per-issue *derived
artifacts* so the analytical verbs read cheap summaries instead of full bodies,
and only **changed** issues get re-derived — making synthesis cost scale with
churn, not collection size. Sketch of the ladder:

1. **Push more determinism into `index.sh`** (cheapest, no invalidation risk):
   e.g. label-based cluster rollups the analyst currently re-derives by reading
   bodies. Pure bash, scales for free.
2. **Per-issue derived-artifact cache**: a compact summary (semantic essence /
   cluster hints; and, if #5 lands, its predicted file/symbol footprint) stored
   as a sidecar or expanded `INDEX` field, keyed by that issue's content hash.
   Only re-summarize issues whose hash changed. This shifts cost to write-time
   and bounds per-run read cost.
3. **Explicitly skip** whole-insights-output caching: it busts on any single
   add/edit/close, so its hit rate against a changing collection is low.

### Relationship to #5

This is the substrate #5 would ride on, not a subset of it.
[[20260603-codebase-aware-implementation-independence-analysis-for-parallel]]
spends *more* per run (footprint probes per issue) to raise verdict fidelity;
this issue spends *less* per run by caching per-issue derived artifacts. A
footprint prediction is exactly the kind of per-issue derived artifact worth
hashing and caching, so landing this first would blunt #5's per-run cost.

### Why deferred (sequencing, not scale)

Deferred by leverage — it sits behind higher-priority blueprint and integrity
work — **not** because the need is distant. The scale trigger is *downstream*
collection size, not this repo's: any adopter project with a large issue
collection already pays the linear cost on every insights run, so the "revisit
when it hurts" condition (insights latency past tolerance, or bodies no longer
fitting one analyst context) may already be met in the field. Priority is `low`
as a scheduling choice, not a claim that the pain is hypothetical.
