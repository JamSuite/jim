---
id: 20260603-codebase-aware-implementation-independence-analysis-for-parallel
title: "Codebase-aware implementation-independence analysis for parallel work"
status: open
priority: medium
labels: [issues-system, trends, future-spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-06-03
updated: 2026-06-03
origin: docs/brainstorms/20260603-issue-command-consolidation.md
---

## Description

### The idea

Identify issues whose implementations are **isolated and independent** — i.e.
touch disjoint code — so they can be parallelized across developers/agents with
low merge-conflict risk. This is a higher-fidelity analysis than the
issue-metadata views (`stats`/`trends`): determining real conflict-independence
requires predicting each issue's file/symbol footprint against the actual
codebase and checking disjointness.

### Why issue context alone is insufficient

Issue context (the `relations:` graph, labels, body prose) yields only a weak,
asymmetric heuristic: it reliably rules a pair *out* (declared coupling) but
cannot reliably rule a pair *in* (absence of a declared relation ≠
implementation independence; label-disjointness is unreliable). A false
"independent" verdict is the expensive error — parallel work collides and trust
erodes — so the capability must be conservative and confidence-rated.

### Fidelity ladder

1. **Issue context only** — candidate isolated nodes via graph analysis. Cheap;
   folds into `trends` as a "parallel-work candidates (footprints unverified)"
   hint. *(This tier-1 hint is in scope for the consolidation spec.)*
2. **Codebase-aware footprint** — predict per-issue file/symbol footprint by
   exploring the repo, then check disjointness. Composes with jim's `Explore` /
   `/jim:research` machinery (a footprint probe per candidate issue). *(This
   ticket.)*
3. **+ git-history co-change** — detect hidden coupling and hot-file conflict
   magnets (lockfiles, config, barrel files) that footprint analysis misses.
4. **Actual diffs** — ground truth, but defeats the purpose (you parallelize
   *before* implementing).

### Inherent ceiling

Even tier 2–3 produces a *prediction* (the implementation may sprawl beyond the
predicted footprint) and cannot see **logical coupling** (disjoint files but a
shared contract — textual merge succeeds, build breaks). The honest ceiling is
"high-confidence, verify before you commit," not "proven conflict-free." UX
framing must reflect that — suggestions to verify, never guarantees.

### Proposed action

Scope a dedicated spec for a codebase-aware independence/parallelization
analysis (likely a new `/jim:issue` verb or a `trends` deep-mode). Define the
footprint-prediction method, the disjointness + hot-file + co-change checks, the
confidence model, and the "predicted not proven" UX. Out of scope for the
issue-command-consolidation spec, which ships only the tier-1 graph hint.

### Why deferred

Surfaced during the issue-command-consolidation brainstorm
(`docs/brainstorms/20260603-issue-command-consolidation.md`). It is the most
ambitious idea discussed and is cleanly separable from the command-surface work.
