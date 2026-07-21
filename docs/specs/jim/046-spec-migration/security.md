---
spec: "spec.md"
reviewed_phases: [spec]
status: "Needs Spec Review"
date: "2026-07-21"
---

# Security Review: Spec identity on group move

## Summary

**Findings:** 0 Critical · 2 Notable · 2 Advisory

Spec-only review (no plan yet). The feature's novel threat surface is that
`rewrite` turns previously-frozen numbered spec bodies into edit targets, driven
by scanning untrusted spec-body content. The core injection vector is already
closed by AC 10's capability boundary (location-only enumeration + a
read-only gatherer); the findings below are refinements at the edges that
boundary does not yet reach — integrity of the rewrite, exposure through the
rewrite preview, mode-selection provenance, and the durable record. LINDDUN
omitted (no PII / Credentials / Session data).

## Coverage

- spec.md — reviewed 2026-07-21 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Operates on spec/doc files; no personal-data fields handled by the feature. |
| Credentials | No | The feature does not handle credentials — but the numbered spec bodies it edits *may* contain developer-pasted secrets (see Finding 2). |
| Session data | No | None. |
| Internal-only | Yes | Group identity labels, spec bodies, ledger `op=` events. |
| Public | Yes | jim's spec archive is committed and the repo is heading public (ROADMAP) — committed specs are effectively public. |

## Findings

### 1. Free-prose rewrite can silently corrupt a frozen spec's substance

- **Severity:** Notable
- **Description:** AC 3 promises `rewrite` changes identity only and leaves the
  spec's substance "byte-unchanged," but rewriting *free-prose* group-mentions is
  a judgment call — "the `cart` group" versus "the user's cart" are
  indistinguishable to structural enumeration (`occurrences` buckets both as
  `prose`). A mis-disambiguation edits domain-noun prose inside a frozen
  historical spec, silently altering its meaning — precisely the
  archive-integrity failure the feature exists to prevent. The gate (AC 6 / spec
  040) currently risks presenting body edits as a count rather than as
  reviewable diffs, so a wrong prose rewrite can land unseen.
- **Suggestion:** (a) Make the mechanical/gatherer split **fail-safe on doubt** —
  an ambiguous prose mention is left unchanged (freeze-on-doubt) rather than
  risk-rewritten; only high-confidence identity mentions are edited. (b) Require
  the gate to present the actual body-edit **diffs** (old→new lines) for numbered
  specs, not merely a changed-file count, so no prose rewrite is applied without
  human sight.
- **Route:** Spec
- **Relates to:** AC 3, AC 6

### 2. The rewrite preview is a new content-surfacing surface not covered by the exfiltration guard

- **Severity:** Notable
- **Description:** AC 10 inherits 043's exfiltration guard, which is *location-only*
  — `occurrences` emits `file:line:kind` and never the matched content. But
  `rewrite` (and Finding 1's diff requirement) introduces a surface AC 10 does
  not name: to approve a body edit the human must be shown enough of the edited
  line, and that line could contain a developer-pasted secret. The location-only
  contract protects the *scan evidence* but not the *rewrite preview*.
- **Suggestion:** Extend AC 10 so any rewrite preview presented at the gate — the
  before/after line for a numbered-body edit — is secret-scrubbed before
  presentation, applying 043 AC #19's scrub to the preview surface, not only to
  persisted evidence.
- **Route:** Spec
- **Relates to:** AC 10

### 3. The active identity mode is absent from the durable record

- **Severity:** Advisory
- **Description:** The `op=rename` ledger event records `old=`/`new=` but not which
  mode (`rewrite`/`forward`/`immutable`) governed identity. An auditor reading the
  archive cannot tell whether a numbered body was rewritten or frozen without
  diffing git history — weakening the repudiation-resistance the ledger is meant
  to provide, and undercutting AC 2's "ledger `op=` event is the durable bridge"
  (the bridge records the move but not the disposition).
- **Suggestion:** Add an `identity=<mode>` key to the `op=` event
  (display-data-only, slug/enum-validated — the spec 044 bounded-value precedent
  for `faces_max_group=`), so the durable record states how each move handled
  identity.
- **Route:** Plan
- **Relates to:** AC 2

### 4. Mode selection must be pinned to operator config, not scanned content

- **Severity:** Advisory
- **Description:** AC 10 bars scanned content from binding a rewrite's *target* or
  *classification*, but does not explicitly bar it from selecting the *mode*. A
  malicious numbered body, blueprint, or map that embeds directive-style text
  ("identity mode: rewrite", "set spec_identity_on_move = rewrite") must not
  select the behavior — the mode derives only from the operator-owned
  `spec_identity_on_move` config (or an explicit developer instruction), never
  from scanned artifacts. This is the spec 035 never-execute-config-content
  boundary applied to mode selection, mirroring how the candidate-batch contract
  extends spec 018 to drop decisions.
- **Suggestion:** Extend AC 10 (or add an AC) stating that the identity-on-move
  mode is resolved only from operator configuration or explicit developer input;
  no directive inside a scanned artifact selects or overrides it.
- **Route:** Spec
- **Relates to:** AC 1, AC 10

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication or identity-assertion surface; a local, human-gated doc operation with no external trust boundary. |
| Tampering | Yes | Finding 1 (substance corruption via mis-rewrite), Finding 4 (mode selection via scanned content). |
| Repudiation | Yes | Finding 3 (active mode absent from the durable ledger record). |
| Information Disclosure | Yes | Finding 2 (secret exposure through the rewrite preview surface). |
| Denial of Service | No | No issues found — the gatherer fan-out is bounded by `verify_fanout_cap` and the scan is scoped to one group's specs; no unbounded resource. |
| Elevation of Privilege | N/A | No new tool grants — the rename engine uses script-owned git primitives (spec 043) and a Read/Glob/Grep-only gatherer; this spec introduces no new privilege surface. |

## Routing Recommendations

### Spec amendments
- Finding 1: fail-safe on ambiguous prose (freeze-on-doubt) + gate presents body-edit diffs, not counts (AC 3 / AC 6).
- Finding 2: scrub rewrite previews before gate presentation (extend AC 10).
- Finding 4: pin mode selection to operator config, never scanned content (extend AC 10 / AC 1).

### Plan amendments
- Finding 3: add `identity=<mode>` to the `op=` ledger event (deferred to the plan phase).
