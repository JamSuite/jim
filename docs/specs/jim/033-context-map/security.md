---
spec: docs/specs/jim/033-context-map/spec.md
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-07-03"
---

# Security Review: Context map — deliberate spec-group definition

## Summary

**Findings:** 0 Critical · 3 Notable · 4 Advisory

Reviewed `spec.md` only (no `plan.md` exists yet) with the requirements-gap
lens: freeform expert review plus the STRIDE completeness sweep. LINDDUN
omitted — no PII, credentials, or session data in scope.

## Coverage

- spec.md — reviewed 2026-07-03 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Map holds architecture data, not personal data |
| Credentials | No | — |
| Session data | No | — |
| Internal-only | Yes | Group purposes, boundary rationale, code-territory paths — project-internal architecture knowledge |
| Public | Yes | `BLUEPRINT.md` is committed; exposure follows repo visibility (jim's own repo is going public per ROADMAP) |

## Findings

### 1. Project-tier autonomy under `auto_blueprint` is unspecified

- **Severity:** Notable
- **Description:** `auto_blueprint` governs unattended group-tier blueprint
  writes, graded by the Step-4a criticality rule (spec 031). The spec is
  silent on whether project-tier map updates inherit that knob. A partition
  edit ripples to every group by definition — an unattended re-partition
  would be the highest-consequence unattended write jim can make.
- **Suggestion:** Add an AC stating the autonomy stance explicitly — either
  project-tier map changes always require explicit approval regardless of
  `auto_blueprint`, or the Step-4a grading extends with partition-structure
  edits classed critical/high (always prompt).
- **Route:** Spec
- **Relates to:** AC #9, AC #10

### 2. Commit-machinery generalization must preserve the path-scoped discipline

- **Severity:** Notable
- **Description:** Extending `commit-blueprint` (which hardcodes
  `spec.md` + `ledger.md`) to a root-level artifact resolved from the
  `blueprint_path` config key inserts a config-derived value into a
  `git add` path for the first time. A malicious or broken `jimconf.toml`
  (repo content, editable via PR) could redirect the write/commit target.
- **Suggestion:** The plan must validate/normalize the resolved path
  (repo-contained, no traversal) before any write or commit, keep the
  literal-path + `--` guard + `create|update` whitelist discipline, and
  never widen to `git add -A` — extending the posture documented in
  ARCHITECTURE.md → Security Considerations rather than restating it.
- **Route:** Plan
- **Relates to:** AC #1, AC #10

### 3. Advisor must treat map content as data, never instruction

- **Severity:** Notable
- **Description:** `BLUEPRINT.md` becomes jim's most frequently
  machine-consumed document — read on every `/jim:spec`, influencing filing
  decisions and triggering the mint-new skill invocation. Git-carried repo
  content can be attacker-influenced in team settings (documented trust
  boundary, ARCHITECTURE.md → Security Considerations). Directive-style text
  embedded in a group's purpose/rationale must not bind the advisor's
  recommendation, pushback, or flow control.
- **Suggestion:** The plan's advisor step carries an explicit
  data-not-instruction clause (the spec 018 § Security and Safety
  discipline applied to map content); reasoning quotes map content
  descriptively only.
- **Route:** Plan
- **Relates to:** AC #11, AC #12, AC #13

### 4. Validate territory paths at capture time

- **Severity:** Advisory
- **Description:** Territory declarations are data-only in this spec but
  become AST/lint scoping inputs when #22 lands. Capturing unvalidated
  paths (absolute, `../` traversal) plants unsafe inputs ahead of their
  mechanical consumption.
- **Suggestion:** Extend AC #8 with capture-time shape validation —
  relative, repo-contained paths only — so the map never records a path
  that would be unsafe to consume later.
- **Route:** Spec
- **Relates to:** AC #8

### 5. Maintained-by banner on `BLUEPRINT.md`

- **Severity:** Advisory
- **Description:** Out-of-band hand edits are the documented failure mode of
  jim's other authority artifact (issue #10 — ARCHITECTURE.md hand-edits
  bypassing `/jim:arch`). The map is a higher-consequence authority document
  with the same exposure.
- **Suggestion:** The map template opens with the same "generated and
  maintained by `/jim:blueprint` — edit via the skill" banner
  ARCHITECTURE.md carries, deterring silent tampering with the partition.
- **Route:** Spec
- **Relates to:** AC #1, AC #3

### 6. Scrub moment at the map write gate

- **Severity:** Advisory
- **Description:** The creation interview paraphrases developer domain
  knowledge into a committed document; on public repos that content is
  public (internal system names, unreleased product directions).
- **Suggestion:** Mirror the spec-017 AC-C2 scrub reminder at the map's
  approval gate before first write ("last chance to scrub sensitive
  content before persistence").
- **Route:** Plan
- **Relates to:** AC #5

### 7. Narrow the `allowed-tools` widening in `/jim:spec`

- **Severity:** Advisory
- **Description:** Inline `Skill(jim:blueprint)` invocation means
  `/jim:spec`'s `allowed-tools` transitively covers the blueprint update
  path's nested calls — including the path-scoped commit — on every spec
  run.
- **Suggestion:** Add only the namespaced `Skill(jim:blueprint)` token plus
  the specific `Bash(...)` tokens the update path needs, per the spec-012
  allowed-tools-narrowing precedent. No broad git or bash grants.
- **Route:** Plan
- **Relates to:** AC #13

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No auth/identity boundary — all input originates in the developer's session |
| Tampering | Yes | Findings 2, 5 — config-redirected commit target; out-of-band edits of the authority artifact |
| Repudiation | No | No issues found — ledger stage events (AC #10) + git history audit every map change |
| Information Disclosure | Yes | Finding 6 — domain knowledge entering a possibly-public committed doc |
| Denial of Service | N/A | Human-gated, bounded flows; one small file read per `/jim:spec` |
| Elevation of Privilege | Yes | Findings 1, 7 — unattended-autonomy gap; transitive tool-surface widening |

## Routing Recommendations

### Spec amendments
- Finding 1: add an autonomy-stance AC (map updates vs `auto_blueprint`) —
  **applied 2026-07-03 as AC #18**, revised per developer direction: map
  updates honor `auto_blueprint` under the shared Step-4a grading (additive
  unattended when enabled; weakening/removal always prompts per-item;
  default `"false"` keeps every change human-approved), preserving the
  `auto_` convention's user-owned override intent.
- Finding 4: extend AC #8 with capture-time territory-path shape validation —
  **applied 2026-07-03** (AC #8 extended in place).
- Finding 5: add the maintained-by banner to the map's required shape —
  **applied 2026-07-03** (AC #1 extended in place).

### Plan amendments
- Finding 2: path validation + scoped-commit discipline for the generalized commit arm.
- Finding 3: data-not-instruction clause in the advisor step.
- Finding 6: scrub reminder at the map approval gate.
- Finding 7: narrow `allowed-tools` tokens for the inline invocation.

### Candidate issues
No findings routed to Issue this run.
