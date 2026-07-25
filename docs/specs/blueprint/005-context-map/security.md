---
spec: docs/specs/blueprint/005-context-map/spec.md
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-03"
---

# Security Review: Context map — deliberate spec-group definition

## Summary

**Findings:** 0 Critical · 3 Notable · 6 Advisory

Dual-lens review: `spec.md` (requirements-gap lens) and `plan.md`
(design-flaw lens), freeform expert review plus the STRIDE completeness
sweep. LINDDUN omitted — no PII, credentials, or session data in scope.
All Critical/Notable findings are addressed — three applied to the spec,
and the plan folds in the four plan-routed findings (traceability in
plan.md → Design Decisions). Two new Advisories (8, 9) surfaced by the
plan lens await routing.

## Coverage

- spec.md — reviewed 2026-07-03 (requirements-gap lens); re-reviewed
  2026-07-03 post-amendment under the dual lens
- plan.md — reviewed 2026-07-03 (design-flaw lens)

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
- **Status:** Addressed in plan — DD 4 (`commit-map` containment validation,
  literal paths, `--` guard, mode whitelist) / Task 3. See also Finding 8.

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
- **Status:** Addressed in plan — DD 6 (data-not-instruction clause;
  Task 7's Verify greps for it).

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
- **Status:** Addressed in plan — Tasks 5–6 (scrub reminder text in
  `map-methodology.md`, applied at both write gates).

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
- **Status:** Addressed in plan — DD 6 (single namespaced
  `Skill(jim:blueprint)` token; nested calls covered by existing scoped
  tokens).

### 8. Extend `commit-map` containment validation to the `<specs-dir>` argument

- **Severity:** Advisory
- **Description:** Plan DD 4 validates `<map-path>`, but `commit-map`'s
  second argument `<specs-dir>` (resolved from the `specs_path` config key)
  also reaches `git add` via `<specs-dir>/ledger.md` — the same
  config-derived-path class Finding 2 closed for the map path.
- **Suggestion:** Apply the identical containment check (relative, no `..`
  segment, resolves inside `git rev-parse --show-toplevel`) to both
  arguments; add a reject test case per argument in `tests/jimledger.sh`.
- **Route:** Plan
- **Relates to:** plan DD 4, Task 3
- **Status:** Addressed in plan — DD 4 / Task 3 (containment check applied
  to both arguments).

### 9. Prefer a deterministic shape check for territory paths

- **Severity:** Advisory
- **Description:** AC #8's capture-time territory validation is enforced at
  the prompt layer (methodology rules the LLM applies). The check itself is
  mechanical — exactly the class the Bash-vs-Prompt rule assigns to
  scripts; a missed `..` at capture would sit in the map until #22
  re-validates.
- **Suggestion:** Run a deterministic validator at the capture step (a
  small `jimfile.sh` helper or an inline pattern-reject in the skill's
  fenced block) before recording territory — or explicitly document
  acceptance of prompt-level validation with #22 as the backstop.
- **Route:** Plan
- **Relates to:** plan DD 7, Tasks 5–6; spec AC #8
- **Status:** Addressed in plan — DD 7 / Task 2 (`jimfile.sh valid-relpath`
  validator) + Task 5 (methodology invokes it per declared path).

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No auth/identity boundary — all input originates in the developer's session |
| Tampering | Yes | Findings 2, 5, 8, 9 — config-redirected commit targets; out-of-band edits of the authority artifact; unvalidated territory paths at rest |
| Repudiation | No | No issues found — ledger stage events (AC #10) + git history audit every map change |
| Information Disclosure | Yes | Finding 6 — domain knowledge entering a possibly-public committed doc |
| Denial of Service | N/A | Human-gated, bounded flows; one small file read per `/jim:spec` |
| Elevation of Privilege | Yes | Findings 1, 7 — unattended-autonomy gap; transitive tool-surface widening |

## Artifact Misalignment

Dual-lens comparison ran — no misalignments found. AC #18's grading matches
plan DD 9 exactly; AC #1's single-surface rule survives the mint-new path
(the write still flows through the blueprint surface, invoked inline); AC
#10's stage-event convention holds with the documented specs-root ledger
home (plan DD 3).

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
- Finding 2: path validation + scoped-commit discipline — **addressed**, plan DD 4 / Task 3.
- Finding 3: data-not-instruction clause in the advisor step — **addressed**, plan DD 6 / Task 7.
- Finding 6: scrub reminder at the map approval gate — **addressed**, plan Tasks 5–6.
- Finding 7: narrow `allowed-tools` tokens — **addressed**, plan DD 6 / Task 7.
- Finding 8 (new, this run): extend `commit-map` containment to `<specs-dir>` — **addressed**, plan DD 4 / Task 3 (both arguments validated).
- Finding 9 (new, this run): deterministic territory-path shape check — **addressed**, plan DD 7 / Tasks 2, 5 (`jimfile.sh valid-relpath`).

### Candidate issues
No findings routed to Issue this run.
