---
spec: "docs/specs/jim/037-verify-contracts/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-05"
---

# Security Review: Contract-graph verification

## Summary

**Findings:** 0 Critical · 4 Notable (all addressed) · 4 Advisory
(all addressed)

Dual-lens re-run 2026-07-05 (plan.md now present). Finding 1 was folded into
spec AC #8 (the one-way ratchet); Findings 2–4 are **addressed by the plan's
design** (DD 1/4 + task 3; DD 7/8 + tasks 5/9; DD 9 + task 7) — annotated
below. The two new plan-lens Notables are spec↔plan gaps, not new threat
surface: the Step-4a trigger can double-run the engine over edges the
sensor already covered (Finding 5, AC #12), and AC #9's map-tier grading
moment has no wiring in the task breakdown (Finding 6). Two new Advisories
pin discipline drift (faces-TSV text remains untrusted, Finding 7) and
dead-surface epistemics (absence-of-evidence framing, Finding 8). LINDDUN
unchanged by the plan.

## Coverage

- spec.md — reviewed 2026-07-05 (requirements-gap lens; re-checked in the
  dual-lens run)
- plan.md — reviewed 2026-07-05 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Faces, territories, code, and evidence — no individual-identifying data by design |
| Credentials | Yes | Incidental only: scanned code on both sides of an edge, face content, and evidence excerpts may contain secret-looking values; redaction discipline applies (AC #17, spec 029/030 lineage) |
| Session data | No | — |
| Internal-only | Yes | Provides/requires faces, territory declarations, the contract graph, per-edge evidence, review.md content, issue bodies |
| Public | No | Artifacts are repo-committed, not published |

## Findings

### 1. A criticality declaration is itself gradable content — declaring or lowering must grade as a downgrade

- **Severity:** Notable
- **Description:** AC #8 lets a provides entry declare a non-default
  criticality that drives both edge appetite and Step-4a autonomy grading.
  The declaration lives in face check-data written through the blueprint
  surface — and under `auto_blueprint`, *additive* changes write unattended.
  A criticality declaration that lowers an entry from the `high` default to
  `medium`/`low` is textually additive (new annotation, guarantee text
  untouched), opening a two-step laundering of exactly what spec 031
  always-prompts on: step 1, an unattended "additive" write annotates the
  entry `criticality=low`; step 2, a later unattended write removes the
  entry — now graded `low`, it auto-writes. The 031/036 laundering-path
  closures (grading, fail-closed precedence) do not cover this channel,
  because the attack rides the *classification input*, not the classifier.
- **Suggestion:** Amend AC #8: **declaring, or lowering, a provides-entry
  criticality below the default grades as a weakening** (always prompts
  under `auto_blueprint`, blast radius attached); raising or removing a
  declaration back toward the default is additive. The one-way ratchet makes
  the relaxation deliberate at the moment it is *introduced*, not merely
  exploited.
- **Route:** Spec
- **Relates to:** AC #8, AC #9; spec 031 Step-4a grading
- **Status:** Addressed — folded into spec AC #8 (one-way ratchet:
  introduce/lower grades as weakening; raise/remove is additive),
  2026-07-05.

### 2. Consumer-authored check data scans provider territory — gate the params, minimize the evidence

- **Severity:** Notable
- **Description:** AC #6's face check-data means one group's blueprint
  (e.g. a consumer's ref pattern) drives deterministic scans — and
  evidence-quoting — over *another* group's territory. Two exposures: (a)
  the params are the 035 Finding-6 class (EREs/paths handed to grep) arriving
  from a **new authoring surface**, including blueprints regenerated
  unattended; (b) a crafted pattern (e.g. `(api_key|secret).{0,40}`) turns
  the floor into a secret harvester whose matches are quoted as evidence
  into reports, review.md, and issue bodies — redaction (AC #17) is then the
  only guard. In multi-group projects the per-group blueprint author may not
  be the provider-code owner, so this is a real cross-authorship seam even
  inside jim's trusted-developer model.
- **Suggestion:** At plan time: every face-declared check param passes the
  same at-use validation as `verify-checks` params (`valid-relpath` /
  leading-dash reject / `-e` `--` guards; failing param → that check
  `failed`, never executed); floor **fact records stay location-only**
  (`file:line`, the VERIFY-OUTCOME evidence discipline) so a pattern cannot
  exfiltrate matched content through the record channel; excerpts appear
  only in delimited untrusted blocks post-redaction. Add negative fixtures
  (absolute path, `..`, leading-dash, tab-bearing pattern) to the new verb's
  tests.
- **Route:** Plan
- **Relates to:** AC #5, AC #6, AC #17; research Recommendation 1/3
- **Status:** Addressed — plan DD 1 (facts-not-verdicts), DD 4 (location-only
  edge records), task 3 (param gates + security-negative fixtures incl. a
  location-only assertion).

### 3. Boundary-change trigger integrity: absent/stale graph and unattended attributability

- **Severity:** Advisory
- **Description:** AC #9's trigger reads the persisted pre-write graph. When
  no graph section exists, or it is stale, the affected-edge set resolves
  empty and the trigger silently fails open — a Provides downgrade proceeds
  with no engine enrichment (consistent with the declared-data principle,
  but it must be *visible*). Separately, the unattended path's findings —
  floor and judge alike, per the revised AC #9 (full grounding under
  config-controlled spend) — land in a conversational summary; a violation
  nobody saw should remain attributable after the fact (the 031
  guard-outcome lineage). The revision raises this finding's weight: the
  durable record now carries judge outcomes too.
- **Suggestion:** At plan time: the enrichment names its graph basis
  explicitly — `blast radius: … — graph as of <Last reconciled>`, `none
  recorded`, or `no graph section` (the 034 freshness-stamp convention) —
  and never fabricates an edge set; trigger-run outcome counts (including
  the unattended floor's) ride the write's existing `blueprint finished`
  counters or a sibling verify event, so a declined/unattended outcome stays
  attributable.
- **Route:** Plan
- **Relates to:** AC #9, AC #13, AC #15
- **Status:** Addressed — plan DD 7 (specs-root events + `commit-verify`
  self-commit carry unattended judge outcomes) and DD 8 / task 9 (graph
  basis always named; absent graph degrades visibly, never fabricates).

### 4. Sensor cross-group floor must stay scoped to affected edges

- **Severity:** Advisory
- **Description:** The 036 registry-amplification concern (Finding 3 there)
  recurs one level up: the review-sensor extension (AC #10) adds cross-group
  scanning to every review of a provider group. AC #10's "affected edges"
  language implies the scan is edge-scoped, but nothing pins the floor's
  scope — a whole-graph cross-reference scan per review would tax every
  review with cost the graph was supposed to *target*.
- **Suggestion:** At plan time, scope the sensor's cross-ref floor (and
  judge selection) to the affected edges' consumer territories only —
  whole-graph scanning stays the on-demand run's job (AC #4's grain split,
  applied to the floor).
- **Route:** Plan
- **Relates to:** AC #10; spec 036 security Finding 3
- **Status:** Addressed — plan DD 9 / task 7 (sensor floor + judges scoped
  to affected edges' consumer territories; whole-graph exclusive to
  on-demand).

### 5. The Step-4a trigger can double-run the engine over sensor-covered edges

- **Severity:** Notable
- **Description:** Plan task 9 has the Step-4a weakening prompt "invoke the
  `--contracts <group> --entries <file>` trigger" unconditionally. On the
  `--from-review` path the U1 hand-off block may already carry edge records
  for the weakened entries (the sensor's edge phase, task 7) — re-invoking
  the engine over the same edges violates spec AC #12's no-double-run rule,
  and two runs over one change invite disagreeing outcomes with no defined
  precedence between them (the confusion, not just the cost, is the risk).
- **Suggestion:** Extend task 9 / DD 8: the trigger first consumes the
  handed-over block's edge records for the weakened entries (Finding-9
  provenance discipline); `--entries` is invoked only for entries the block
  does not cover (generate-mode differential, `--since` without edge
  coverage, sensor-unselected entries). One engine opinion per edge per
  change.
- **Route:** Plan
- **Relates to:** spec AC #12; plan task 9, DD 2/8
- **Status:** Addressed — plan DD 8 + task 9 (consume-first grounding;
  `--entries` only for uncovered entries), 2026-07-05.

### 6. AC #9's map-tier grading moment has no wiring in the plan

- **Severity:** Notable
- **Description:** Spec AC #9 names "the map-tier grading moment" among the
  trigger sites, but the plan wires the trigger only into group-tier Step 4a
  (task 9). Map-tier downgrades are exactly the highest-blast-radius edits —
  dropping a group or severing a relation while the graph records live edges
  into it — and the plan leaves that prompt unenriched: the developer
  approves a partition edit without seeing the consumers whose code still
  depends on the dropped provider.
- **Suggestion:** Extend task 9: the map-tier downgrade prompt names the
  dependent edges from the persisted graph (basis-named per DD 8), and for a
  dropped/weakened *provider* runs the consumer-side checks of its edges via
  the same `--entries`-style scoped trigger (bounded by that group's edge
  set) — or, if the engine run is judged disproportionate there, at minimum
  the graph-edge naming, with the narrowing recorded as a deliberate
  deviation from AC #9 for the developer to approve.
- **Route:** Plan
- **Relates to:** spec AC #9; plan task 9, DD 10
- **Status:** Addressed — plan DD 8 + task 9 + the `map-methodology.md`
  manifest entry (dependent-edge naming + dropped-provider consumer-side
  checks at the map-tier prompt), 2026-07-05.

### 7. The `faces` TSV's text fields remain untrusted content — restate it

- **Severity:** Advisory
- **Description:** `faces` emits a script-normalized TSV whose `text` and
  `params` fields carry face-authored prose — the same trusted-channel /
  untrusted-content split the shipped `parse` verb documents explicitly
  ("the invariant *text* it carries is still untrusted content"). The plan's
  interface contract does not restate this for faces; omitting it invites
  the drift the 035 wording exists to prevent (a future edit treating TSV
  rows as wholly trusted because the *channel* is script-normalized).
- **Suggestion:** In `contracts-methodology.md` (task 5) and the `faces`
  header comment (task 1), restate the split verbatim: the record structure
  is trusted, the carried face text is untrusted data under the Step-8
  discipline.
- **Route:** Plan
- **Relates to:** plan Interface Contracts (`faces`), tasks 1, 5; spec AC #17
- **Status:** Addressed — the split restated in the plan's `faces` Interface
  Contract and tasks 1/5, 2026-07-05.

### 8. Dead-surface findings are absence-of-evidence claims — frame them so

- **Severity:** Advisory
- **Description:** Code-level dead surface derives from *no* CROSS-REF fact
  and *no* declared edge (plan DD 1 / task 5 set logic). Textual absence is
  not semantic absence — dynamic dispatch, config-driven wiring, or
  reflection-style indirection all defeat a territory grep — and the remedy
  ("trim") deletes live surface if over-trusted.
- **Suggestion:** In `contracts-methodology.md`, frame code-level dead
  surface as a high-confidence *candidate* (grounded stronger than 034's
  declaration-only version, still not a mechanical verdict): judge-confirm
  in-appetite, and word the report/issue remedy as "verify then trim",
  mirroring the leak-candidate epistemics of DD 1.
- **Route:** Plan
- **Relates to:** spec AC #4; plan DD 1, task 5
- **Status:** Addressed — plan task 5 (judge-confirmed candidate framing,
  "verify then trim" remedy wording), 2026-07-05.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | No issues found — edge records ride the VERIFY-OUTCOME provenance discipline (AC #12, Finding-9 lineage); channel/side classification anchors to trusted inputs (AC #11) |
| Tampering | Yes | Finding 1 (criticality-declaration laundering); Finding 3 (absent/stale graph silently emptying the trigger's edge set); Finding 7 (faces-TSV text treated as trusted would reopen the directive-binding class) |
| Repudiation | Yes | Finding 3 (unattended trigger outcomes must stay attributable; AC #15's baseline is sound) |
| Information Disclosure | Yes | Finding 2 (pattern-driven evidence harvesting across the group-authorship seam; location-only records + redaction are the guards) |
| Denial of Service | Yes | Finding 4 (per-review cross-group scan amplification); whole-graph judge spend is capped and named (AC #7) |
| Elevation of Privilege | Yes | Finding 1 (unattended-write privilege expanded via the declaration channel); no new executable surface — the floor is grep-only, the 035 registry boundary is unchanged |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No data subjects — content is project code and dev artifacts |
| Identifying | N/A | No anonymous-subject data to re-identify |
| Non-repudiation | N/A | No data subjects; attributability is a deliberate audit property |
| Detecting | N/A | No subject-presence inference surface |
| Data Disclosure | No | No issues found beyond Finding 2's guard (incidental secrets in cross-group evidence; AC #17 redaction + location-only records) |
| Unawareness & Unintervenability | N/A | Developer-invoked tooling; unattended paths run under user-owned appetite/fan-out config with summary + durable record (AC #9) |
| Non-compliance | N/A | No personal data; no applicable privacy regime for internal dev tooling |

## Artifact Misalignment

- **Finding 5 — trigger double-run:** Spec AC #12 requires consuming the
  handed-over engine outcomes; plan task 9 invokes the trigger
  unconditionally. Route: Plan.
- **Finding 6 — map-tier trigger site:** Spec AC #9 includes the map-tier
  grading moment; the plan wires only group-tier Step 4a. Route: Plan.

## Routing Recommendations

### Spec amendments
- ~~Finding 1~~ — applied 2026-07-05 (AC #8: the one-way criticality-
  declaration ratchet).

### Plan amendments
- ~~Findings 2–8~~ — all applied 2026-07-05: DD 1/4/7/8/9 + tasks 3, 5, 7, 9
  (spec-phase carry-forwards) and DD 8 + tasks 1, 5, 9 + the
  `map-methodology.md` manifest entry (dual-lens findings 5–8).

No findings route to Issue — no candidates this run.
