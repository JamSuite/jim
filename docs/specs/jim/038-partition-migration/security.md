---
spec: "docs/specs/jim/038-partition-migration/spec.md"
reviewed_phases: [spec, plan]
status: Needs Spec Review
date: "2026-07-07"
---

# Security Review: Partition migration skill

## Summary

**Findings:** 0 Critical · 2 Notable · 1 Advisory open (7–9, from the
2026-07-07 dual-lens re-run). Prior findings 1–6 all resolved — 1/2/5
folded as spec ACs #18/#19/#2; 3/4/6 folded into plan DD 5/DD 6/DD 7.

Dual-lens re-run over spec.md (20 ACs) + plan.md (14 design decisions,
11 tasks). STRIDE sweep completed; LINDDUN active via incidental
credential exposure in scanned content, most categories N/A (no
personal-data subjects). One artifact misalignment surfaced (Finding 8).

## Coverage

- spec.md — reviewed 2026-07-07 (requirements-gap lens)
- spec.md + plan.md — dual-lens re-run 2026-07-07 (plan-phase lens +
  artifact misalignment; spec re-read at 20 ACs)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Processes code structure and project docs; no personal-data subjects by design |
| Credentials | Yes | Incidental: scanned code/config may contain secret-looking values; committed artifacts (map, blueprints, issues) are the exposure path |
| Session data | No | — |
| Internal-only | Yes | Dependency graph, partition proposals, punch-list findings, ledger events — all committed to the project repo |
| Public | No | — |

## Findings

*Findings 1–6 (spec-phase run): resolved — 1, 2, 5 folded as spec ACs
#18/#19/#2 (developer-confirmed routing); 3, 4, 6 folded into plan DD 5,
DD 6, DD 7 respectively. Findings 7–9 are from the dual-lens re-run.*

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

### 7. Manifest-derived tokens interpolated into the native scan's matching

- **Severity:** Notable
- **Description:** `jimpartition.sh scan` derives resolution prefixes from
  repo-controlled manifest content — go.mod `module` paths, workspace
  Cargo.toml `name` values (hyphen↔underscore normalized), Elixir
  `defmodule` names. The plan gates *emitted paths* at ingestion (DD 5)
  but does not require these tokens to be validated before they
  participate in pattern construction inside the scanner. A crafted
  manifest value carrying regex metacharacters or separator bytes could
  inject into the scan's grep/awk matching (the spec 035 Finding-1 class):
  mis-resolved edges, field-shifting upstream of output sanitization, or
  pathological regex behavior. Blast radius is bounded by `ingest`'s
  endpoint gate, but a poisoned resolution can still fabricate
  plausible-looking tracked-path edges.
- **Suggestion:** In plan Task 4: charset-gate every manifest-derived
  token before use (module / package / defmodule names against a
  conservative allowlist); match via fixed-string or `awk -v` + `index()`
  techniques, never raw regex interpolation; a non-conforming manifest
  degrades that file/crate/module to `UNMODELED`/`HYGIENE` — named in the
  coverage label, never silently used. Add fixtures with a
  metacharacter-bearing Cargo.toml `name` and go.mod `module`.
- **Route:** Plan
- **Relates to:** AC #2, #17; plan DD 3/4, Task 4

### 8. AC #15's letter pushes the mode write toward a jim surface

- **Severity:** Notable
- **Description:** AC #15 requires the run to "update the territory
  declarations and mode through the blueprint surface." The territory
  *mode* lives only in `group_territory` (jimconf.toml) — operator-owned
  config no jim surface writes. Plan DD 13 resolves this correctly
  (declarations through the surface; the mode flip is the developer's own
  verified config edit), but an implementer reading the AC literally is
  pushed toward making some jim surface write config — exactly the new
  trust boundary DD 13 refuses ("user config is data, not code").
- **Suggestion:** Reword AC #15's clause to match the boundary: "…updates
  the territory declarations through the blueprint surface after
  verifying the operator's own `group_territory` change…" (or
  equivalent), so requirement and config-ownership boundary agree.
- **Route:** Spec
- **Relates to:** AC #15; plan DD 13 (artifact misalignment)

### 9. Gatherer held/violated marking should fail closed toward the issue path

- **Severity:** Advisory
- **Description:** AC #12's judge-rung half rests on the gatherer's LLM
  marking of candidate invariants as held/violated over untrusted code. A
  prompt injection in scanned content that flips a violated candidate to
  "held" would push a currently-violated rule into a generated
  blueprint — the outcome AC #12 forbids — with the mechanical floor
  (DD 12) as backstop only for pattern/structure rungs.
- **Suggestion:** In the gatherer contract (Task 7) and generation
  handoff (Task 8): a "held" marking requires cited `file:line` evidence;
  an unevidenced, uncertain, or contested candidate defaults to the issue
  offer, never to a blueprint row. Fail closed toward tracking, not
  recording.
- **Route:** Plan
- **Relates to:** AC #12, #17; plan DD 11/12

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Local single-developer tool; no external identity boundary introduced |
| Tampering | Yes | Findings 2, 3, 7 |
| Repudiation | No | Started/finished ledger events audit each run |
| Information Disclosure | Yes | Covered by AC #17 (secret redaction); Finding 6 hardens the ledger channel |
| Denial of Service | Yes | Findings 4, 7 |
| Elevation of Privilege | Yes | Findings 1, 5, 9 (content→execution would cross the operator trust boundary; a content-shaped partition or invariant lets code escape verification) |

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

## Artifact Misalignment

- **Finding 8** — AC #15 required "declarations and mode" updated through
  the blueprint surface; the mode lives in config, which that surface
  does not write. Resolved (variant b, developer-confirmed): the skill
  sets the one key to the invocation's developer-typed target on gate
  confirmation — trusted-channel authorization — and AC #15 was reworded
  to match; plan DD 13 pins the narrow-write rule (sole key, typed value,
  explicit gate, visible Edit).

## Routing Recommendations

### Spec amendments
*Applied 2026-07-07 (developer-confirmed routing): Findings 1 and 2 added
as ACs #18–19; Finding 5 folded into AC #2.*
- Finding 1: AC pinning config-only tool activation (content never executes).
- Finding 2: AC on retiring superseded group blueprints in `repartition` mode.
- Finding 5: evidence-cited proposal presentation folded into AC #2.

*Dual-lens re-run 2026-07-07 — applied (developer-confirmed, variant b):*
- Finding 8: AC #15 reworded — declarations through the blueprint
  surface; `group_territory` set by the skill to the invocation's named
  target (the sole config key it may write, developer-typed value only).
  Plan DD 13 updated to the narrow single-key write.

### Plan amendments
*Findings 3, 4, 6 (held 2026-07-07 for the plan phase): applied — plan
DD 5 (ingestion relpath + tracked-set gate), DD 6 (extractor timeout +
batched fan-out), DD 7 (counters-only partition ledger events).*

*Dual-lens re-run 2026-07-07 — applied (developer-confirmed routing):*
- Finding 7 → plan Task 4 + the scan contract (manifest-token charset
  gate, fixed-string matching, metacharacter fixtures).
- Finding 9 → plan DD 12, Task 7, and the gatherer contract (fail-closed
  held/violated marking).

### Candidate issues
No findings routed to Issue this run.
