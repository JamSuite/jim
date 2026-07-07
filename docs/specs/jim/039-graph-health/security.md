---
spec: "docs/specs/jim/039-graph-health/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-07-07"
---

# Security Review: Graph-health metrics in the reconcile pass

## Summary

**Findings:** 0 Critical · 1 Notable · 2 Advisory (open) · 3 resolved

Dual-lens re-run: spec.md (requirements-gap) + plan.md (design-flaw).
Findings 1–3 from the spec-only run are resolved by the plan's design
decisions; the plan lens adds one Notable (prior-event key passthrough)
and two Advisories. LINDDUN remains omitted — structural metadata only.

## Coverage

- spec.md — reviewed 2026-07-07 (requirements-gap lens)
- plan.md — reviewed 2026-07-07 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Structural metadata only — group names, edge labels, path names |
| Credentials | No | The pass reads the persisted graph table and file *paths*, not code/config contents; face content is redacted upstream at write time (spec 034) |
| Session data | No | — |
| Internal-only | Yes | Partition metrics and path names in the report; numeric counters on the committed ledger |
| Public | No | — |

## Findings

### 1. Uncovered-path names are untrusted report content — RESOLVED

*Resolved 2026-07-07: plan DD 5 + tasks 2/5 — script-side sanitation and
top-level aggregation, skill-side ≤5-dirs + "+N more" cap, exact count on
the event.*

- **Severity:** Notable
- **Description:** Group names entering the report are slug-validated
  upstream (edges-verb hygiene) and territory paths pass `valid-relpath`,
  but the coverage metric's uncovered paths come from the working tree's
  tracked-file listing — arbitrary filenames that may carry
  directive-style text, escape sequences, or unbounded volume. AC #6 has
  the report naming these paths inline; on a tangle the uncovered set can
  be huge (alarm fatigue is a documented detector failure mode, spec 034).
- **Suggestion:** In the plan: render uncovered paths only after the same
  relpath-style sanitation the rest of the report applies, aggregate to
  directory level, and cap the rendered list (count always exact on the
  event; names truncated with an explicit "+N more"). Treat path names as
  data, never instruction, per the standing untrusted-content discipline.
- **Route:** Plan
- **Relates to:** AC #6; AC #2 (report rendering)

### 2. Malformed prior event must degrade to baseline, visibly — RESOLVED

*Resolved 2026-07-07: folded into spec AC #2; plan DD 3 implements it
mechanically (`last-reconcile` rc 2 → baseline + named degradation).*

- **Severity:** Notable
- **Description:** The delta reads the previous `op=reconcile` event back
  from `ledger.md` — a committed, hand-editable file. AC #2 covers the
  present/absent cases but not a *malformed* prior (non-numeric values,
  missing keys, injected text): rendering unvalidated prior values into
  the delta would put untrusted ledger content in the report, and a crash
  would break the reconcile's report path.
- **Suggestion:** Extend AC #2: a prior event that fails shape validation
  (the specs 034/028 extraction pattern) is treated as absent — baseline
  rendering — and the report names the degradation rather than silently
  hiding it.
- **Route:** Spec
- **Relates to:** AC #2, #4

### 3. Extended counters are emitted values, never lifted values — RESOLVED

*Resolved 2026-07-07: plan DD 4 + tasks 1–3 — script-emitted, sanitized,
int-or-na-validated values only; the skill copies them verbatim.*

- **Severity:** Advisory
- **Description:** AC #5 keeps event fields numeric, but the provenance
  constraint is implicit: every extended counter must be script-computed
  and validated at emission; no value may be interpolated from graph or
  face text (the "never a value lifted from content" discipline, spec 034),
  and a non-integer computation result must fail the emission, not ride
  the kv field.
- **Suggestion:** In the plan: emit extended counters through the same
  sanitizing emitter path as the existing seven, with a non-negative-
  integer check at emission time.
- **Route:** Plan
- **Relates to:** AC #4, #5

### 4. Prior-event unknown keys pass through to the renderer

- **Severity:** Notable
- **Description:** The `last-reconcile` contract prints unknown kv keys
  "shaped k=v with a safe charset" unvalidated, and the rendering contract
  says deltas render "per key present in the prior." A hand-edited ledger
  line could carry a crafted-but-charset-safe key (e.g.
  `all-clear-ignore-findings=1`) that flows through validation into the
  report's composition context — a low-power but unnecessary injection
  channel into the health block.
- **Suggestion:** Whitelist at the verb: `last-reconcile` prints only the
  documented counter keys (the seven + four), dropping anything else; the
  rendering contract correspondingly says "per *documented* key present in
  the prior." Unknown keys never reach the prompt path.
- **Route:** Plan
- **Relates to:** Interface Contracts (`last-reconcile`); Design Decision 3

### 5. `na` conflates not-applicable with measurement-failed

- **Severity:** Advisory
- **Description:** DD 5 maps both "map declares no territories" and "git
  unavailable" to `UNCOVERED na`. The verify engine's vocabulary doctrine
  (spec 035) keeps *not applicable*, *failed*, and *skipped* distinct so a
  clean line always means "checked"; here a broken environment silently
  reads as none-mode. Impact is bounded — the surrounding reconcile flow
  already hard-requires git for its commit — but the conflation is silent.
- **Suggestion:** Emit a reason fact alongside (e.g.
  `UNCOVERED_NA_REASON no-territories|no-git`) rendered in the report, or
  document in the methodology that git absence is impossible within the
  reconcile flow and `na` therefore always means territory-less.
- **Route:** Plan
- **Relates to:** Design Decision 5; spec AC #7

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Local single-developer tool; no identity boundary introduced |
| Tampering | Yes | Findings 2 (resolved), 4 (unknown-key passthrough from a hand-edited prior event) |
| Repudiation | No | Events are append-only and committed; the run remains audited |
| Information Disclosure | No | Structural metadata only; path names are already repo-visible; events stay content-free (AC #5) |
| Denial of Service | No | Group-scale graph, one tracked-file pass; report volume bounded per Finding 1's cap |
| Elevation of Privilege | No | Measurement-only: no execution surface, never vetoes or gates (AC #3, #10) |

## Artifact Misalignment

- **Finding M1 — Coverage naming vs the rendering cap:** Spec AC #6 says
  the report "names the uncovered directories"; plan DD 5 renders at most
  5 plus `+N more` (per resolved Finding 1). A named subset with an exact
  event count is a defensible reading, but the cap should be explicit
  where the contract lives. Route: Plan — task 5's methodology § Graph
  health states the cap as the documented rendering rule. Advisory.

## Routing Recommendations

### Spec amendments
*Applied 2026-07-07 (developer-confirmed routing): Finding 2 folded into
AC #2. No new spec-routed findings in the dual-lens re-run.*
- Finding 2: AC #2 extended — malformed prior event degrades to baseline
  rendering, named in the report. (Resolved.)

### Plan amendments
*Findings 1 and 3 from the spec-only run are addressed by plan DD 4/5 and
tasks 1–3/5 (resolved). Dual-lens findings applied 2026-07-07
(developer-confirmed routing):*
- Finding 4: `last-reconcile` output whitelisted to the documented counter
  keys; deltas render only for documented keys (DD 3, Interface Contracts,
  task 3).
- Finding 5: `UNCOVERED_NA_REASON no-territories|no-git` fact added,
  rendered in the report (DD 5, Interface Contracts, task 2).
- Finding M1: the ≤5 + "+N more" cap stated as the documented rendering
  rule in methodology § Graph health (task 5).

### Candidate issues
No findings routed to Issue this run.
