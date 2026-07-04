---
spec: "docs/specs/jim/034-contract-graph/spec.md"
reviewed_phases: [spec]
status: Needs Plan Review
date: "2026-07-04"
---

# Security Review: Cross-group contract graph and blast radius

## Summary

**Findings:** 0 Critical · 4 Notable · 3 Advisory

Reviewed spec.md only (no plan.md exists yet) under the requirements-gap
lens, with a STRIDE completeness sweep; LINDDUN omitted (no PII, credentials,
or session data handled). The spec inherits a strong 026–033 trust-boundary
lineage; the gaps found are presentation-layer discipline, autonomy
treatment, and use-time validation — no design flaw that would create a
vulnerability if built as specified.

*Routing applied 2026-07-04: the four Spec-routed findings (1, 2, 3, 6) were
folded into spec.md as AC clauses / AC #13. Remaining open routing is
plan-phase (findings 4, 5, 7) — hence the `Needs Plan Review` status for the
architect.*

## Coverage

- spec.md — reviewed 2026-07-04 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Architecture/process artifacts only (faces, map, findings) |
| Credentials | No | Not handled as data; scanned faces may incidentally contain secret-looking values — covered by the redaction invariant (AC #12) |
| Session data | No | — |
| Internal-only | Yes | Group faces, invariants, and territory paths: project-internal architecture data, committed to the repo |
| Public | No | Repo-resident artifacts; exposure follows repo visibility |

## Findings

### 1. Untrusted face/map content is quoted without a delimiting requirement

- **Severity:** Notable
- **Description:** The reconciliation report, the 031 fork enrichment (blast
  radius), and offered issue bodies all quote face entries as evidence. AC
  #11 forbids embedded directives from *binding* judgment, but nothing
  requires the quoted content to be *presented* inside a structural
  untrusted-content delimiter — the discipline spec 031 established with its
  `<untrusted-change-evidence>` blocks. Undelimited quoting is the channel
  through which a directive-bearing face entry reaches the developer (or a
  downstream agent reading the report) dressed as the skill's own voice.
- **Suggestion:** Add a clause (AC #11 or a sibling AC): face/map content
  quoted in the report, fork enrichment, or an offered issue body appears
  only inside delimited untrusted-content blocks, per the spec 031
  convention.
- **Route:** Spec
- **Relates to:** AC #9, AC #11

### 2. Autonomy treatment of the derived-graph write is unspecified

- **Severity:** Notable
- **Description:** Under `auto_blueprint`, blueprint writes run unattended
  and each fires re-derivation (AC #7), which rewrites the graph section in
  `BLUEPRINT.md`. Spec 033 AC #18 grades map writes by the Step-4a rule
  (weakening/removal prompts per-item). The spec is silent on whether the
  derived-section rewrite is subject to that grading — if subject, every
  unattended update prompts and the automation the initiative depends on
  breaks; if exempt, an unattended write path into the partition-authority
  artifact exists with no recorded rationale or boundary.
- **Suggestion:** Add an AC: the derived graph section is mechanical
  content carrying no intent authority — its rewrite is exempt from Step-4a
  grading and never prompts on its own; findings always surface in the run's
  report and counters, and hand-declared map content (Relations, groups,
  territory) remains fully graded. State it so the exemption is a bounded,
  auditable decision rather than an implementation accident.
- **Route:** Spec
- **Relates to:** AC #2, AC #7

### 3. Territory paths need use-time re-validation at reconcile time

- **Severity:** Notable
- **Description:** The unresolved-require class attributes partition gaps by
  checking whether a required code location falls in any group's declared
  territory (AC #4) — the first consumer of territory paths since 033
  recorded them as data. 033 validates paths at *capture*
  (`jimfile.sh valid-relpath`), but map content can be edited out-of-band;
  a path that is absolute, `..`-bearing, or otherwise malformed must not
  drive filesystem probing or land in a finding as-is.
- **Suggestion:** Add a clause to AC #4 (or AC #11): every territory path
  read from the map is re-validated through the `valid-relpath` boundary
  before use; failing paths are reported as map hygiene findings and never
  used. (Carries forward 033 security Findings 4/9; issue #22 records the
  same consumption-time backstop for the verification engine.)
- **Route:** Spec
- **Relates to:** AC #4

### 4. Commit scope for the map write from group-tier runs

- **Severity:** Notable
- **Description:** A group-tier update self-commits via `commit-blueprint`,
  path-scoped to the group's `000-blueprint/` dir. Re-derivation on that
  trigger (AC #7) also rewrites `BLUEPRINT.md` — outside that commit's
  scope. The blueprint machinery's invariant is that `jimledger.sh` commits
  in exactly its enumerated path-scoped arms (literal paths, `--` guard,
  never `git add -A`); an implementation that widens a commit or hand-rolls
  a new git write site to carry the map change would erode it.
- **Suggestion:** The plan must route the graph write through the existing
  `valid-relpath`-guarded `commit-map` arm (or an equally path-scoped
  mechanism decided at plan time) — never a widened commit. Flagged now so
  the architect designs for it; the research file's commit-scope note points
  the same way.
- **Route:** Plan
- **Relates to:** AC #2, AC #7

### 5. Counter consumption must shape-validate

- **Severity:** Advisory
- **Description:** The `edges=`/`leaks=`/`dead=`/`breaking=` counters (AC
  #10) ride the untrusted ledger. Any later extraction — the `metrics`
  channel, `/jim:review` surfacing — must treat them per the spec 028
  precedent: fixed key set, values shape-validated (non-negative integers),
  so a tampered ledger yields at most a bounded well-formed value, never
  arbitrary text.
- **Suggestion:** Plan-level: when wiring counter extraction, mirror the
  `review_alignment`/`review_findings` validation pattern
  (`jimledger.sh` metrics, spec 028 Finding 1).
- **Route:** Plan
- **Relates to:** AC #10

### 6. Report language must not imply code-level verification

- **Severity:** Advisory
- **Description:** The reconciliation is declaration-level: faces checked
  against faces. A clean report means "declared surfaces are consistent,"
  not "contracts verified against code" — that is issue #22's engine. Report
  wording that implies verification would breed exactly the misplaced trust
  the no-persisted-verdict decision (AC #3) guards against.
- **Suggestion:** Add one line to the report requirements (AC #9 or the
  mockup's framing): summary wording states the check is declaration-level
  reconciliation, e.g. "faces reconcile" rather than "contracts verified."
- **Route:** Spec
- **Relates to:** AC #3, AC #9, UI Mockup

### 7. Cost amplification and blast-radius noise

- **Severity:** Advisory
- **Description:** Re-derivation on every blueprint write costs O(groups)
  blueprint reads plus LLM matching per write; a bloated or adversarially
  broad `requires` face floods blast radius with edges, and habitual noise
  teaches developers to ignore breaking-change findings (alarm fatigue — the
  practical failure mode of any detector).
- **Suggestion:** Plan-level: a deterministic extraction pre-pass over the
  dotted face keys bounds LLM cost (Bash-vs-Prompt rule); the report
  aggregates findings per consumer group rather than per entry. Deeper
  hardening of match quality is issue #22's territory.
- **Route:** Plan
- **Relates to:** AC #7, AC #8

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or auth boundary — all inputs are repo-resident artifacts under the developer's control |
| Tampering | Yes | Findings 3, 4 (out-of-band map edits; commit-scope discipline). Face tampering is mitigated by design: detectors + approval gates + AC #11 |
| Repudiation | No | No issues found — AC #10 counters and ledger stage events give attributability |
| Information Disclosure | Yes | Findings 1, 6 (undelimited quoting; over-trust in clean reports); AC #12 covers secret redaction |
| Denial of Service | Yes | Finding 7 (per-write cost amplification; blast-radius flooding / alarm fatigue) |
| Elevation of Privilege | Yes | Finding 2 (unattended write authority for the derived section under `auto_blueprint`) |

## Routing Recommendations

### Spec amendments
- Finding 1: require delimited untrusted-content blocks wherever face/map content is quoted — **applied 2026-07-04** (AC #11 clause).
- Finding 2: state the derived-graph section's exemption from Step-4a grading as a bounded, recorded decision — **applied 2026-07-04** (new AC #13).
- Finding 3: require use-time `valid-relpath` re-validation of territory paths read from the map — **applied 2026-07-04** (AC #4 clause).
- Finding 6: require declaration-level wording in the report summary — **applied 2026-07-04** (AC #9 clause).

### Plan amendments
- Finding 4: route the map write through the path-scoped `commit-map` arm; never widen a commit.
- Finding 5: shape-validate counter extraction per the spec 028 pattern.
- Finding 7: deterministic extraction pre-pass; per-consumer aggregation in the report.

### Candidate issues
No findings routed to Issue this run.
