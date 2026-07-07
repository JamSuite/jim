---
spec: "docs/specs/jim/038-partition-migration/spec.md"
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-07-07"
---

# Security Review: Partition migration skill

## Summary

**Findings:** 0 Critical · 3 Notable · 3 Advisory

Reviewed spec.md (requirements-gap lens); no plan.md exists yet. STRIDE
sweep completed; LINDDUN active via incidental credential exposure in
scanned content, most categories N/A (no personal-data subjects).

## Coverage

- spec.md — reviewed 2026-07-07 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Processes code structure and project docs; no personal-data subjects by design |
| Credentials | Yes | Incidental: scanned code/config may contain secret-looking values; committed artifacts (map, blueprints, issues) are the exposure path |
| Session data | No | — |
| Internal-only | Yes | Dependency graph, partition proposals, punch-list findings, ledger events — all committed to the project repo |
| Public | No | — |

## Findings

### 1. Extractor activation boundary not carried by an AC

- **Severity:** Notable
- **Description:** The Handoff points at the spec 035 registry pattern, but
  no AC pins the constraint that extraction tooling activates **only** from
  operator-owned configuration. AC #17 keeps scanned content from binding
  *decisions*; command *activation* is a distinct, sharper boundary — a
  tool name or "run this" string encountered in scanned code, an existing
  map, or README prose must be inert (the never-execute-config-content
  model, spec 035 Finding 1).
- **Suggestion:** Add an AC: extraction and assessment tooling is activated
  only from operator-owned configuration; strings encountered in scanned
  artifacts never select, parameterize into execution, or execute a
  command.
- **Route:** Spec
- **Relates to:** AC #2, #3, #17; Handoff Insight 1

### 2. Disposition of superseded group blueprints unspecified

- **Severity:** Notable
- **Description:** In `repartition` mode the old partition's `000-blueprint`
  artifacts remain authoritative-looking living artifacts unless retired.
  Two coexisting boundary authorities let stale invariants and faces keep
  driving verification and mislead the assignment advisor. Freeze-history
  (AC #14) covers numbered specs; it says nothing about the *living*
  blueprints of retired groups.
- **Suggestion:** Add an AC: materialization in `repartition` mode
  explicitly marks superseded group blueprints as retired (pointing at the
  new map), through the blueprint surface, so exactly one partition
  authority exists after migration.
- **Route:** Spec
- **Relates to:** User Story #2; AC #7, #14

### 3. Extractor-emitted paths unvalidated at migration-phase use

- **Severity:** Notable
- **Description:** Map writes inherit `valid-relpath` via delegation
  (AC #7), but the migration's own phases — coverage set-difference,
  evidence fan-out scoping, proposal content — consume extractor output
  first. An adversarial repo or misbehaving extractor could emit absolute
  or `..` paths that scope scanning outside the repo or corrupt the
  coverage math.
- **Suggestion:** In the plan: validate every extractor-emitted path
  through the existing relpath/safe-path boundary at ingestion
  (`safe_path_param` precedent); failures are reportable hygiene, never
  silently used or dropped.
- **Route:** Plan
- **Relates to:** AC #4; Handoff Insight 1

### 4. Unbounded extractor execution and fan-out

- **Severity:** Advisory
- **Description:** Operator-wired extractor commands and the per-group
  evidence fan-out have no stated bounds; a hung tool or huge repo wedges
  the run.
- **Suggestion:** In the plan: run extractor commands under a timeout
  (`verify_registry_timeout` precedent) and cap the evidence fan-out
  (`verify_fanout_cap` precedent); exhaustion degrades the run with a named
  reason.
- **Route:** Plan
- **Relates to:** Handoff Insights 1, 3

### 5. Proposal rationale should cite extracted evidence

- **Severity:** Advisory
- **Description:** The human map gate is the control against scanned
  content nudging the partition (e.g. prose steering toward `none`
  territory mode, or an exclusion that lets code escape verification). An
  unsupported suggestion is easiest to catch when every proposed
  group/territory cites its evidence.
- **Suggestion:** Strengthen AC #2's presentation requirement: the proposal
  cites extracted evidence (edge counts, representative references) per
  proposed group, so unsupported boundary suggestions stand out at the
  gate.
- **Route:** Spec
- **Relates to:** AC #2, #6, #17

### 6. Migration ledger events must stay content-free

- **Severity:** Advisory
- **Description:** AC #16 specifies counters; the ledger is jim's trusted
  content-free metrics channel (spec 026 Finding 7). A migrate event
  carrying path or content values would quietly break that trust property.
- **Suggestion:** In the plan: migrate events carry counters only — never
  path, name, or content values in their kv fields.
- **Route:** Plan
- **Relates to:** AC #16

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Local single-developer tool; no external identity boundary introduced |
| Tampering | Yes | Findings 2, 3 |
| Repudiation | No | Started/finished ledger events audit each run |
| Information Disclosure | Yes | Covered by AC #17 (secret redaction); Finding 6 hardens the ledger channel |
| Denial of Service | Yes | Finding 4 |
| Elevation of Privilege | Yes | Findings 1, 5 (content→execution would cross the operator trust boundary; a content-shaped partition lets code escape verification) |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | Graph links code units, not people; no personal-data subjects |
| Identifying | N/A | No personal-data subjects |
| Non-repudiation | N/A | No subject-deniability concerns; auditing is deliberate and developer-scoped |
| Detecting | N/A | No subject-presence inference |
| Data Disclosure | Yes | Incidental secrets in scanned content reaching committed artifacts — covered by AC #17 redaction; no new finding |
| Unawareness & Unintervenability | No | Operator initiates every run and gates every write |
| Non-compliance | N/A | No stated privacy policy or regulation applies to this internal artifact flow |

## Routing Recommendations

### Spec amendments
*Applied 2026-07-07 (developer-confirmed routing): Findings 1 and 2 added
as ACs #18–19; Finding 5 folded into AC #2.*
- Finding 1: AC pinning config-only tool activation (content never executes).
- Finding 2: AC on retiring superseded group blueprints in `repartition` mode.
- Finding 5: evidence-cited proposal presentation folded into AC #2.

### Plan amendments
*Held for the plan phase (developer-confirmed 2026-07-07) — to be picked up
when plan.md is drafted.*
- Finding 3: relpath validation of extractor output at ingestion.
- Finding 4: extractor timeout + evidence fan-out cap.
- Finding 6: content-free migrate ledger events (counters only).

### Candidate issues
No findings routed to Issue this run.
