---
spec: "docs/specs/jim/034-contract-graph/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-04"
---

# Security Review: Cross-group contract graph and blast radius

## Summary

**Findings:** 0 Critical · 0 Notable · 0 Advisory open (all 9 findings resolved)

Dual-lens re-run 2026-07-04 with plan.md present (requirements-gap +
design-flaw lenses, artifact-misalignment check); LINDDUN omitted (no PII,
credentials, or session data handled). All seven first-run findings are
resolved — four folded into spec ACs at routing, three absorbed by plan
design decisions (DD 2, DD 4, DD 5). The re-run surfaced one Notable
artifact misalignment (Finding 8 — reconcile-only runs leave their durable
record uncommitted) and one Advisory hardening (Finding 9); both were
routed to Plan and applied 2026-07-04 (DD 4/DD 5/task 3 always-commit;
DD 7/task 1 freshness stamp). No findings remain open — status `Active`.

## Coverage

- spec.md — reviewed 2026-07-04 (requirements-gap lens; re-checked in the
  dual-lens re-run after routing amendments)
- plan.md — reviewed 2026-07-04 (design-flaw lens + artifact misalignment)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Architecture/process artifacts only (faces, map, findings) |
| Credentials | No | Not handled as data; scanned faces may incidentally contain secret-looking values — covered by the redaction invariant (AC #12) |
| Session data | No | — |
| Internal-only | Yes | Group faces, invariants, and territory paths: project-internal architecture data, committed to the repo |
| Public | No | Repo-resident artifacts; exposure follows repo visibility |

## Findings

### 1. Untrusted face/map content is quoted without a delimiting requirement — RESOLVED (spec AC #11 clause)

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

### 2. Autonomy treatment of the derived-graph write is unspecified — RESOLVED (spec AC #13; plan DD 6)

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

### 3. Territory paths need use-time re-validation at reconcile time — RESOLVED (spec AC #4 clause; plan task 1)

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

### 4. Commit scope for the map write from group-tier runs — RESOLVED (plan DD 4: `commit-map` reuse, never widened)

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

### 5. Counter consumption must shape-validate — RESOLVED (plan DD 5 + Interface Contracts)

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

### 6. Report language must not imply code-level verification — RESOLVED (spec AC #9 clause)

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

### 7. Cost amplification and blast-radius noise — RESOLVED (plan DD 2 scoped reads; methodology per-consumer aggregation)

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

### 8. Reconcile-only runs leave their durable record uncommitted — RESOLVED (plan DD 4/DD 5 always-commit; task 3)

- **Severity:** Notable
- **Description:** Spec AC #10 requires each run's outcomes durably recorded
  — the spec-031 convention, where the record is *committed*. Plan DD 4
  commits via `commit-map` only **when the graph section changed**, but a
  reconcile can find mismatches without changing the derived edge table
  (findings are verdicts, the graph records edges): that run's
  counter-bearing `started`/`finished` events sit uncommitted on the
  specs-root ledger indefinitely, and attributability is lost with the
  working tree. This is an artifact misalignment between spec AC #10 and
  plan DD 4/DD 5.
- **Suggestion:** Always run `commit-map` after a reconcile that recorded
  events: an unchanged map stages nothing, so the commit carries the ledger
  alone — exactly the 031 fix-only ledger-only-commit property, reusing the
  existing arm with no script change. Amend DD 4/DD 5 and the § Reconcile
  skeleton (task 3) accordingly.
- **Route:** Plan
- **Relates to:** AC #10; plan DD 4, DD 5

### 9. Blast-radius consult should surface graph freshness — RESOLVED (plan DD 7; task 1 stamp echo)

- **Severity:** Advisory
- **Description:** Plan DD 7 reads the *persisted* graph for blast radius —
  correct and cheap, but a stale graph under-reports consumers, and the
  prompt gives the developer no way to judge that risk.
- **Suggestion:** Include the graph's `Last reconciled` stamp in the
  blast-radius line (e.g. "blast radius: billing, orders — graph as of
  2026-07-04"), so trust in the answer is calibrated by its age. One line in
  the methodology's fork-enrichment format (task 1).
- **Route:** Plan
- **Relates to:** AC #8; plan DD 7

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or auth boundary — all inputs are repo-resident artifacts under the developer's control |
| Tampering | No | Prior findings 3, 4 resolved (spec AC #4 clause; plan DD 4); face tampering mitigated by design: detectors + approval gates + AC #11 |
| Repudiation | Yes | Finding 8 (reconcile-only runs' counters uncommitted — attributability gap) |
| Information Disclosure | No | Prior findings 1, 6 resolved (spec AC #11/#9 clauses); AC #12 covers secret redaction |
| Denial of Service | No | Prior finding 7 resolved (plan DD 2; per-consumer aggregation) |
| Elevation of Privilege | No | Prior finding 2 resolved (spec AC #13; plan DD 6 — bounded, recorded exemption) |

## Artifact Misalignment

- **Finding 8 — reconcile-only durability:** Spec AC #10 asserts every run's
  outcomes are durably recorded (the 031 committed-record convention); plan
  DD 4's conditional commit leaves a no-graph-change reconcile's counters
  uncommitted. Route: Plan (always `commit-map` after recorded events —
  ledger-only commit when the map is unchanged).

## Routing Recommendations

### Spec amendments
- Finding 1: require delimited untrusted-content blocks wherever face/map content is quoted — **applied 2026-07-04** (AC #11 clause).
- Finding 2: state the derived-graph section's exemption from Step-4a grading as a bounded, recorded decision — **applied 2026-07-04** (new AC #13).
- Finding 3: require use-time `valid-relpath` re-validation of territory paths read from the map — **applied 2026-07-04** (AC #4 clause).
- Finding 6: require declaration-level wording in the report summary — **applied 2026-07-04** (AC #9 clause).

### Plan amendments
- Finding 4: route the map write through the path-scoped `commit-map` arm — **resolved 2026-07-04** (plan DD 4).
- Finding 5: shape-validate counter extraction per the spec 028 pattern — **resolved 2026-07-04** (plan DD 5 + Interface Contracts).
- Finding 7: cost bounding + per-consumer aggregation — **resolved 2026-07-04** (plan DD 2; methodology, task 1).
- Finding 8: always `commit-map` after a reconcile that recorded events (ledger-only commit when the map is unchanged) — **applied 2026-07-04** (DD 4/DD 5, task 3).
- Finding 9: echo the graph's `Last reconciled` stamp in the blast-radius line — **applied 2026-07-04** (DD 7, task 1, Interface Contracts).

### Candidate issues
No findings routed to Issue this run.
